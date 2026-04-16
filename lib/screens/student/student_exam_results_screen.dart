import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/exam_service.dart';
import '../../theme/app_theme.dart';

/// Shows the student their exam score + wrong-answer review.
class StudentExamResultsScreen extends StatefulWidget {
  final String sessionId;
  final int correctCount;
  final int totalCount;
  final int totalQuestions;

  const StudentExamResultsScreen({
    super.key,
    required this.sessionId,
    required this.correctCount,
    required this.totalCount,
    required this.totalQuestions,
  });

  @override
  State<StudentExamResultsScreen> createState() =>
      _StudentExamResultsScreenState();
}

class _StudentExamResultsScreenState extends State<StudentExamResultsScreen> {
  List<_ReviewItem> _wrongAnswers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReview();
  }

  Future<void> _loadReview() async {
    try {
      final questions = await ExamService.fetchQuestions(widget.sessionId);
      final myAnswers = await ExamService.fetchMyAnswers(widget.sessionId);

      // Build a question lookup.
      final qMap = <String, Map<String, dynamic>>{};
      for (final q in questions) {
        qMap[q['id'].toString()] = q;
      }

      // Find wrong answers.
      final wrong = <_ReviewItem>[];
      for (final a in myAnswers) {
        if (a['is_correct'] == true) continue;
        final q = qMap[a['question_id'].toString()];
        if (q == null) continue;
        wrong.add(_ReviewItem(
          prompt: q['prompt'] as String,
          correctAnswer: q['correct_answer'] as String,
          studentAnswer: a['answer'] as String,
        ));
      }

      if (!mounted) return;
      setState(() {
        _wrongAnswers = wrong;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Review load failed: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.totalQuestions > 0
        ? (widget.correctCount / widget.totalQuestions * 100)
        : 0;
    final grade = pct >= 90
        ? 'A'
        : pct >= 80
            ? 'B'
            : pct >= 70
                ? 'C'
                : pct >= 60
                    ? 'D'
                    : 'F';
    final gradeColor = pct >= 70
        ? Colors.green
        : pct >= 60
            ? Colors.amber
            : Colors.redAccent;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unanswered = widget.totalQuestions - widget.totalCount;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Exam results'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            // ── Grade circle ─────────────────────────────────────
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gradeColor.withValues(alpha: isDark ? 0.18 : 0.1),
                  border: Border.all(color: gradeColor, width: 3),
                ),
                alignment: Alignment.center,
                child: Text(
                  grade,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: gradeColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Center(
              child: Text(
                '${widget.correctCount} / ${widget.totalQuestions} correct',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                '${pct.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: gradeColor,
                ),
              ),
            ),
            if (unanswered > 0) ...[
              const SizedBox(height: 6),
              Center(
                child: Text(
                  '$unanswered question${unanswered == 1 ? '' : 's'} unanswered (timed out)',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // ── Wrong answer review ──────────────────────────────
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_wrongAnswers.isNotEmpty) ...[
              const Text('Review your mistakes',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ..._wrongAnswers
                  .map((item) => _WrongAnswerTile(item: item, isDark: isDark)),
            ] else ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: AppTheme.borderRadiusSm,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events_rounded,
                          color: Colors.green, size: 22),
                      SizedBox(width: 8),
                      Text('Perfect score! No mistakes.',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.green)),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.violet,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
              ),
              onPressed: () => context.go('/home'),
              child: const Text('Back to home',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewItem {
  final String prompt;
  final String correctAnswer;
  final String studentAnswer;

  const _ReviewItem({
    required this.prompt,
    required this.correctAnswer,
    required this.studentAnswer,
  });
}

class _WrongAnswerTile extends StatelessWidget {
  final _ReviewItem item;
  final bool isDark;
  const _WrongAnswerTile({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final timedOut = item.studentAnswer == '__timed_out__';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white,
          borderRadius: AppTheme.borderRadiusSm,
          border: Border.all(
            color: Colors.redAccent.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.prompt,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.close_rounded,
                    size: 16, color: Colors.redAccent),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    timedOut ? 'No answer (timed out)' : item.studentAnswer,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.redAccent,
                      fontStyle:
                          timedOut ? FontStyle.italic : FontStyle.normal,
                      decoration: timedOut
                          ? null
                          : TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.check_rounded,
                    size: 16, color: Colors.green),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.correctAnswer,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
