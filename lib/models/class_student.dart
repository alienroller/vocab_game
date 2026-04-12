class ClassStudent {
  final String id;
  final String username;
  final int xp;
  final int level;
  final int streakDays;
  final int totalWordsAnswered;
  final int totalCorrect;
  final String? lastPlayedDate;   // 'YYYY-MM-DD' or null
  final String? classCode;

  const ClassStudent({
    required this.id,
    required this.username,
    required this.xp,
    required this.level,
    required this.streakDays,
    required this.totalWordsAnswered,
    required this.totalCorrect,
    this.lastPlayedDate,
    this.classCode,
  });

  factory ClassStudent.fromMap(Map<String, dynamic> map) {
    return ClassStudent(
      id: map['id'] as String,
      username: map['username'] as String,
      xp: map['xp'] as int,
      level: map['level'] as int,
      streakDays: map['streak_days'] as int,
      totalWordsAnswered: map['total_words_answered'] as int,
      totalCorrect: map['total_correct'] as int,
      lastPlayedDate: map['last_played_date'] as String?,
      classCode: map['class_code'] as String?,
    );
  }

  // Safe accuracy: returns 0.0 if no answers
  double get accuracy =>
      totalWordsAnswered == 0 ? 0.0 : totalCorrect / totalWordsAnswered;

  // For display: "74%" or "—"
  String get accuracyDisplay =>
      totalWordsAnswered == 0 ? '—' : '${(accuracy * 100).round()}%';

  // At-risk: hasn't played in 3 or more days
  bool get isAtRisk {
    if (lastPlayedDate == null) return true; // never played
    final last = DateTime.parse(lastPlayedDate!);
    final today = DateTime.now();
    final daysSince = DateTime(today.year, today.month, today.day)
        .difference(DateTime(last.year, last.month, last.day))
        .inDays;
    return daysSince >= 3;
  }

  // Days since last activity. Returns null if never played.
  int? get daysSinceActive {
    if (lastPlayedDate == null) return null;
    final last = DateTime.parse(lastPlayedDate!);
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day)
        .difference(DateTime(last.year, last.month, last.day))
        .inDays;
  }
}
