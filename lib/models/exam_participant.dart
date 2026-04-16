/// Mirrors a row in the `exam_participants` table (migration 004).
class ExamParticipant {
  final String sessionId;
  final String studentId;
  final String status; // invited | joined | in_progress | completed | absent | timed_out
  final int shuffleSeed;
  final DateTime? joinedAt;
  final DateTime? finishedAt;
  final int? score;
  final int? correctCount;
  final int? totalCount;
  final int backgroundedCount;

  /// Denormalised — filled in by the service when joining against profiles.
  final String? username;

  const ExamParticipant({
    required this.sessionId,
    required this.studentId,
    required this.status,
    required this.shuffleSeed,
    this.joinedAt,
    this.finishedAt,
    this.score,
    this.correctCount,
    this.totalCount,
    this.backgroundedCount = 0,
    this.username,
  });

  factory ExamParticipant.fromMap(Map<String, dynamic> m, {String? username}) {
    return ExamParticipant(
      sessionId: m['session_id'] as String,
      studentId: m['student_id'] as String,
      status: m['status'] as String,
      shuffleSeed: (m['shuffle_seed'] as num).toInt(),
      joinedAt: m['joined_at'] == null
          ? null
          : DateTime.parse(m['joined_at'] as String),
      finishedAt: m['finished_at'] == null
          ? null
          : DateTime.parse(m['finished_at'] as String),
      score: (m['score'] as num?)?.toInt(),
      correctCount: (m['correct_count'] as num?)?.toInt(),
      totalCount: (m['total_count'] as num?)?.toInt(),
      backgroundedCount: (m['backgrounded_count'] as num?)?.toInt() ?? 0,
      username: username,
    );
  }

  bool get hasJoined =>
      status == 'joined' || status == 'in_progress' || status == 'completed';
  bool get isFinished =>
      status == 'completed' || status == 'absent' || status == 'timed_out';
}
