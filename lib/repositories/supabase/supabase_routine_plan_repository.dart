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
  Future<void> loadPlans({
    String? ownerIdOverride,
    String? clientIdOverride,
    bool requireOwnerAndClient = false,
  }) async {
    try {
      final authUserId = _client.auth.currentUser?.id;
      final ownerId = ownerIdOverride ?? authUserId;
      final clientId = clientIdOverride ?? authUserId;
      if (ownerId == null || clientId == null) {
        logger.w('No user logged in');
        return;
      }

      final query = _client.from('routine_plans').select();
      final response = requireOwnerAndClient
          ? await query
              .eq('owner', ownerId)
              .eq('clientId', clientId)
              .order('createdAt', ascending: false)
          : await query
              .or('owner.eq.$ownerId,clientId.eq.$clientId')
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
