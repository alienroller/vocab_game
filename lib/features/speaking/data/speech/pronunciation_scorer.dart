import 'dart:math' as math;

/// Pronunciation similarity in `[0.0, 1.0]`.
///
/// Blends two cheap signals:
/// - character-level Levenshtein ratio (catches "i wood" vs "i would")
/// - token-level Jaccard (catches word swaps / missing filler)
///
/// A blended score lets the scorer tolerate both typos from the STT
/// engine and small word omissions, which is what Falou does — pass
/// threshold is 0.65, deliberately lenient.
class PronunciationScorer {
  /// Default passing threshold, per §5.3 of the overhaul doc.
  static const double defaultThreshold = 0.65;

  const PronunciationScorer();

  double score(String transcription, String target) {
    final a = _normalize(transcription);
    final b = _normalize(target);
    if (a.isEmpty || b.isEmpty) return 0.0;

    final lev = _levenshteinRatio(a, b);
    final jac = _jaccard(a.split(' ').toSet(), b.split(' ').toSet());
    return (0.6 * lev + 0.4 * jac).clamp(0.0, 1.0);
  }

  bool passes(String transcription, String target,
      {double threshold = defaultThreshold}) {
    return score(transcription, target) >= threshold;
  }

  // ─── Internals ─────────────────────────────────────────────────────

  /// Lowercase, strip punctuation (keep apostrophes), collapse whitespace.
  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"[^\w\s']"), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static double _levenshteinRatio(String a, String b) {
    if (a == b) return 1.0;
    final maxLen = math.max(a.length, b.length);
    if (maxLen == 0) return 1.0;
    final d = _levenshtein(a, b);
    return 1.0 - (d / maxLen);
  }

  static int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    // Two-row dynamic programming to keep memory O(min(len)).
    final m = a.length;
    final n = b.length;
    var prev = List<int>.generate(n + 1, (i) => i);
    var curr = List<int>.filled(n + 1, 0);

    for (var i = 1; i <= m; i++) {
      curr[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        curr[j] = math.min(
          math.min(curr[j - 1] + 1, prev[j] + 1),
          prev[j - 1] + cost,
        );
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n];
  }

  static double _jaccard(Set<String> a, Set<String> b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final inter = a.intersection(b).length;
    final union = a.union(b).length;
    return inter / union;
  }
}
