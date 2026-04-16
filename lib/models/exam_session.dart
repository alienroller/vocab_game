/// Mirrors a row in the `exam_sessions` table (migration 004).
class ExamSession {
  final String id;
  final String teacherId;
  final String classCode;
  final String title;
  final List<String> bookIds;
  final List<String> unitIds;
  final int questionCount;
  final int perQuestionSeconds;
  final int totalSeconds;
  final String status; // lobby | in_progress | completed | cancelled | abandoned
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;

  const ExamSession({
    required this.id,
    required this.teacherId,
    required this.classCode,
    required this.title,
    required this.bookIds,
    required this.unitIds,
    required this.questionCount,
    required this.perQuestionSeconds,
    required this.totalSeconds,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
  });

  factory ExamSession.fromMap(Map<String, dynamic> m) {
    List<String> asList(Object? v) =>
        (v is List) ? v.map((e) => e.toString()).toList() : <String>[];
    return ExamSession(
      id: m['id'] as String,
      teacherId: m['teacher_id'] as String,
      classCode: m['class_code'] as String,
      title: m['title'] as String,
      bookIds: asList(m['book_ids']),
      unitIds: asList(m['unit_ids']),
      questionCount: (m['question_count'] as num).toInt(),
      perQuestionSeconds: (m['per_question_seconds'] as num).toInt(),
      totalSeconds: (m['total_seconds'] as num).toInt(),
      status: m['status'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      startedAt: m['started_at'] == null
          ? null
          : DateTime.parse(m['started_at'] as String),
      endedAt: m['ended_at'] == null
          ? null
          : DateTime.parse(m['ended_at'] as String),
    );
  }

  bool get isLobby => status == 'lobby';
  bool get isInProgress => status == 'in_progress';
  bool get isFinished =>
      status == 'completed' || status == 'cancelled' || status == 'abandoned';
}
