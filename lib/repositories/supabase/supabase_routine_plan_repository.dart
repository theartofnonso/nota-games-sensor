import 'dart:async';
import 'dart:convert';

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
          .order('created_at', ascending: false);

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

      final now = DateTime.now().toUtc();

      final insertData = {
        'owner': userId,
        'data': jsonEncode(planDto.toJson()),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      // Only include id if it's not empty (let Supabase auto-generate otherwise)
      if (planDto.id.isNotEmpty) {
        insertData['id'] = planDto.id;
      }

      final response = await _client
          .from('routine_plans')
          .insert(insertData)
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

      final now = DateTime.now().toUtc();

      await _client
          .from('routine_plans')
          .update({
            'data': jsonEncode(plan.toJson()),
            'updated_at': now.toIso8601String(),
          })
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
    final dataJson = jsonDecode(item['data'] as String) as Map<String, dynamic>;

    // Add metadata from Supabase
    dataJson['id'] = item['id'];
    dataJson['owner'] = item['owner'];
    dataJson['createdAt'] = item['created_at'];
    dataJson['updatedAt'] = item['updated_at'];

    return RoutinePlanDto.fromJson(json: dataJson);
  }
}
