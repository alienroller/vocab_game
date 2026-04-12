class WordStat {
  final String wordEnglish;
  final String wordUzbek;
  final int timesShown;
  final int timesCorrect;

  const WordStat({
    required this.wordEnglish,
    required this.wordUzbek,
    required this.timesShown,
    required this.timesCorrect,
  });

  factory WordStat.fromMap(Map<String, dynamic> map) {
    return WordStat(
      wordEnglish: map['word_english'] as String,
      wordUzbek: map['word_uzbek'] as String,
      timesShown: map['times_shown'] as int,
      timesCorrect: map['times_correct'] as int,
    );
  }

  // Class-level accuracy for this word (across all students)
  double get accuracy =>
      timesShown == 0 ? 0.0 : timesCorrect / timesShown;

  String get accuracyDisplay => '${(accuracy * 100).round()}%';

  // Difficulty tier: used for heatmap color
  // 'hard'   = accuracy < 0.40
  // 'medium' = accuracy 0.40 - 0.69
  // 'easy'   = accuracy >= 0.70
  String get difficultyTier {
    if (accuracy < 0.40) return 'hard';
    if (accuracy < 0.70) return 'medium';
    return 'easy';
  }
}
