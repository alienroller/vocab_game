import 'dart:math' as math;

/// Pronunciation similarity for a learner's transcript against a target phrase.
///
/// Uses token-level sequence alignment (not bag-of-words) to compute two
/// independent signals:
///   - **recall**    — did the learner say all the target words?
///   - **precision** — did the learner say only the target words (no extras)?
///
/// Both must clear their own threshold to pass. This asymmetric gate rejects
/// cases like "what is your fucking name" (recall 1.0, precision 0.80) that a
/// symmetric metric like Jaccard would accept. Minor word drops by the STT
/// engine ("what is your name" → "what your name") still pass because the
/// recall bar is set below 1.0.
///
/// Individual tokens are matched fuzzily via Levenshtein ratio so STT typos
/// ("wood" ↔ "would") count as hits rather than substitutions.
class PronunciationScorer {
  /// Legacy single-number threshold used by older callers that still compare
  /// `score() >= threshold`. [passes] is the authoritative gate.
  static const double defaultThreshold = 0.65;

  static const double defaultRecall = 0.75;
  static const double defaultPrecision = 0.85;

  /// A said-token counts as matching a want-token if their character-level
  /// Levenshtein ratio is at least this. 0.80 catches short-vowel typos
  /// (wood/would) without letting unrelated words collide.
  static const double _tokenMatchRatio = 0.80;

  /// STT engines often emit these as real tokens. They're stripped before
  /// scoring so hesitation doesn't hurt precision.
  static const Set<String> _fillers = {
    'uh', 'uhh', 'uhm',
    'um', 'umm',
    'er', 'err',
    'ah', 'ahh',
    'hmm', 'hm', 'mhm', 'mm',
    'eh',
  };

  const PronunciationScorer();

  /// F1 of precision and recall in `[0, 1]`. Used for UI display; the real
  /// pass/fail gate is [passes].
  double score(String transcription, String target) {
    final said = _tokenize(transcription);
    final want = _tokenize(target);
    if (said.isEmpty || want.isEmpty) return 0.0;
    final a = _align(said, want);
    final p = a.precision;
    final r = a.recall;
    if (p + r == 0) return 0.0;
    return 2 * p * r / (p + r);
  }

  /// Passes iff both recall and precision clear their thresholds.
  bool passes(
    String transcription,
    String target, {
    double recall = defaultRecall,
    double precision = defaultPrecision,
  }) {
    final said = _tokenize(transcription);
    final want = _tokenize(target);
    if (said.isEmpty || want.isEmpty) return false;
    final a = _align(said, want);
    return a.recall >= recall && a.precision >= precision;
  }

  // ─── Internals ─────────────────────────────────────────────────────

  static List<String> _tokenize(String s) {
    final cleaned = s
        .toLowerCase()
        .replaceAll(RegExp(r"[^\w\s']"), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return const [];
    return [
      for (final t in cleaned.split(' '))
        if (t.isNotEmpty && !_fillers.contains(t)) t,
    ];
  }

  /// Token-level Needleman-Wunsch style alignment. Cost 1 for substitution
  /// and for insertion/deletion, cost 0 for a fuzzy token match.
  static _Alignment _align(List<String> said, List<String> want) {
    final m = said.length;
    final n = want.length;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      dp[0][j] = j;
    }
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final match = _tokensMatch(said[i - 1], want[j - 1]);
        final cost = match ? 0 : 1;
        dp[i][j] = math.min(
          math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1),
          dp[i - 1][j - 1] + cost,
        );
      }
    }

    var i = m;
    var j = n;
    var matches = 0;
    var subs = 0;
    var ins = 0; // extra said tokens
    var del = 0; // missing want tokens
    while (i > 0 || j > 0) {
      if (i > 0 && j > 0) {
        final match = _tokensMatch(said[i - 1], want[j - 1]);
        final cost = match ? 0 : 1;
        if (dp[i][j] == dp[i - 1][j - 1] + cost) {
          if (match) {
            matches++;
          } else {
            subs++;
          }
          i--;
          j--;
          continue;
        }
      }
      if (i > 0 && dp[i][j] == dp[i - 1][j] + 1) {
        ins++;
        i--;
        continue;
      }
      if (j > 0 && dp[i][j] == dp[i][j - 1] + 1) {
        del++;
        j--;
        continue;
      }
      break; // defensive
    }

    return _Alignment(
      matches: matches,
      substitutions: subs,
      insertions: ins,
      deletions: del,
    );
  }

  /// Fuzzy token equality: character-level Levenshtein ratio ≥ 0.80.
  static bool _tokensMatch(String a, String b) {
    if (a == b) return true;
    final maxLen = math.max(a.length, b.length);
    if (maxLen == 0) return true;
    final d = _levenshtein(a, b);
    return (1 - d / maxLen) >= _tokenMatchRatio;
  }

  static int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
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
}

class _Alignment {
  final int matches;
  final int substitutions;
  final int insertions;
  final int deletions;

  const _Alignment({
    required this.matches,
    required this.substitutions,
    required this.insertions,
    required this.deletions,
  });

  /// Fraction of said tokens that are correct (aligned matches).
  double get precision {
    final said = matches + substitutions + insertions;
    if (said == 0) return 0.0;
    return matches / said;
  }

  /// Fraction of target tokens that were said (aligned matches).
  double get recall {
    final want = matches + substitutions + deletions;
    if (want == 0) return 0.0;
    return matches / want;
  }
}
