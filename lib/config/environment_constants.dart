/// Build-time environment constants injected via `--dart-define`.
///
/// Usage in build commands:
///   flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=your-anon-key
class EnvironmentConstants {
  const EnvironmentConstants._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=com.vocabgame.vocab_game';
  static const String appStoreUrl = 'https://apps.apple.com/us/app/vocabgame-english-uzbek/id6761130647';

  /// Gemini API key for speaking module AI evaluation.
  /// Optional — speaking module degrades gracefully without it.
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Whether the Gemini-powered speaking module is available.
  static bool get hasGeminiKey => geminiApiKey.isNotEmpty;

  /// Validates that all required environment constants were provided at
  /// build time. Call this once at the top of `main()` before any SDK
  /// initialization. Throws an immediate, developer-readable error if
  /// any value is missing.
  static void validate() {
    final missing = <String>[];
    if (url.isEmpty) missing.add('SUPABASE_URL');
    if (anonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');

    if (missing.isNotEmpty) {
      throw StateError(
        'Missing required --dart-define values: ${missing.join(', ')}.\n'
        'Run with: flutter run '
        '--dart-define=SUPABASE_URL=<url> '
        '--dart-define=SUPABASE_ANON_KEY=<key>',
      );
    }
  }
}
