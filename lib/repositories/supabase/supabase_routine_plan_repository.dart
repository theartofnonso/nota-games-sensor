import 'dart:async';

import 'package:collection/collection.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../dtos/appsync/routine_plan_dto.dart';
import '../../enums/posthog_analytics_event.dart';
import '../../logger.dart';

class SupabaseRoutinePlanRepository {
  final logger = getLogger(className: "SupabaseRoutinePlanRepository");
  final SupabaseClient _client = Supabase.instance.client;

  List<RoutinePlanDto> _plans = [];

  UnmodifiableListView<RoutinePlanDto> get plans =>
      UnmodifiableListView(_plans);

  Future<void> loadPlans() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        logger.w('No user logged in, cannot load plans');
        return;
      }

      final response = await _client
          .from('routine_plans')
          .select()
          .eq('owner', userId)
          .order('createdAt', ascending: false);

      _plans = (response as List<dynamic>)
          .map((item) => _convertMapToRoutinePlanDto(item))
          .toList();

      logger.i('Loaded ${_plans.length} routine plans');
    } catch (e) {
      logger.e('Error loading routine plans: $e');
      rethrow;
    }
  }

  Future<RoutinePlanDto> savePlan({required RoutinePlanDto planDto}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _client
          .from('routine_plans')
          .insert(planDto.toJson())
          .select()
          .single();

      final generatedId = response['id'] as String;

      Posthog().capture(
        eventName: PostHogAnalyticsEvent.createRoutineTemplate.displayName,
        properties: Map<String, Object>.from(planDto.toJson()),
      );

      logger.i('Saved plan: $planDto');

      final updatedWithId = planDto.copyWith(id: generatedId);
      return updatedWithId;
    } catch (e) {
      logger.e('Error saving plan: $e');
      rethrow;
    }
  }

  Future<void> updatePlan({required RoutinePlanDto plan}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _client
          .from('routine_plans')
          .update(plan.toJson())
          .eq('id', plan.id)
          .eq('owner', userId);

      logger.i('Updated plan: $plan');
    } catch (e) {
      logger.e('Error updating plan: $e');
      rethrow;
    }
  }

  Future<void> removePlan({required RoutinePlanDto plan}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _client
          .from('routine_plans')
          .delete()
          .eq('id', plan.id)
          .eq('owner', userId);

      logger.i('Removed plan: $plan');
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
