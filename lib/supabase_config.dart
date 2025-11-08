import 'package:flutter/foundation.dart';

class SupabaseConfig {
  // TODO: Replace with your actual Supabase project URL and anon key
  // You can find these in your Supabase project settings at: https://app.supabase.com
  static const String supabaseUrl = kDebugMode
      ? 'YOUR_DEV_SUPABASE_URL'
      : 'YOUR_PROD_SUPABASE_URL';
  
  static const String supabaseAnonKey = kDebugMode
      ? 'YOUR_DEV_SUPABASE_ANON_KEY'
      : 'YOUR_PROD_SUPABASE_ANON_KEY';
}

