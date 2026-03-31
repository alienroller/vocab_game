class EnvironmentConstants {
  const EnvironmentConstants._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}

// This should be passed in --dart-define.
