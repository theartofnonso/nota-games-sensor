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
        _remoteRepository = remoteRepository ?? SupabaseRoutinePlanRepository(),
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

  Future<void> clearCache() async {
    _entries = const [];
    await _localStore.deleteAll();
  }

  Future<void> syncNow() async {
    _logger.i('Starting routine plan sync');

    _entries = await _localStore.loadAll();

    await _pushLocalChanges();
    await _pullRemoteChanges();

    await _localStore.saveAll(_entries);

    _logger
        .i('Routine plan sync completed. Local plans: ${offlinePlans.length}');
  }

  Future<void> upsertLocal(RoutinePlanDto plan) async {
    // Defense in depth: Prevent modifying system-created plans (those with clientId)
    if (plan.clientId != null && plan.clientId!.isNotEmpty) {
      _logger.w(
        'Cannot upsert system plan (has clientId): ${plan.id}. System plans can only be modified by the backend.',
      );
      throw UnsupportedError(
        'Cannot modify system-created routine plans. These plans are managed by the backend system.',
      );
    }

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

    // Defense in depth: Prevent deleting system-created plans (those with clientId)
    if (existing.plan.clientId != null && existing.plan.clientId!.isNotEmpty) {
      _logger.w(
        'Cannot delete system plan (has clientId): $planId. System plans can only be deleted by the backend.',
      );
      throw UnsupportedError(
        'Cannot delete system-created routine plans. These plans are managed by the backend system.',
      );
    }

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
        // Defense in depth: Skip system-created plans (those with clientId)
        // These should never be modified by the frontend, but if they somehow got into
        // the local store with needsSync=true, we skip them here
        if (entry.plan.clientId != null && entry.plan.clientId!.isNotEmpty) {
          _logger.w(
            'Skipping push for system plan (has clientId): ${entry.plan.id}. '
            'System plans are managed by the backend and cannot be modified from the frontend.',
          );

          // Mark as not needing sync since we're intentionally skipping it
          final index = _entries.indexWhere((e) => e.plan.id == entry.plan.id);
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
          continue;
        }

        if (entry.isDeleted) {
          await _client.from('routine_plans').delete().eq('id', entry.plan.id);
          _entries = _entries.where((e) => e.plan.id != entry.plan.id).toList();
        } else {
          final userId = _client.auth.currentUser?.id;
          if (userId == null) {
            throw Exception('Cannot upsert plan: user not authenticated');
          }

          // Ensure owner is set to current user and clientId is null for user-created plans
          final json = entry.plan.toJson();
          json['owner'] = userId;
          // Explicitly set clientId to null for user-created plans (RLS requirement)
          json['clientId'] = null;

          await _client.from('routine_plans').upsert(json);

          final index = _entries.indexWhere((e) => e.plan.id == entry.plan.id);
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

        final index = _entries.indexWhere((e) => e.plan.id == entry.plan.id);
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
          .or('owner.eq.$userId,clientId.eq.$userId');

      final updatedAtById = <String, DateTime>{};
      for (final row in rawRows as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final id = map['id'] as String;
        final updatedAtStr = map['updatedAt'] as String;
        updatedAtById[id] = DateTime.parse(updatedAtStr);
      }

      final byId = {for (final e in _entries) e.plan.id: e};

      // Track which remote IDs we've seen
      final remoteIds = <String>{};

      for (final remote in remotePlans) {
        remoteIds.add(remote.id);
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

      // Remove entries that are marked deleted locally and have been successfully deleted from the server
      byId.removeWhere((_, entry) => entry.isDeleted && !entry.needsSync);

      // Remove local entries that no longer exist on the remote (unless they need sync)
      byId.removeWhere((id, entry) =>
          !remoteIds.contains(id) && !entry.needsSync && !entry.isDeleted);

      _entries = byId.values.toList();
    } catch (e, stackTrace) {
      _logger.w('Failed to pull remote routine plans: $e\n$stackTrace');
    }
  }
}
