import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/appsync/routine_plan_dto.dart';

import '../logger.dart';
import '../repositories/supabase/supabase_routine_plan_repository.dart';
import 'routine_plan_local_entry.dart';
import 'routine_plan_local_store.dart';

/// Offline-first repository for [RoutinePlanDto].
class OfflineRoutinePlanRepository {
  OfflineRoutinePlanRepository({
    RoutinePlanLocalStore? localStore,
    SupabaseRoutinePlanRepository? remoteRepository,
    SupabaseClient? client,
  })  : _localStore = localStore ?? RoutinePlanLocalStore(),
        _remoteRepository =
            remoteRepository ?? SupabaseRoutinePlanRepository(),
        _client = client ?? Supabase.instance.client;

  final RoutinePlanLocalStore _localStore;
  final SupabaseRoutinePlanRepository _remoteRepository;
  final SupabaseClient _client;
  final _logger = getLogger(className: 'OfflineRoutinePlanRepository');

  List<RoutinePlanLocalEntry> _entries = const [];

  List<RoutinePlanDto> get offlinePlans =>
      _entries.where((e) => !e.isDeleted).map((e) => e.plan).toList();

  Future<void> loadFromCache() async {
    _entries = await _localStore.loadAll();
  }

  Future<void> syncNow() async {
    _logger.i('Starting routine plan sync');

    _entries = await _localStore.loadAll();

    await _pushLocalChanges();
    await _pullRemoteChanges();

    await _localStore.saveAll(_entries);

    _logger.i('Routine plan sync completed. Local plans: ${offlinePlans.length}');
  }

  Future<void> upsertLocal(RoutinePlanDto plan) async {
    final now = DateTime.now().toUtc();
    final index = _entries.indexWhere((e) => e.plan.id == plan.id);

    if (index == -1) {
      _entries = [
        ..._entries,
        RoutinePlanLocalEntry(
          plan: plan,
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
          plan: plan,
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

  Future<void> deleteLocal(String planId) async {
    final index = _entries.indexWhere((e) => e.plan.id == planId);
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
      _logger.i('No local routine plan changes to push');
      return;
    }

    _logger.i('Pushing ${pending.length} local routine plan changes');

    for (final entry in pending) {
      try {
        if (entry.isDeleted) {
          await _client.from('routine_plans').delete().eq('id', entry.plan.id);
          _entries =
              _entries.where((e) => e.plan.id != entry.plan.id).toList();
        } else {
          await _client.from('routine_plans').upsert(entry.plan.toJson());

          final index =
              _entries.indexWhere((e) => e.plan.id == entry.plan.id);
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
          'Failed to push local routine plan change for ${entry.plan.id}: $e\n$stackTrace',
        );

        final index =
            _entries.indexWhere((e) => e.plan.id == entry.plan.id);
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
      await _remoteRepository.loadPlans();
      final remotePlans = _remoteRepository.plans;

      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _logger.w('Skipping routine plan pull: no authenticated user');
        return;
      }

      final rawRows = await _client
          .from('routine_plans')
          .select('id, "updatedAt"')
          .eq('owner', userId);

      final updatedAtById = <String, DateTime>{};
      for (final row in rawRows as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final id = map['id'] as String;
        final updatedAtStr = map['updatedAt'] as String;
        updatedAtById[id] = DateTime.parse(updatedAtStr);
      }

      final byId = {for (final e in _entries) e.plan.id: e};

      for (final remote in remotePlans) {
        final remoteUpdatedAt =
            updatedAtById[remote.id] ?? DateTime.now().toUtc();
        final local = byId[remote.id];

        if (local == null) {
          byId[remote.id] = RoutinePlanLocalEntry(
            plan: remote,
            updatedAt: remoteUpdatedAt,
            isDeleted: false,
            needsSync: false,
          );
          continue;
        }

        if (remoteUpdatedAt.isAfter(local.updatedAt)) {
          byId[remote.id] = local.copyWith(
            plan: remote,
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
      _logger.w('Failed to pull remote routine plans: $e\n$stackTrace');
    }
  }
}


