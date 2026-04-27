/// A single target phrase the learner will speak.
///
/// The Falou-style modules reuse phrases across exercises, so all
/// translations, audio references and phonetic hints live here once
/// and each exercise just points at the id.
class SpeakingPhrase {
  /// Stable id (e.g. `greet_hello`). Used in exercise payloads.
  final String id;

  /// English (L2) text shown big on the phrase card.
  final String l2Text;

  /// Uzbek (L1) translation shown small and muted.
  final String l1Text;

  /// Optional simplified phonetic hint, surfaced after attempt #3.
  /// Keep friendly (e.g. `haw aar yoo?`), not strict IPA.
  final String? phonetic;

  /// Tokens for word-by-word breakdown. When null the widget falls back
  /// to `l2Text.split(" ")` so seeding stays cheap.
  final List<String>? tokens;

  const SpeakingPhrase({
    required this.id,
    required this.l2Text,
    required this.l1Text,
    this.phonetic,
    this.tokens,
  });

  /// Always-safe token list for exercises.
  List<String> get effectiveTokens => tokens ?? _splitWords(l2Text);

  static List<String> _splitWords(String text) {
    return text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList(growable: false);
  }
}
