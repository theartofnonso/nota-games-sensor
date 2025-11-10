import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:isar/isar.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tracker_app/models/local/local_routine_plan.dart';
import 'package:tracker_app/services/sync_service.dart';
import 'package:uuid/uuid.dart';

import '../../dtos/appsync/routine_plan_dto.dart';
import '../../enums/posthog_analytics_event.dart';
import '../../logger.dart';

class SupabaseRoutinePlanRepository {
  final logger = getLogger(className: "SupabaseRoutinePlanRepository");
  final SupabaseClient _client = Supabase.instance.client;
  final Isar isar;
  final SyncService syncService;

  List<RoutinePlanDto> _plans = [];

  SupabaseRoutinePlanRepository({
    required this.isar,
    required this.syncService,
  });

  UnmodifiableListView<RoutinePlanDto> get plans =>
      UnmodifiableListView(_plans);

  /// Load plans - OFFLINE FIRST
  Future<void> loadPlans() async {
    try {
      await _loadFromLocal();
      _syncFromSupabase(); // Fire and forget - updates local storage in background
    } catch (e) {
      logger.e('Error loading routine plans: $e');
      rethrow;
    }
  }

  Future<void> _loadFromLocal() async {
    final localPlans = await isar.localRoutinePlans.where().findAll();

    _plans = localPlans.map((local) {
      return RoutinePlanDto.fromJson(json: jsonDecode(local.jsonData));
    }).toList();

    logger.i('Loaded ${_plans.length} plans from local storage');
  }

  Future<void> _syncFromSupabase() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        logger.w('No user logged in, skipping Supabase sync');
        return;
      }

      if (!await syncService.hasInternet()) {
        logger.d('No internet, skipping Supabase sync');
        return;
      }

      final response = await _client
          .from('routine_plans')
          .select()
          .eq('owner', userId)
          .order('createdAt', ascending: false);

      final supabasePlans = (response as List<dynamic>)
          .map((item) => _convertMapToRoutinePlanDto(item))
          .toList();

      await _mergeWithLocal(supabasePlans);

      // Reload in-memory list after sync
      await _loadFromLocal();

      logger.i('Synced ${supabasePlans.length} plans from Supabase');
    } catch (e) {
      logger.e('Error syncing from Supabase: $e');
    }
  }

  Future<void> _mergeWithLocal(List<RoutinePlanDto> supabasePlans) async {
    await isar.writeTxn(() async {
      for (final plan in supabasePlans) {
        final existing = await isar.localRoutinePlans
            .filter()
            .planIdEqualTo(plan.id)
            .findFirst();

        if (existing == null) {
          // New item - create it
          final local = LocalRoutinePlan()
            ..planId = plan.id
            ..jsonData = jsonEncode(plan.toJson())
            ..name = plan.name
            ..lastModifiedLocal = DateTime.now()
            ..needsSync = false
            ..createdAt = DateTime.now();

          await isar.localRoutinePlans.put(local);
        } else if (!existing.needsSync) {
          // Existing item with no local changes - update from Supabase
          existing
            ..jsonData = jsonEncode(plan.toJson())
            ..name = plan.name
            ..lastModifiedLocal = DateTime.now()
            ..needsSync = false;

          await isar.localRoutinePlans.put(existing);
        }
        // If existing.needsSync = true, keep local version (will sync later)
      }
    });

    await _loadFromLocal();
  }

  /// Save plan - OFFLINE FIRST
  Future<RoutinePlanDto> savePlan({required RoutinePlanDto planDto}) async {
    try {
      final id = planDto.id.isEmpty ? const Uuid().v4() : planDto.id;
      final planWithId = planDto.copyWith(id: id);

      final local = LocalRoutinePlan()
        ..planId = id
        ..jsonData = jsonEncode(planWithId.toJson())
        ..name = planWithId.name
        ..lastModifiedLocal = DateTime.now()
        ..needsSync = true
        ..createdAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.localRoutinePlans.put(local);
      });

      _plans.add(planWithId);

      await syncService.queueSync(
        entityType: 'plan',
        entityId: id,
        operation: 'create',
        jsonData: jsonEncode(planWithId.toJson()),
      );

      Posthog().capture(
        eventName: PostHogAnalyticsEvent.createRoutineTemplate.displayName,
        properties: Map<String, Object>.from(planWithId.toJson()),
      );

      logger.i('Saved plan locally: $planWithId');
      return planWithId;
    } catch (e) {
      logger.e('Error saving plan: $e');
      rethrow;
    }
  }

  /// Update plan - OFFLINE FIRST
  Future<void> updatePlan({required RoutinePlanDto plan}) async {
    try {
      final local = await isar.localRoutinePlans
          .filter()
          .planIdEqualTo(plan.id)
          .findFirst();

      if (local != null) {
        local
          ..jsonData = jsonEncode(plan.toJson())
          ..name = plan.name
          ..lastModifiedLocal = DateTime.now()
          ..needsSync = true;

        await isar.writeTxn(() async {
          await isar.localRoutinePlans.put(local);
        });
      }

      final index = _plans.indexWhere((p) => p.id == plan.id);
      if (index != -1) {
        _plans[index] = plan;
      }

      await syncService.queueSync(
        entityType: 'plan',
        entityId: plan.id,
        operation: 'update',
        jsonData: jsonEncode(plan.toJson()),
      );

      logger.i('Updated plan locally: $plan');
    } catch (e) {
      logger.e('Error updating plan: $e');
      rethrow;
    }
  }

  /// Remove plan - OFFLINE FIRST
  Future<void> removePlan({required RoutinePlanDto plan}) async {
    try {
      final local = await isar.localRoutinePlans
          .filter()
          .planIdEqualTo(plan.id)
          .findFirst();

      if (local != null) {
        await isar.writeTxn(() async {
          await isar.localRoutinePlans.delete(local.id);
        });
      }

      _plans.removeWhere((p) => p.id == plan.id);

      await syncService.queueSync(
        entityType: 'plan',
        entityId: plan.id,
        operation: 'delete',
        jsonData: jsonEncode(plan.toJson()),
      );

      logger.i('Removed plan locally: $plan');
    } catch (e) {
      logger.e('Error removing plan: $e');
      rethrow;
    }
  }

  /// Helper methods

  RoutinePlanDto? planWhere({required String id}) {
    return _plans.firstWhereOrNull((dto) => dto.id == id);
  }

  void clear() {
    _plans.clear();
  }

  /// Helper method to convert Supabase map to RoutinePlanDto
  RoutinePlanDto _convertMapToRoutinePlanDto(Map<String, dynamic> item) {
    return RoutinePlanDto.fromJson(json: Map<String, dynamic>.from(item));
  }
}
