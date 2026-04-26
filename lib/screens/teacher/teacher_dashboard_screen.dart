import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/class_students_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/teacher_classes_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/assignment_service.dart';
import '../../services/class_service.dart';
import '../../services/teacher_message_service.dart';
import '../../theme/app_theme.dart';
import '../../models/teacher_class.dart';
import '../../models/teacher_message.dart';
import '../../widgets/class_switcher.dart';
import '../../widgets/teacher_onboarding_checklist.dart';

class TeacherDashboardScreen extends ConsumerStatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  ConsumerState<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends ConsumerState<TeacherDashboardScreen> {
  TeacherMessage? _message;
  bool _isLoadingMessage = true;
  String? _className;
  int? _totalActiveAssignments;
  int? _totalAtRiskAllClasses;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Keep the class-picker in the app bar in sync even if the teacher has
    // not visited /teacher/classes this session, then fire the cross-class
    // at-risk count once the class list is available.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final profile = ref.read(profileProvider);
      if (profile != null) {
        await ref.read(teacherClassesProvider.notifier).load(profile.id);
        unawaited(_loadAtRiskCount());
      }
    });
  }

  Future<void> _loadAtRiskCount() async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    final classes = ref.read(teacherClassesProvider).classes;
    if (classes.isEmpty) return;
    try {
      final n = await AnalyticsService.getTeacherAtRiskCount(
        classCodes: classes.map((c) => c.code).toList(),
        teacherId: profile.id,
      );
      if (mounted) setState(() => _totalAtRiskAllClasses = n);
    } catch (e, s) {
      debugPrint('At-risk count failed: $e\n$s');
    }
  }

  Future<void> _switchActiveClass(String newCode) async {
    final profile = ref.read(profileProvider);
    if (profile == null || profile.classCode == newCode) return;
    await ref.read(profileProvider.notifier).setClassCode(newCode);
    // classStudentsProvider + dashboard data will reload via the ref.listen
    // in build() — we only need to refresh student data for the new class.
    await ref.read(classStudentsProvider.notifier).load(
      classCode: newCode,
      teacherId: profile.id,
    );
  }

  Future<void> _loadData() async {
    final profile = ref.read(profileProvider);
    if (profile == null || profile.classCode == null) return;

    ref.read(classStudentsProvider.notifier).load(
      classCode: profile.classCode!,
      teacherId: profile.id,
    );

    // Across-classes active assignment count (shown in the aggregate strip).
    // Per-teacher query, so class switch doesn't invalidate it.
    unawaited(
      AssignmentService.getActiveAssignmentCountForTeacher(profile.id)
          .then((n) {
        if (mounted) setState(() => _totalActiveAssignments = n);
      }).catchError((Object e, StackTrace s) {
        debugPrint('Active assignment count failed: $e\n$s');
      }),
    );

    // Cross-class at-risk count — requires the class list, so run it as a
    // fire-and-forget that will no-op if classes aren't loaded yet.
    unawaited(_loadAtRiskCount());

    // Fetch class name
    try {
      final classInfo = await ClassService.getClassInfo(profile.classCode!);
      if (mounted && classInfo != null) {
        setState(() => _className = classInfo['class_name'] as String?);
      }
    } catch (e, s) {
      debugPrint('Fetch class name failed: $e\n$s');
    }

    // Fetch pinned message
    try {
      final msg = await TeacherMessageService.getMessage(profile.classCode!);
      if (mounted) {
        setState(() {
          _message = msg;
          _isLoadingMessage = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMessage = false);
    }
  }

  void _editMessage(String classCode, String teacherId) {
    final controller = TextEditingController(text: _message?.message ?? '');
    final allClasses = ref.read(teacherClassesProvider).classes;
    final activeClass = _findActiveClass(allClasses, classCode);
    final activeClassLabel = activeClass?.className.isNotEmpty == true
        ? activeClass!.className
        : classCode;
    final hasMultipleClasses = allClasses.length > 1;
    var pinToAll = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final targetCount = pinToAll ? allClasses.length : 1;
            final scopeText = pinToAll
                ? 'Pinning to all $targetCount classes'
                : 'Pinning to $activeClassLabel';

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Pin a Message',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    scopeText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    maxLength: 200,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Test on Friday! Study Unit 4.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (hasMultipleClasses) ...[
                    const SizedBox(height: 4),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Pin to all my classes'),
                      subtitle: Text(
                        'Sends the same message to all ${allClasses.length} of your classes.',
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: pinToAll,
                      onChanged: (v) => setSheetState(() => pinToAll = v),
                    ),
                  ] else
                    const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () async {
                          try {
                            await TeacherMessageService.deleteMessage(classCode);
                            setState(() => _message = null);
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                          } catch (e) {
                            if (sheetContext.mounted) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to clear: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: const Text(
                          'Clear',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            final trimmed = controller.text.trim();
                            if (trimmed.isNotEmpty) {
                              final targetCodes = pinToAll
                                  ? allClasses.map((c) => c.code).toList()
                                  : [classCode];
                              await TeacherMessageService.setMessageForClasses(
                                classCodes: targetCodes,
                                teacherId: teacherId,
                                message: trimmed,
                              );
                              final newMsg = await TeacherMessageService
                                  .getMessage(classCode);
                              if (mounted) setState(() => _message = newMsg);
                            }
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                            if (mounted && pinToAll) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Pinned to ${allClasses.length} classes.',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (sheetContext.mounted) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to save message: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // React to the active class changing (teacher picked a different class
    // from the switcher in /teacher/classes). Reloads dashboard data against
    // the new class.
    ref.listen<String?>(
      profileProvider.select((p) => p?.classCode),
      (prev, next) {
        if (prev != next) {
          setState(() {
            _message = null;
            _isLoadingMessage = true;
            _className = null;
          });
          _loadData();
        }
      },
    );

    final profile = ref.watch(profileProvider);
    final classesState = ref.watch(classStudentsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final teacherClasses = ref.watch(teacherClassesProvider).classes;
    final activeClass = _findActiveClass(teacherClasses, profile.classCode);
    final titleText = _className
        ?? activeClass?.className
        ?? (profile.classCode != null ? 'Class ${profile.classCode}' : 'Dashboard');

    return Scaffold(
      appBar: AppBar(
        title: teacherClasses.length > 1
            ? _ClassPickerTitle(
                titleText: titleText,
                onTap: () async {
                  final picked = await showSwitchClassSheet(
                    context: context,
                    classes: teacherClasses,
                    activeCode: profile.classCode,
                  );
                  if (picked != null) await _switchActiveClass(picked);
                },
              )
            : Text(titleText),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share class code',
            onPressed: () {
              if (profile.classCode != null) {
                Share.share('Join my class on VocabGame! Code: ${profile.classCode}');
              }
            },
          ),
          // Profile is no longer a bottom-nav tab — reach it from here.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: IconButton(
              tooltip: 'Profile',
              onPressed: () => context.push('/teacher/profile'),
              icon: CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.violet.withValues(alpha: 0.15),
                child: Text(
                  profile.username.isNotEmpty
                      ? profile.username[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppTheme.violet,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 0. Across-classes aggregate strip (only for multi-class teachers)
              if (teacherClasses.length >= 2) ...[
                _AcrossClassesStrip(
                  classCount: teacherClasses.length,
                  totalStudents: teacherClasses.fold<int>(
                    0,
                    (sum, c) => sum + c.studentCount,
                  ),
                  activeAssignments: _totalActiveAssignments,
                  atRiskCount: _totalAtRiskAllClasses,
                  isDark: isDark,
                  onTap: () => context.push('/teacher/classes'),
                ),
                const SizedBox(height: 16),
              ],

              // 0.5. First-run checklist — auto-hides once all 3 steps done.
              TeacherOnboardingChecklist(
                hasStudents: classesState.students.isNotEmpty,
                hasAssignment: (_totalActiveAssignments ?? 0) > 0,
                hasMessage: _message != null,
                onShareCode: () {
                  if (profile.classCode != null) {
                    Share.share(
                      'Join my class on VocabGame! Code: ${profile.classCode}',
                    );
                  }
                },
                onOpenLibrary: () => context.go('/teacher/library'),
                onPinMessage: () {
                  if (profile.classCode != null) {
                    _editMessage(profile.classCode!, profile.id);
                  }
                },
              ),
              if (classesState.students.isEmpty ||
                  (_totalActiveAssignments ?? 0) == 0 ||
                  _message == null)
                const SizedBox(height: 16),

              // 1. At-Risk Section — most-actionable item, shown first.
              if (classesState.students.isNotEmpty && classesState.healthScore != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('⚠️ At Risk — ${classesState.healthScore!.atRiskCount} students', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange)),
                    if (classesState.healthScore!.atRiskCount > 5)
                      TextButton(
                        onPressed: () => context.push('/teacher/analytics'),
                        child: const Text('View all →'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (classesState.healthScore!.atRiskCount == 0)
                  const Text('✅ All students practiced recently', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                else
                  ...classesState.students.where((s) => s.isAtRisk).take(5).map((student) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: AppTheme.glassCard(isDark: isDark),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                        child: Text(student.username.isNotEmpty ? student.username[0].toUpperCase() : '?', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(student.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(student.lastPlayedDate == null ? 'Never played' : 'Last active: ${student.daysSinceActive} days ago', style: const TextStyle(color: Colors.red)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/teacher/student-detail', extra: student),
                    ),
                  )),
                const SizedBox(height: 24),
              ] else if (classesState.students.isNotEmpty && classesState.healthScore == null) ...[
                Container(
                  decoration: AppTheme.glassCard(isDark: isDark),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        const SizedBox(width: 12),
                        const Text('Health score unavailable — pull to refresh'),
                      ],
                    ),
                ),
                const SizedBox(height: 24),
              ],

              // 2. Teacher Message Card — composer, lower priority than
              //    intervening with at-risk students.
              Container(
                decoration: AppTheme.glassCard(isDark: isDark),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (profile.classCode != null) _editMessage(profile.classCode!, profile.id);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.push_pin, size: 18, color: AppTheme.violet),
                                  SizedBox(width: 8),
                                  Text('Class Message', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.violet)),
                                ],
                              ),
                              const Icon(Icons.edit, size: 16, color: Colors.grey),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_isLoadingMessage)
                            const CircularProgressIndicator()
                          else if (_message != null)
                            Text(_message!.message, style: const TextStyle(fontSize: 15))
                          else
                            const Text('📌 Pin a message for students', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  TeacherClass? _findActiveClass(List<TeacherClass> classes, String? code) {
    if (code == null) return null;
    for (final c in classes) {
      if (c.code == code) return c;
    }
    return null;
  }
}

/// Tappable app-bar title that opens [showSwitchClassSheet] so the teacher
/// can switch active class without leaving the dashboard. The sheet uses
/// the same [ClassSwitcherRow] as the My Classes screen for visual parity.
class _ClassPickerTitle extends StatelessWidget {
  final String titleText;
  final VoidCallback onTap;

  const _ClassPickerTitle({
    required this.titleText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(titleText, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 24),
          ],
        ),
      ),
    );
  }
}

/// Compact strip showing aggregate counts across all the teacher's classes.
/// Tapping it opens the full classes list.
class _AcrossClassesStrip extends StatelessWidget {
  final int classCount;
  final int totalStudents;
  final int? activeAssignments;
  final int? atRiskCount;
  final bool isDark;
  final VoidCallback onTap;

  const _AcrossClassesStrip({
    required this.classCount,
    required this.totalStudents,
    required this.activeAssignments,
    required this.atRiskCount,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      'Across $classCount classes',
      '$totalStudents student${totalStudents == 1 ? '' : 's'}',
      if (activeAssignments != null)
        '$activeAssignments assignment${activeAssignments == 1 ? '' : 's'}',
    ];
    final showAtRisk = atRiskCount != null && atRiskCount! > 0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: AppTheme.glassCard(isDark: isDark),
          child: Row(
            children: [
              const Icon(Icons.workspaces_outline,
                  size: 20, color: AppTheme.violet),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  parts.join(' • '),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              if (showAtRisk) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '$atRiskCount at risk',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
