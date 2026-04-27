import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/exam_session.dart';
import '../../providers/exam_provider.dart';
import '../../theme/app_theme.dart';

class TeacherExamsScreen extends ConsumerWidget {
  const TeacherExamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSessions = ref.watch(teacherExamSessionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exams'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/teacher/exams/create'),
        backgroundColor: AppTheme.violet,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New exam', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(teacherExamSessionsProvider),
        child: asyncSessions.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(message: e.toString()),
          data: (sessions) {
            if (sessions.isEmpty) return const _EmptyState();
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _SessionTile(session: sessions[i], isDark: isDark),
            );
          },
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final ExamSession session;
  final bool isDark;
  const _SessionTile({required this.session, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (session.status) {
      'lobby' => Colors.amber,
      'in_progress' => Colors.green,
      'completed' => Colors.blueGrey,
      'cancelled' => Colors.redAccent,
      'abandoned' => Colors.redAccent,
      _ => Colors.grey,
    };

    final label = switch (session.status) {
      'lobby' => 'Lobby',
      'in_progress' => 'Live',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      'abandoned' => 'Abandoned',
      _ => session.status,
    };

    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
      borderRadius: AppTheme.borderRadiusMd,
      child: InkWell(
        borderRadius: AppTheme.borderRadiusMd,
        onTap: () => context.push('/teacher/exams/${session.id}/lobby'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.violet.withValues(alpha: 0.12),
                  borderRadius: AppTheme.borderRadiusSm,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.assignment_turned_in_rounded,
                    color: AppTheme.violet),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${session.classCode} • ${session.questionCount} qs • '
                      '${(session.totalSeconds / 60).round()} min',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => ListView(
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          Text('No exams yet',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text(
            'Tap + to create your first exam for the class.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load exams:\n$message',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent)),
        ),
      );
}
