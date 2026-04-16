import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/student_exam_provider.dart';
import '../../theme/app_theme.dart';

/// Shows the student a single exam invitation.
/// Join button → waits for teacher to press Start → navigates to exam runner.
class StudentExamLobbyScreen extends ConsumerWidget {
  final String sessionId;
  const StudentExamLobbyScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lobby = ref.watch(studentExamLobbyProvider(sessionId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = lobby.session;

    // If the session transitions to in_progress after the student joined,
    // navigate to the exam screen.
    if (session != null && session.isInProgress && lobby.joined) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.pushReplacement('/student/exam/$sessionId/take');
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(session?.title ?? 'Exam'),
      ),
      body: lobby.loading
          ? const Center(child: CircularProgressIndicator())
          : lobby.error != null
              ? _ErrorBody(message: lobby.error!)
              : _Body(session: session, lobby: lobby, isDark: isDark),
      bottomNavigationBar: _bottomBar(context, ref, lobby),
    );
  }

  Widget? _bottomBar(
    BuildContext context,
    WidgetRef ref,
    StudentExamLobbyState lobby,
  ) {
    final session = lobby.session;
    if (session == null || session.isFinished) return null;

    if (!lobby.joined) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.violet,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: lobby.loading
                ? null
                : () => ref
                    .read(studentExamLobbyProvider(sessionId).notifier)
                    .joinExam(),
            child: lobby.loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text('Join exam',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }

    // Joined but exam not yet started.
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            borderRadius: AppTheme.borderRadiusSm,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.amber),
              ),
              SizedBox(width: 10),
              Text('Waiting for teacher to start...',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.amber)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final dynamic session;
  final StudentExamLobbyState lobby;
  final bool isDark;
  const _Body({required this.session, required this.lobby, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (session == null) {
      return const Center(child: Text('Exam not found.'));
    }

    final status = session.status as String;
    if (status == 'cancelled' || status == 'abandoned') {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cancel_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text('This exam was cancelled.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Go back'),
            ),
          ],
        ),
      );
    }

    if (status == 'completed') {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 48, color: Colors.green),
            const SizedBox(height: 12),
            const Text('This exam has ended.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Go back'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(session.title as String,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _info(Icons.help_outline_rounded,
              '${session.questionCount} questions (multiple choice)'),
          _info(Icons.timer_outlined,
              '${session.perQuestionSeconds}s per question'),
          _info(Icons.hourglass_bottom_rounded,
              '${(session.totalSeconds as int) ~/ 60} min total'),
          const SizedBox(height: 24),
          if (lobby.joined)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: AppTheme.borderRadiusSm,
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('You\'re in! Waiting for the teacher to start.',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.green)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.violet),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
      );
}

class _ErrorBody extends StatelessWidget {
  final String message;
  const _ErrorBody({required this.message});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error: $message',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent)),
        ),
      );
}
