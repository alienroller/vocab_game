class AssignmentProgress {
  final String id;
  final String assignmentId;
  final String studentId;
  final String classCode;
  final int wordsMastered;
  final int totalWords;
  final bool isCompleted;
  final DateTime? lastPracticedAt;

  const AssignmentProgress({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.classCode,
    required this.wordsMastered,
    required this.totalWords,
    required this.isCompleted,
    this.lastPracticedAt,
  });

  factory AssignmentProgress.fromMap(Map<String, dynamic> map) {
    return AssignmentProgress(
      id: map['id'] as String,
      assignmentId: map['assignment_id'] as String,
      studentId: map['student_id'] as String,
      classCode: map['class_code'] as String,
      wordsMastered: map['words_mastered'] as int,
      totalWords: map['total_words'] as int,
      isCompleted: map['is_completed'] as bool,
      lastPracticedAt: map['last_practiced_at'] != null
          ? DateTime.parse(map['last_practiced_at'] as String)
          : null,
    );
  }

  // Progress as a value between 0.0 and 1.0
  double get progressRatio =>
      totalWords == 0 ? 0.0 : wordsMastered / totalWords;

  // For display: "14 / 25 words"
  String get progressLabel => '$wordsMastered / $totalWords words';
}
