import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/appsync/exercise_dto.dart';

import '../logger.dart';
import '../repositories/supabase/supabase_exercise_repository.dart';
import 'exercise_local_entry.dart';
import 'exercise_local_store.dart';

/// Offline-first repository for [ExerciseDto].
///
/// - Local file-based store is the source of truth for the app.
/// - Supabase is used as the remote source.
/// - Last-write-wins is implemented using the Supabase `updatedAt` column.
class OfflineExerciseRepository {
  OfflineExerciseRepository({
    ExerciseLocalStore? localStore,
    SupabaseExerciseRepository? remoteRepository,
    SupabaseClient? client,
  })  : _localStore = localStore ?? ExerciseLocalStore(),
        _remoteRepository = remoteRepository ?? SupabaseExerciseRepository(),
        _client = client ?? Supabase.instance.client;

  final ExerciseLocalStore _localStore;
  final SupabaseExerciseRepository _remoteRepository;
  final SupabaseClient _client;
  final _logger = getLogger(className: 'OfflineExerciseRepository');

  List<ExerciseLocalEntry> _entries = const [];

  /// Offline-first view of exercises for the rest of the app.
  List<ExerciseDto> get offlineExercises => _entries
      .where((e) => !e.isDeleted)
      .map((e) => e.exercise)
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  /// Load from disk only (no network).
  Future<void> loadFromCache() async {
    _entries = await _localStore.loadAll();
  }

  /// Full sync: push local changes to server, then pull everything from
  /// Supabase and merge using last-write-wins.
  Future<void> syncNow() async {
    _logger.i('Starting exercise sync');

    _entries = await _localStore.loadAll();

    await _pushLocalChanges();
    await _pullRemoteChanges();

    await _localStore.saveAll(_entries);

    _logger.i('Exercise sync completed. Local exercises: ${offlineExercises.length}');
  }

  /// Local-first create/update: mark entry as needing sync.
  Future<void> upsertLocal(ExerciseDto exercise) async {
    final now = DateTime.now().toUtc();
    final index = _entries.indexWhere((e) => e.exercise.id == exercise.id);

    if (index == -1) {
      _entries = [
        ..._entries,
        ExerciseLocalEntry(
          exercise: exercise,
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
          exercise: exercise,
          updatedAt: now,
          isDeleted: false,
          needsSync: true,
          lastSyncFailed: false,
        ),
        ..._entries.sublist(index + 1),
      ];
    }

    await _localStore.saveAll(_entries);
  }

  /// Local-first delete: mark/remove the exercise locally and sync later.
  Future<void> deleteLocal(String exerciseId) async {
    final index = _entries.indexWhere((e) => e.exercise.id == exerciseId);
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

  Future<void> _pushLocalChanges() async {
    final pending = _entries.where((e) => e.needsSync).toList();
    if (pending.isEmpty) {
      _logger.i('No local exercise changes to push');
      return;
    }

    _logger.i('Pushing ${pending.length} local exercise changes to Supabase');

    for (final entry in pending) {
      try {
        if (entry.isDeleted) {
          await _client.from('exercises').delete().eq('id', entry.exercise.id);
          _entries = _entries
              .where((e) => e.exercise.id != entry.exercise.id)
              .toList();
        } else {
          await _client.from('exercises').upsert(entry.exercise.toJson());

          final index =
              _entries.indexWhere((e) => e.exercise.id == entry.exercise.id);
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
        }
      } catch (e, stackTrace) {
        _logger.w(
          'Failed to push local exercise change for ${entry.exercise.id}: $e\n$stackTrace',
        );

        final index =
            _entries.indexWhere((e) => e.exercise.id == entry.exercise.id);
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

  Future<void> _pullRemoteChanges() async {
    try {
      await _remoteRepository.loadUserExercises();
      final remoteExercises = _remoteRepository.exercises;

      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _logger.w('Skipping exercise pull: no authenticated user');
        return;
      }

      final rawRows = await _client
          .from('exercises')
          .select('id, "updatedAt"')
          .eq('owner', userId);

      final updatedAtById = <String, DateTime>{};
      for (final row in rawRows as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final id = map['id'] as String;
        final updatedAtStr = map['updatedAt'] as String;
        updatedAtById[id] = DateTime.parse(updatedAtStr);
      }

      final byId = {for (final e in _entries) e.exercise.id: e};

      for (final remote in remoteExercises) {
        final remoteUpdatedAt =
            updatedAtById[remote.id] ?? DateTime.now().toUtc();
        final local = byId[remote.id];

        if (local == null) {
          byId[remote.id] = ExerciseLocalEntry(
            exercise: remote,
            updatedAt: remoteUpdatedAt,
            isDeleted: false,
            needsSync: false,
          );
          continue;
        }

        if (remoteUpdatedAt.isAfter(local.updatedAt)) {
          byId[remote.id] = local.copyWith(
            exercise: remote,
            updatedAt: remoteUpdatedAt,
            isDeleted: false,
            needsSync: false,
            lastSyncFailed: false,
          );
        }
      }

      byId.removeWhere((_, entry) => entry.isDeleted && !entry.needsSync);

      _entries = byId.values.toList();
    } catch (e, stackTrace) {
      _logger.w('Failed to pull remote exercises: $e\n$stackTrace');
    }
  }
}


