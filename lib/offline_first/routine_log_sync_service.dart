import 'dart:async';

import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/app_flavor.dart';

import '../enums/posthog_analytics_event.dart';
import '../logger.dart';
import '../repositories/supabase/supabase_routine_log_repository.dart';
import '../services/fcm_push_service.dart';
import 'routine_log_local_entry.dart';
import 'routine_log_local_store.dart';

/// A small, self-contained example of an offline-first repository + sync engine
/// for [RoutineLogDto].
///
/// Design:
/// - Local file-based store is the source of truth for the app.
/// - Supabase is used as the remote source.
/// - Last-write-wins is implemented using the Supabase `updatedAt` column
///   (server clock) vs the local `updatedAt` value.
///
/// This module is intentionally *not* wired into the rest of the app yet.
/// You can adopt it incrementally by:
/// - Using [offlineLogs] instead of direct Supabase logs where appropriate.
/// - Calling [syncNow] on app start, resume, or when connectivity changes.
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
          // Best-effort delete; if it 404s or fails, we keep the entry
          // as pending so it can retry later.
          await _client.from('routine_logs').delete().eq('id', entry.log.id);

          // Remove from local list after successful delete.
          _entries = _entries.where((e) => e.log.id != entry.log.id).toList();
        } else {
          // Upsert log; Supabase trigger will set `updatedAt` server-side.
          await _client.from('routine_logs').upsert(entry.log.toJson());

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

          // Fire analytics for successfully synced workout logs from here so
          // that we only track events once the server write has succeeded.
          await Posthog().capture(
            eventName: PostHogAnalyticsEvent.logRoutine.displayName,
          );

          // Notify coach when client logs a session (client app only).
          // Backend resolves coach from coach_clients, device tokens, and client name.
          if (AppConfig.isClient) {
            final clientId = _client.auth.currentUser?.id;
            if (clientId != null && clientId.isNotEmpty) {
              unawaited(sendFcmNotification(
                clientId: clientId,
                title: 'Session logged',
                body: 'Your client just logged a workout',
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
          .from('routine_logs')
          .select('id, "updatedAt"')
          .eq('owner', userId);

      final updatedAtById = <String, DateTime>{};
      for (final row in rawRows as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final id = map['id'] as String;
        final updatedAtStr = map['updatedAt'] as String;
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
