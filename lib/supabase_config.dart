import 'package:flutter/foundation.dart';

class SupabaseConfig {
  // TODO: Replace with your actual Supabase project URL and anon key
  // You can find these in your Supabase project settings at: https://app.supabase.com
  static const String supabaseUrl = kDebugMode
      ? 'https://psblxphtjqyymlexuydi.supabase.co'
      : 'https://psblxphtjqyymlexuydi.supabase.co';

  static const String supabaseAnonKey = kDebugMode
      ? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBzYmx4cGh0anF5eW1sZXh1eWRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg5MjU3NzcsImV4cCI6MjA3NDUwMTc3N30.JP8_bgmTvjO4_nqDSDddSfTtSmm45AxvK2zleuEgh10'
      : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBzYmx4cGh0anF5eW1sZXh1eWRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg5MjU3NzcsImV4cCI6MjA3NDUwMTc3N30.JP8_bgmTvjO4_nqDSDddSfTtSmm45AxvK2zleuEgh10';
}
