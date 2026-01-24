import 'package:supabase_flutter/supabase_flutter.dart';

Future<String?> fetchCoachIdForClient(String clientId) async {
  try {
    final response = await Supabase.instance.client
        .from('coach_clients')
        .select('coach_id')
        .eq('client_id', clientId)
        .maybeSingle();
    return response?['coach_id'] as String?;
  } catch (_) {
    return null;
  }
}
