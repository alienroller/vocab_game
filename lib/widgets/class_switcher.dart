import 'package:flutter/material.dart';

import '../models/teacher_class.dart';
import '../services/class_service.dart';
import '../theme/app_theme.dart';

/// Horizontally-scrollable pill row showing every class the teacher owns.
/// Highlights the active class and exposes a trailing "+" to create more
/// (when [onAdd] is provided). Long-press fires [onLongPress] for actions.
///
/// Used by My Classes (inline) and the Dashboard's switch-class sheet so
/// the same visual treatment is shown everywhere.
class ClassSwitcherRow extends StatelessWidget {
  final List<TeacherClass> classes;
  final bool isLoading;
  final String? activeCode;
  final ValueChanged<String> onSelect;
  final VoidCallback? onAdd;
  final ValueChanged<TeacherClass>? onLongPress;
  final EdgeInsetsGeometry padding;

  const ClassSwitcherRow({
    super.key,
    required this.classes,
    required this.activeCode,
    required this.onSelect,
    this.isLoading = false,
    this.onAdd,
    this.onLongPress,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 4),
  });

  bool get _atLimit => classes.length >= ClassService.maxClassesPerTeacher;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (isLoading && classes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  for (final c in classes)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClassChip(
                        label: c.className.isEmpty ? c.code : c.className,
                        subtitle: '${c.studentCount}',
                        isActive: c.code == activeCode,
                        isDark: isDark,
                        onTap: () => onSelect(c.code),
                        onLongPress: onLongPress == null
                            ? null
                            : () => onLongPress!(c),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (onAdd != null)
            Tooltip(
              message: _atLimit
                  ? 'Class limit reached '
                    '(${ClassService.maxClassesPerTeacher}/'
                    '${ClassService.maxClassesPerTeacher})'
                  : 'Create new class',
              child: IconButton.filledTonal(
                onPressed: _atLimit ? null : onAdd,
                icon: const Icon(Icons.add),
              ),
            ),
        ],
      ),
    );
  }
}

/// Single pill in the class switcher. Public so other surfaces (sheets,
/// onboarding) can reuse the same look.
class ClassChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ClassChip({
    super.key,
    required this.label,
    required this.subtitle,
    required this.isActive,
    required this.isDark,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = AppTheme.violet.withValues(alpha: 0.18);
    const activeBorder = AppTheme.violet;

    return Material(
      color: isActive
          ? activeBg
          : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isActive
                  ? activeBorder
                  : Colors.grey.withValues(alpha: 0.3),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? Icons.check_circle : Icons.class_,
                size: 14,
                color: isActive ? AppTheme.violet : Colors.grey,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isActive ? AppTheme.violet : null,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.violet
                      : Colors.grey.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : null,
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

/// Opens a modal bottom sheet that lets the teacher pick a different class
/// using the same chip-row UI as the My Classes screen. Returns the picked
/// code, or null if dismissed without selection.
Future<String?> showSwitchClassSheet({
  required BuildContext context,
  required List<TeacherClass> classes,
  required String? activeCode,
}) {
  return showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Switch class',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ClassSwitcherRow(
                classes: classes,
                activeCode: activeCode,
                onSelect: (code) => Navigator.pop(sheetCtx, code),
              ),
            ],
          ),
        ),
      );
    },
  );
}
