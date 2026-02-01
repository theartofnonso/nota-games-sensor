import 'package:flutter/foundation.dart';

class SupabaseConfig {
  // TODO: Replace with your actual Supabase project URL and anon key
  // You can find these in your Supabase project settings at: https://app.supabase.com
  static const String supabaseUrl = kDebugMode
      ? 'https://psblxphtjqyymlexuydi.supabase.co'
      : 'https://psblxphtjqyymlexuydi.supabase.co';

  static const String supabaseAnonKey = kDebugMode
      ? 'sb_publishable_NMZlMh-S8c1rfIaREy4evQ_48QlPsxR'
      : 'sb_publishable_NMZlMh-S8c1rfIaREy4evQ_48QlPsxR';
}
