import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/coach_decision_dto.dart';

import '../../logger.dart';

class SupabaseCoachDecisionRepository {
  final logger = getLogger(className: 'SupabaseCoachDecisionRepository');
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> createDecision({required CoachDecisionDto decision}) async {
    try {
      await _client.from('coach_decisions').insert(decision.toInsertJson());
    } catch (e) {
      logger.e('Error creating coach decision: $e');
      rethrow;
    }
  }

  Future<List<CoachDecisionDto>> loadDecisions({
    required String clientId,
    int limit = 20,
  }) async {
    try {
      final response = await _client
          .from('coach_decisions')
          .select()
          .eq('client_id', clientId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List<dynamic>)
          .map((item) =>
              CoachDecisionDto.fromJson(json: item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      logger.e('Error loading coach decisions: $e');
      rethrow;
    }
  }
}
