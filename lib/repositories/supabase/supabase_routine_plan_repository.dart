import 'dart:async';

import 'package:collection/collection.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tracker_app/dtos/appsync/routine_plan_dto.dart';
import 'package:uuid/uuid.dart';

import '../../enums/posthog_analytics_event.dart';
import '../../logger.dart';

class SupabaseRoutinePlanRepository {
  final logger = getLogger(className: "SupabaseRoutinePlanRepository");
  final SupabaseClient _client = Supabase.instance.client;

  List<RoutinePlanDto> _plans = [];

  UnmodifiableListView<RoutinePlanDto> get plans =>
      UnmodifiableListView(_plans);

  /// Load plans from Supabase
  Future<void> loadPlans() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        logger.w('No user logged in');
        return;
      }

      final response = await _client
          .from('routine_plans')
          .select()
          .eq('owner', userId)
          .order('createdAt', ascending: false);

      _plans = (response as List<dynamic>).map((item) {
        final data = Map<String, dynamic>.from(item);
        return RoutinePlanDto.fromJson(json: data);
      }).toList();

      logger.i('Loaded ${_plans.length} plans from Supabase');
    } catch (e) {
      logger.e('Error loading plans: $e');
      rethrow;
    }
  }

  /// Save a new plan
  Future<RoutinePlanDto> savePlan(RoutinePlanDto plan) async {
    try {
      // Generate ID if empty
      final id = plan.id.isEmpty ? const Uuid().v4() : plan.id;
      final planWithId = plan.copyWith(id: id);

      // Insert into Supabase
      await _client.from('routine_plans').insert(planWithId.toJson());

      // Analytics
      await Posthog().capture(
        eventName: PostHogAnalyticsEvent.createRoutinePlan.displayName,
      );

      // Add to in-memory list
      _plans.add(planWithId);

      logger.i('Saved plan: ${planWithId.id}');

      return planWithId;
    } catch (e) {
      logger.e('Error saving plan: $e');
      rethrow;
    }
  }

  /// Update an existing plan
  Future<void> updatePlan(RoutinePlanDto plan) async {
    try {
      // Update in Supabase
      await _client
          .from('routine_plans')
          .update(plan.toJson())
          .eq('id', plan.id);

      // Update in-memory list
      _plans = _plans.map((item) => item.id == plan.id ? plan : item).toList();

      logger.i('Updated plan: ${plan.id}');
    } catch (e) {
      logger.e('Error updating plan: $e');
      rethrow;
    }
  }

  /// Delete a plan
  Future<void> deletePlan(RoutinePlanDto plan) async {
    try {
      // Delete from Supabase
      await _client.from('routine_plans').delete().eq('id', plan.id);

      // Remove from in-memory list
      _plans.removeWhere((item) => item.id == plan.id);

      logger.i('Deleted plan: ${plan.id}');
    } catch (e) {
      logger.e('Error deleting plan: $e');
      rethrow;
    }
  }

  /// Helper: Find plan by ID
  RoutinePlanDto? wherePlanById(String id) {
    return _plans.firstWhereOrNull((plan) => plan.id == id);
  }
}
