import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/nutrition/nutrition_log_dto.dart';

import '../logger.dart';
import '../repositories/supabase/supabase_nutrition_log_repository.dart';
import 'nutrition_log_local_entry.dart';
import 'nutrition_log_local_store.dart';

class OfflineNutritionLogRepository {
  OfflineNutritionLogRepository({
    NutritionLogLocalStore? localStore,
    SupabaseNutritionLogRepository? remoteRepository,
    SupabaseClient? client,
  })  : _localStore = localStore ?? NutritionLogLocalStore(),
        _remoteRepository =
            remoteRepository ?? SupabaseNutritionLogRepository(),
        _client = client ?? Supabase.instance.client;

  final NutritionLogLocalStore _localStore;
  final SupabaseNutritionLogRepository _remoteRepository;
  final SupabaseClient _client;
  final _logger = getLogger(className: 'OfflineNutritionLogRepository');

  List<NutritionLogLocalEntry> _entries = const [];

  List<NutritionLogDto> get offlineLogs =>
      _entries.where((e) => !e.isDeleted).map((e) => e.log).toList();

  Future<void> loadFromCache() async {
    _entries = await _localStore.loadAll();
  }

  Future<void> syncNow() async {
    _logger.i('Starting nutrition log sync');

    _entries = await _localStore.loadAll();

    await _pushLocalChanges();
    await _pullRemoteChanges();

    await _localStore.saveAll(_entries);
  }

  Future<void> upsertLocal(NutritionLogDto log) async {
    final now = DateTime.now().toUtc();
    final index = _entries.indexWhere((e) => e.log.id == log.id);

    if (index == -1) {
      _entries = [
        ..._entries,
        NutritionLogLocalEntry(
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
          lastSyncFailed: false,
        ),
        ..._entries.sublist(index + 1),
      ];
    }

    await _localStore.saveAll(_entries);
  }

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

  Future<void> _pushLocalChanges() async {
    final pending = _entries.where((e) => e.needsSync).toList();
    if (pending.isEmpty) {
      _logger.i('No local nutrition log changes to push');
      return;
    }

    for (final entry in pending) {
      try {
        if (entry.isDeleted) {
          await _client.from('nutrition_logs').delete().eq('id', entry.log.id);
          _entries = _entries.where((e) => e.log.id != entry.log.id).toList();
        } else {
          await _client.from('nutrition_logs').upsert(entry.log.toJson());

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
        }
      } catch (e, stackTrace) {
        _logger.w(
          'Failed to push local change for log ${entry.log.id}: $e\n$stackTrace',
        );
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

  Future<void> _pullRemoteChanges() async {
    try {
      await _remoteRepository.loadLogs();
      final remoteLogs = _remoteRepository.logs;

      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _logger.w('Skipping nutrition log pull: no authenticated user');
        return;
      }

      final rawRows = await _client
          .from('nutrition_logs')
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
      final remoteIds = <String>{};

      for (final remote in remoteLogs) {
        remoteIds.add(remote.id);
        final remoteUpdatedAt =
            updatedAtById[remote.id] ?? DateTime.now().toUtc();
        final local = byId[remote.id];

        if (local == null) {
          byId[remote.id] = NutritionLogLocalEntry(
            log: remote,
            updatedAt: remoteUpdatedAt,
            isDeleted: false,
            needsSync: false,
          );
          continue;
        }

        if (remoteUpdatedAt.isAfter(local.updatedAt)) {
          byId[remote.id] = local.copyWith(
            log: remote,
            updatedAt: remoteUpdatedAt,
            isDeleted: false,
            needsSync: false,
            lastSyncFailed: false,
          );
        }
      }

      byId.removeWhere((_, entry) => entry.isDeleted && !entry.needsSync);
      byId.removeWhere((id, entry) =>
          !remoteIds.contains(id) && !entry.needsSync && !entry.isDeleted);

      _entries = byId.values.toList();
    } catch (e, stackTrace) {
      _logger.w('Failed to pull remote nutrition logs: $e\n$stackTrace');
    }
  }
}
