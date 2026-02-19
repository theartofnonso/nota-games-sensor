import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/dtos/set_dtos/duration_set_dto.dart';
import 'package:trainware/dtos/set_dtos/reps_dto.dart';
import 'package:trainware/dtos/set_dtos/weight_and_reps_dto.dart';

import '../logger.dart';
import '../repositories/supabase/supabase_routine_log_repository.dart';
import '../services/fcm_push_service.dart';
import 'routine_log_local_entry.dart';
import 'routine_log_local_store.dart';

/// Offline-first repository + sync engine for workout sessions ([RoutineLogDto]).
///
/// Design:
/// - Local file-based store is the source of truth for the app.
/// - Supabase is used as the remote source.
/// - Last-write-wins is implemented using the Supabase `updated_at` column
///   (server clock) vs the local `updatedAt` value.
///
/// This module is wired into the main routine controller and is the
/// active client-side write path for normalized session data.
class OfflineRoutineLogRepository {
  OfflineRoutineLogRepository({
    RoutineLogLocalStore? localStore,
    SupabaseRoutineLogRepository? remoteRepository,
    SupabaseClient? client,
  })  : _localStore = localStore ?? RoutineLogLocalStore(),
        _remoteRepository = remoteRepository ?? SupabaseRoutineLogRepository(),
        _client = client ?? Supabase.instance.client;

  final RoutineLogLocalStore _localStore;
  final SupabaseRoutineLogRepository _remoteRepository;
  final SupabaseClient _client;
  final _logger = getLogger(className: 'OfflineRoutineLogRepository');

  List<RoutineLogLocalEntry> _entries = const [];

  /// Public, offline-first view of logs for the rest of the app.
  List<RoutineLogDto> get offlineLogs =>
      _entries.where((e) => !e.isDeleted).map((e) => e.log).toList();

  /// Load from disk only (no network).
  Future<void> loadFromCache() async {
    _entries = await _localStore.loadAll();
  }

  Future<void> clearCache() async {
    _entries = const [];
    await _localStore.deleteAll();
  }

  /// Full sync: push local changes to server, then pull everything from
  /// Supabase and merge using last-write-wins.
  Future<void> syncNow() async {
    _logger.i('Starting routine log sync');

    // Ensure we have the latest local snapshot.
    _entries = await _localStore.loadAll();

    await _pushLocalChanges();
    await _pullRemoteChanges();

    await _localStore.saveAll(_entries);

    _logger.i('Routine log sync completed. Local logs: ${offlineLogs.length}');
  }

  /// Create or update a log locally (offline-first).
  ///
  /// This never touches the network directly; instead it marks the entry
  /// as [needsSync] so that [syncNow] can push the change when online.
  Future<void> upsertLocal(RoutineLogDto log) async {
    final now = DateTime.now().toUtc();
    final index = _entries.indexWhere((e) => e.log.id == log.id);

    if (index == -1) {
      _entries = [
        ..._entries,
        RoutineLogLocalEntry(
          log: log,
          updatedAt: now,
          isDeleted: false,
          needsSync: true,
        ),
      ];
    } else {
      final existing = _entries[index];
      _entries = [
        ..._entries.sublist(0, index),
        existing.copyWith(
          log: log,
          updatedAt: now,
          isDeleted: false,
          needsSync: true,
        ),
        ..._entries.sublist(index + 1),
      ];
    }

    await _localStore.saveAll(_entries);
  }

  /// Mark a log as deleted locally; [syncNow] will propagate to the server.
  Future<void> deleteLocal(String logId) async {
    final index = _entries.indexWhere((e) => e.log.id == logId);
    if (index == -1) return;

    final existing = _entries[index];
    final now = DateTime.now().toUtc();

    _entries = [
      ..._entries.sublist(0, index),
      existing.copyWith(
        updatedAt: now,
        isDeleted: true,
        needsSync: true,
      ),
      ..._entries.sublist(index + 1),
    ];

    await _localStore.saveAll(_entries);
  }

