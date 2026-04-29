import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/exam_participant.dart';
import '../../models/exam_session.dart';
import '../../services/exam_service.dart';
import '../../theme/app_theme.dart';

/// Teacher's gradebook view after an exam completes.
/// Shows per-student scores, class average, and hardest questions.
class TeacherExamResultsScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const TeacherExamResultsScreen({super.key, required this.sessionId});

  @override
  ConsumerState<TeacherExamResultsScreen> createState() =>
      _TeacherExamResultsScreenState();
}

class _TeacherExamResultsScreenState
    extends ConsumerState<TeacherExamResultsScreen> {
  ExamSession? _session;
  List<ExamParticipant> _participants = [];
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _allAnswers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final session = await ExamService.fetchSession(widget.sessionId);
      final participants =
          await ExamService.fetchParticipants(widget.sessionId);
      final questions =
          await ExamService.fetchTeacherQuestions(widget.sessionId);
      final answers = await ExamService.fetchAllAnswers(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _session = session;
        _participants = participants;
        _questions = questions;
        _allAnswers = answers;
        _loading = false;
      });
    } catch (e, s) {
      debugPrint('ExamResults load failed: $e\n$s');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exam results')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exam results')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: $_error',
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ),
      );
    }

    // Build per-student scores.
    final answersByStudent = <String, List<Map<String, dynamic>>>{};
    for (final a in _allAnswers) {
      final sid = a['student_id'].toString();
      answersByStudent.putIfAbsent(sid, () => []).add(a);
    }

    // Build per-question accuracy.
    final totalQ = _questions.length;
    final questionAccuracy = <String, _QAcc>{};
    for (final q in _questions) {
      questionAccuracy[q['id'].toString()] = _QAcc(
        prompt: q['prompt'] as String,
        correctAnswer: q['correct_answer'] as String,
      );
    }
    for (final a in _allAnswers) {
      final qid = a['question_id'].toString();
      final acc = questionAccuracy[qid];
      if (acc != null) {
        acc.total++;
        if (a['is_correct'] == true) acc.correct++;
      }
    }

    // Sort students: completed first sorted by score desc, then the rest.
    final scored = _participants.where((p) => p.isFinished).toList()
      ..sort((a, b) =>
          (b.correctCount ?? 0).compareTo(a.correctCount ?? 0));
    final unscored = _participants.where((p) => !p.isFinished).toList();
    final sorted = [...scored, ...unscored];

    // Class averages.
    final scoredParticipants =
        scored.where((p) => p.correctCount != null).toList();
    final classAvg = scoredParticipants.isEmpty
        ? 0.0
        : scoredParticipants
                .map((p) => p.correctCount!)
                .reduce((a, b) => a + b) /
            scoredParticipants.length;
    final classPct =
        totalQ > 0 ? (classAvg / totalQ * 100) : 0.0;

    // Hardest questions — sorted by accuracy ascending.
    final hardest = questionAccuracy.values.toList()
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));

    return Scaffold(
      appBar: AppBar(
        title: Text(_session?.title ?? 'Results'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // ── Class summary ──────────────────────────────────────
          _SummaryCard(
            classAvg: classAvg,
            classPct: classPct,
            totalQ: totalQ,
            studentCount: scoredParticipants.length,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // ── Student scores ─────────────────────────────────────
          _sectionHeader('Student scores'),
          ...sorted.map((p) => _StudentScoreTile(
                participant: p,
                totalQ: totalQ,
                isDark: isDark,
              )),
          const SizedBox(height: 20),

          // ── Hardest questions ──────────────────────────────────
          _sectionHeader('Hardest questions'),
          ...hardest.take(5).map((q) => _QuestionAccTile(
                q: q,
                isDark: isDark,
              )),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Text(text,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800)),
      );
}

// ─── Summary card ────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double classAvg;
  final double classPct;
  final int totalQ;
  final int studentCount;
  final bool isDark;

  const _SummaryCard({
    required this.classAvg,
    required this.classPct,
    required this.totalQ,
    required this.studentCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final gradeColor = _gradeColor(classPct);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.violet.withValues(alpha: isDark ? 0.2 : 0.08),
            AppTheme.violet.withValues(alpha: isDark ? 0.08 : 0.02),
          ],
        ),
        borderRadius: AppTheme.borderRadiusMd,
      ),
      child: Row(
        children: [
          // Grade circle
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gradeColor.withValues(alpha: 0.15),
              border: Border.all(color: gradeColor, width: 2.5),
            ),
            alignment: Alignment.center,
            child: Text(
              '${classPct.round()}%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: gradeColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Class average',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  '${classAvg.toStringAsFixed(1)} / $totalQ correct',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '$studentCount students completed',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Student score tile ──────────────────────────────────────────────────────

class _StudentScoreTile extends StatelessWidget {
  final ExamParticipant participant;
  final int totalQ;
  final bool isDark;

  const _StudentScoreTile({
    required this.participant,
    required this.totalQ,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final p = participant;
    final correct = p.correctCount ?? 0;
    final answered = p.totalCount ?? 0;
    final pct = totalQ > 0 ? (correct / totalQ * 100).round() : 0;

    final Color statusColor;
    final String statusText;
    if (p.status == 'completed') {
      statusColor = _gradeColor(pct.toDouble());
      statusText = '$correct/$totalQ ($pct%)';
    } else if (p.status == 'absent') {
      statusColor = Colors.grey;
      statusText = 'Absent';
    } else if (p.status == 'timed_out') {
      statusColor = Colors.orange;
      statusText = '$correct/$answered (timed out)';
    } else {
      statusColor = Colors.grey;
      statusText = p.status;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
          borderRadius: AppTheme.borderRadiusSm,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.violet.withValues(alpha: 0.12),
              child: Text(
                (p.username ?? '?').isNotEmpty
                    ? (p.username ?? '?')[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.violet,
                    fontSize: 12),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(p.username ?? p.studentId,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            if (p.backgroundedCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Tooltip(
                  message:
                      'Left the app ${p.backgroundedCount} time(s) during the exam',
                  child: Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.amber.shade700),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(statusText,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor)),
            ),
          ],
        ),
      ),
    );
  }
}

// BUG E4 — single source of truth for grade colors lives in AppTheme.
// Reads the teacher's preset (lenient/strict) from Hive so a teacher who
// prefers strict US bands sees them across both the per-student tile and
// the class-summary circle.
Color _gradeColor(double pct) {
  final raw = Hive.box('userProfile').get('teacher_grade_band') as String?;
  return AppTheme.gradeColor(pct, band: AppTheme.gradeBandFromString(raw));
}

// ─── Question accuracy tile ──────────────────────────────────────────────────

class _QAcc {
  final String prompt;
  final String correctAnswer;
  int total = 0;
  int correct = 0;

  _QAcc({required this.prompt, required this.correctAnswer});

  double get accuracy => total > 0 ? correct / total : 0;
}

class _QuestionAccTile extends StatelessWidget {
  final _QAcc q;
  final bool isDark;
  const _QuestionAccTile({required this.q, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final pct = (q.accuracy * 100).round();
    final color = pct >= 70
        ? Colors.green
        : pct >= 50
            ? Colors.amber
            : Colors.redAccent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
          borderRadius: AppTheme.borderRadiusSm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.prompt,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(q.correctAnswer,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$pct% (${q.correct}/${q.total})',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
