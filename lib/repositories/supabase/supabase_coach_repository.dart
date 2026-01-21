import 'package:supabase_flutter/supabase_flutter.dart';

import '../../logger.dart';

class SupabaseCoachRepository {
  final logger = getLogger(className: 'SupabaseCoachRepository');
  final SupabaseClient _client = Supabase.instance.client;

  Future<bool> isCoach({required String userId}) async {
    try {
      final response = await _client
          .from('coaches')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      logger.e('Error checking coach status: $e');
      return false;
    }
  }
}