  /// Push all [needsSync] changes to Supabase.
  Future<void> _pushLocalChanges() async {
    final pending = _entries.where((e) => e.needsSync).toList();
    if (pending.isEmpty) {
      _logger.i('No local routine log changes to push');
      return;
    }

    _logger.i('Pushing ${pending.length} local changes to Supabase');

    for (final entry in pending) {
      try {
        if (entry.isDeleted) {
          // Phase 6: delete normalized session.
          await _client
              .from('workout_sessions')
              .delete()
              .eq('id', entry.log.id);

          // Remove from local list after successful delete.
          _entries = _entries.where((e) => e.log.id != entry.log.id).toList();
        } else {
          // Phase 5.5: relational write path.
          await _client.from('workout_sessions').upsert({
            'id': entry.log.id,
            'user_id': _client.auth.currentUser?.id,
            'template_id': _asUuidOrNull(entry.log.templateId),
            'name': entry.log.name,
            'notes': null,
            'coach_note': entry.log.coachNote,
            'start_time': entry.log.startTime.toUtc().toIso8601String(),
            'end_time': entry.log.endTime.toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });

          // Replace child rows from the latest local state.
          await _client
              .from('session_exercises')
              .delete()
              .eq('session_id', entry.log.id);

          for (var exIndex = 0;
              exIndex < entry.log.exerciseLogs.length;
              exIndex++) {
            final exLog = entry.log.exerciseLogs[exIndex];
            final inserted = await _client
                .from('session_exercises')
                .insert({
                  'session_id': entry.log.id,
                  'exercise_id': exLog.exercise.id,
                  'template_exercise_id': null,
                  'order_index': exIndex,
                  'super_set_group':
                      exLog.superSetId.isEmpty ? null : exLog.superSetId,
                  'notes': exLog.notes.isEmpty ? null : exLog.notes,
                })
                .select('id')
                .single();
            final sessionExerciseId = inserted['id'] as String;

            final setRows = <Map<String, dynamic>>[];
            for (var setIndex = 0; setIndex < exLog.sets.length; setIndex++) {
              final set = exLog.sets[setIndex];
              final row = <String, dynamic>{
                'session_exercise_id': sessionExerciseId,
                'order_index': setIndex,
                'is_completed': set.checked,
              };
              if (set is WeightAndRepsSetDto) {
                row['reps'] = set.reps;
                row['weight'] = set.weight;
              } else if (set is RepsSetDto) {
                row['reps'] = set.reps;
              } else if (set is DurationSetDto) {
                row['duration_seconds'] = set.duration.inSeconds;
              }
              setRows.add(row);
            }
            if (setRows.isNotEmpty) {
              await _client.from('session_sets').insert(setRows);
            }
          }

          // Mark as synced; we don't yet know the server's updatedAt value,
          // but the next pull will bring that in and update the local entry.
          final index = _entries.indexWhere((e) => e.log.id == entry.log.id);
          if (index != -1) {
            final current = _entries[index];
            _entries = [
              ..._entries.sublist(0, index),
              current.copyWith(
                needsSync: false,
                lastSyncFailed: false,
              ),
              ..._entries.sublist(index + 1),
            ];
          }

          // Notify coach when client logs a session (client app only).
          // Backend resolves coach from coach_clients, device tokens, and client name.
          if (AppConfig.isClient) {
            final clientId = _client.auth.currentUser?.id;
            if (clientId != null && clientId.isNotEmpty) {
              unawaited(sendFcmNotification(
                userId: clientId,
                logId: entry.log.id,
              ));
            }
          }
        }
      } catch (e, stackTrace) {
        _logger.w(
          'Failed to push local change for log ${entry.log.id}: $e\n$stackTrace',
        );
        // Mark the entry as failed so the UI can surface this state, but keep
        // it as `needsSync` so it can be retried later.
        final index = _entries.indexWhere((e) => e.log.id == entry.log.id);
        if (index != -1) {
          final current = _entries[index];
          _entries = [
            ..._entries.sublist(0, index),
            current.copyWith(lastSyncFailed: true),
            ..._entries.sublist(index + 1),
          ];
        }
      }
    }
  }

  /// Pull all logs from Supabase and merge into local entries using
  /// last-write-wins (server `updatedAt` vs local `updatedAt`).
  Future<void> _pullRemoteChanges() async {
    try {
      await _remoteRepository.loadLogs();
      final remoteLogs = _remoteRepository.logs;

      // Fetch raw rows so we can read the `updatedAt` column as well.
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _logger.w('Skipping remote pull: no authenticated user');
        return;
      }

      final rawRows = await _client
          .from('workout_sessions')
          .select('id, updated_at')
          .eq('user_id', userId);

      final updatedAtById = <String, DateTime>{};
      for (final row in rawRows as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final id = map['id'] as String;
        final updatedAtStr = map['updated_at'] as String;
        updatedAtById[id] = DateTime.parse(updatedAtStr);
      }

      final byId = {for (final e in _entries) e.log.id: e};

      // Track which remote IDs we've seen
      final remoteIds = <String>{};

      for (final remoteLog in remoteLogs) {
        remoteIds.add(remoteLog.id);
        final remoteUpdatedAt =
            updatedAtById[remoteLog.id] ?? DateTime.now().toUtc();
        final local = byId[remoteLog.id];

        if (local == null) {
          // New remote log we didn't know about locally.
          byId[remoteLog.id] = RoutineLogLocalEntry(
            log: remoteLog,
            updatedAt: remoteUpdatedAt,
            isDeleted: false,
            needsSync: false,
          );
          continue;
        }

        // Last-write-wins:
        // - If local is newer -> keep local (it will be pushed on next sync).
        // - If remote is newer -> overwrite local with remote.
        if (remoteUpdatedAt.isAfter(local.updatedAt)) {
          byId[remoteLog.id] = local.copyWith(
            log: remoteLog,
            updatedAt: remoteUpdatedAt,
            isDeleted: false,
            needsSync: false,
          );
        }
      }

      // Remove entries that are marked deleted locally and have been
      // successfully deleted from the server (i.e., no remote row exists).
      byId.removeWhere((_, entry) => entry.isDeleted && !entry.needsSync);

      // Remove local entries that no longer exist on the remote (unless they need sync)
      byId.removeWhere((id, entry) =>
          !remoteIds.contains(id) && !entry.needsSync && !entry.isDeleted);

      _entries = byId.values.toList();
    } catch (e, stackTrace) {
      _logger.w('Failed to pull remote routine logs: $e\n$stackTrace');
    }
  }
}

String? _asUuidOrNull(String raw) {
  if (raw.isEmpty) return null;
  final uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}\-'
    r'[0-9a-fA-F]{4}\-'
    r'[1-5][0-9a-fA-F]{3}\-'
    r'[89abAB][0-9a-fA-F]{3}\-'
    r'[0-9a-fA-F]{12}$',
  );
  return uuidPattern.hasMatch(raw) ? raw : null;
}
