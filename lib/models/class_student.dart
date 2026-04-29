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
  final DateTime? createdAt;      // when the profile row was created

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
    this.createdAt,
  });

  factory ClassStudent.fromMap(Map<String, dynamic> map) {
    DateTime? created;
    final raw = map['created_at'];
    if (raw is String && raw.isNotEmpty) {
      created = DateTime.tryParse(raw);
    }
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
      createdAt: created,
    );
  }

  // Safe accuracy: returns 0.0 if no answers
  double get accuracy =>
      totalWordsAnswered == 0 ? 0.0 : totalCorrect / totalWordsAnswered;

  // For display: "74%" or "—"
  String get accuracyDisplay =>
      totalWordsAnswered == 0 ? '—' : '${(accuracy * 100).round()}%';

  /// True if a "never played" student has been a class member long enough that
  /// the teacher should reasonably expect them to have started. Avoids tagging
  /// students who joined seconds ago as at-risk.
  ///
  /// Rule: account older than 24h. If creation timestamp is unknown (legacy
  /// rows), default to giving them the benefit of the doubt for one day —
  /// caller treats unknown-age + never-played as NOT at-risk.
  bool get _isPastNewStudentGrace {
    if (createdAt == null) return false;
    final ageHours = DateTime.now().difference(createdAt!).inHours;
    return ageHours >= 24;
  }

  /// At-risk semantics:
  ///   • Never played AND account is >24h old, OR
  ///   • Last played ≥ 3 days ago.
  /// A student who just joined this morning is NOT at-risk yet — that gave
  /// teachers a wall of red right after onboarding (BUG D1).
  bool get isAtRisk {
    if (lastPlayedDate == null) {
      return _isPastNewStudentGrace;
    }
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
