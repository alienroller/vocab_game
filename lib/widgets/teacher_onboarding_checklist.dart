import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tiny onboarding card shown to new teachers on the Dashboard. Lists the
/// three "first thing to do" steps; each step shows a checkmark once met.
/// The card hides itself entirely once all three are done — no manual
/// dismiss needed.
///
/// The status booleans should be derived from the same providers the
/// dashboard already watches (student count, active assignment count,
/// teacher message presence).
class TeacherOnboardingChecklist extends StatelessWidget {
  final bool hasStudents;
  final bool hasAssignment;
  final bool hasMessage;
  final VoidCallback onShareCode;
  final VoidCallback onOpenLibrary;
  final VoidCallback onPinMessage;

  const TeacherOnboardingChecklist({
    super.key,
    required this.hasStudents,
    required this.hasAssignment,
    required this.hasMessage,
    required this.onShareCode,
    required this.onOpenLibrary,
    required this.onPinMessage,
  });

  bool get _allDone => hasStudents && hasAssignment && hasMessage;

  @override
  Widget build(BuildContext context) {
    if (_allDone) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.violet.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.violet.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppTheme.violet, size: 18),
              SizedBox(width: 8),
              Text(
                'Get your class going',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.violet,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ChecklistRow(
            done: hasStudents,
            label: 'Share your class code',
            subtitle: hasStudents
                ? 'Students have joined.'
                : 'Send the code so students can join.',
            actionLabel: 'Share',
            onAction: onShareCode,
          ),
          _ChecklistRow(
            done: hasAssignment,
            label: 'Assign a first unit',
            subtitle: hasAssignment
                ? 'At least one unit is assigned.'
                : 'Pick a unit from Library to give them work.',
            actionLabel: 'Library',
            onAction: onOpenLibrary,
          ),
          _ChecklistRow(
            done: hasMessage,
            label: 'Pin a class message',
            subtitle: hasMessage
                ? 'Your message is pinned.'
                : 'Tell students what to focus on this week.',
            actionLabel: 'Pin',
            onAction: onPinMessage,
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final bool done;
  final String label;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _ChecklistRow({
    required this.done,
    required this.label,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 22,
            color: done ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? Colors.grey : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (!done)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.violet,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }
}
