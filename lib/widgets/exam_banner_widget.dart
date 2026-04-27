import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/exam_session.dart';
import '../providers/student_exam_provider.dart';
import '../theme/app_theme.dart';

/// Renders a list of active exam invitations as tappable banners.
/// Intended to sit near the top of the student home screen.
class ExamBannerWidget extends ConsumerWidget {
  const ExamBannerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncExams = ref.watch(studentActiveExamsProvider);
    return asyncExams.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (exams) {
        if (exams.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: exams
                .map((e) => _ExamBannerTile(session: e))
                .toList(),
          ),
        );
      },
    );
  }
}

class _ExamBannerTile extends StatelessWidget {
  final ExamSession session;
  const _ExamBannerTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent;
    final String label;
    final IconData icon;

    if (session.isInProgress) {
      accent = Colors.green;
      label = 'LIVE NOW';
      icon = Icons.play_circle_rounded;
    } else {
      accent = Colors.amber.shade700;
      label = 'PENDING';
      icon = Icons.assignment_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: accent.withValues(alpha: isDark ? 0.14 : 0.09),
        borderRadius: AppTheme.borderRadiusMd,
        child: InkWell(
          borderRadius: AppTheme.borderRadiusMd,
          onTap: () =>
              context.push('/student/exam/${session.id}/lobby'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: accent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${session.questionCount} questions  •  '
                        '${(session.totalSeconds / 60).round()} min',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    color: accent, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
