import 'dart:async';
import 'dart:collection';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/appsync/routine_plan_dto.dart';

import '../../logger.dart';

class SupabaseRoutinePlanRepository {
  final logger = getLogger(className: "SupabaseRoutinePlanRepository");
  final SupabaseClient _client = Supabase.instance.client;

  List<RoutinePlanDto> _plans = [];

  UnmodifiableListView<RoutinePlanDto> get plans =>
      UnmodifiableListView(_plans);

  /// Load plans from Supabase (read-only; writes go through offline layer).
  Future<void> loadPlans() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        logger.w('No user logged in');
        return;
      }

      // Load both user-created plans and system plans (with clientId)
      final response = await _client
          .from('routine_plans')
          .select()
          .or('owner.eq.$userId,clientId.eq.$userId')
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
}
