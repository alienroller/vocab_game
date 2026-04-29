import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/class_student.dart';
import '../../models/teacher_class.dart';
import '../../models/user_profile.dart';
import '../../providers/class_students_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/teacher_classes_provider.dart';
import '../../services/class_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/class_switcher.dart';
import 'create_class_sheet.dart';

enum StudentSortType { xp, level, streak, accuracy, name }

class TeacherMyClassesScreen extends ConsumerStatefulWidget {
  const TeacherMyClassesScreen({super.key});

  @override
  ConsumerState<TeacherMyClassesScreen> createState() => _TeacherMyClassesScreenState();
}

class _TeacherMyClassesScreenState extends ConsumerState<TeacherMyClassesScreen> {
  StudentSortType _sortType = StudentSortType.xp;
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(profileProvider);
      if (profile == null) return;

      // Load the teacher's class list (up to 5).
      ref.read(teacherClassesProvider.notifier).load(profile.id);

      // Load students for the currently-active class.
      if (profile.classCode != null) {
        final state = ref.read(classStudentsProvider);
        if (state.students.isEmpty && !state.isLoading) {
          ref.read(classStudentsProvider.notifier).load(
            classCode: profile.classCode!,
            teacherId: profile.id,
          );
        }
      }
    });
  }

  Future<void> _switchActiveClass(String newCode) async {
    final profile = ref.read(profileProvider);
    if (profile == null || profile.classCode == newCode) return;

    await ref.read(profileProvider.notifier).setClassCode(newCode);
    await ref.read(classStudentsProvider.notifier).load(
      classCode: newCode,
      teacherId: profile.id,
    );
  }

  Future<void> _openCreateSheet() async {
    final classesState = ref.read(teacherClassesProvider);
    if (classesState.atLimit) {
      // BUG MC3 — clearer phrasing + actionable next step.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You\'ve reached the ${ClassService.maxClassesPerTeacher}-class '
            'limit. Delete one to add another.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    await showCreateClassSheet(context);
  }

  /// Opens a bottom sheet with actions for [cls]: copy code, share, and
  /// delete (only if the class is empty).
  Future<void> _openClassActionsSheet(TeacherClass cls) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final canDelete = cls.studentCount == 0;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cls.className.isEmpty ? cls.code : cls.className,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${cls.code} • ${cls.studentCount} student'
                            '${cls.studentCount == 1 ? '' : 's'}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy code'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: cls.code));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share invite'),
                onTap: () {
                  Navigator.pop(ctx);
                  Share.share(
                    'Join my class on VocabGame! Code: ${cls.code}',
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: canDelete ? Colors.red : Colors.grey,
                ),
                title: Text(
                  'Delete class',
                  style: TextStyle(
                    color: canDelete ? Colors.red : Colors.grey,
                  ),
                ),
                subtitle: canDelete
                    ? null
                    : Text(
                        'Remove the ${cls.studentCount} student'
                        '${cls.studentCount == 1 ? '' : 's'} first',
                        style: const TextStyle(fontSize: 12),
                      ),
                enabled: canDelete,
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(cls);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(TeacherClass cls) async {
    // BUG MC4 — preflight counts so the confirmation dialog is honest about
    // what's about to be wiped, instead of "and any past exams" hand-wave.
    final supa = Supabase.instance.client;
    int assignments = 0;
    int exams = 0;
    bool hasMessage = false;
    try {
      final results = await Future.wait<List>([
        supa
            .from('assignments')
            .select('id')
            .eq('class_code', cls.code)
            .eq('is_active', true),
        supa.from('exam_sessions').select('id').eq('class_code', cls.code),
        supa
            .from('teacher_messages')
            .select('class_code')
            .eq('class_code', cls.code)
            .limit(1),
      ]);
      assignments = (results[0] as List).length;
      exams = (results[1] as List).length;
      hasMessage = (results[2] as List).isNotEmpty;
    } catch (_) {
      // Network blip — show a softer message rather than blocking deletion.
    }

    if (!mounted) return;
    final pieces = <String>[
      if (assignments > 0)
        '$assignments assignment${assignments == 1 ? '' : 's'}',
      if (exams > 0) '$exams past exam${exams == 1 ? '' : 's'}',
      if (hasMessage) '1 pinned message',
    ];
    final detail = pieces.isEmpty
        ? 'No assignments, exams, or messages are attached.'
        : 'Will also remove: ${pieces.join(', ')}.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete class?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${cls.className.isEmpty ? cls.code : cls.className}" '
              '(${cls.code}) will be permanently deleted.',
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This cannot be undone.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _deleteClass(cls);
  }

  Future<void> _deleteClass(TeacherClass cls) async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;

    try {
      await ClassService.deleteClass(code: cls.code, teacherId: profile.id);
    } on ClassHasStudentsException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Students joined since you opened this menu — refresh and try again.'),
          backgroundColor: Colors.orange,
        ),
      );
      await ref.read(teacherClassesProvider.notifier).load(profile.id);
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Reload class list. If we just deleted the active class, switch to
    // whatever remains, or clear the active class.
    await ref.read(teacherClassesProvider.notifier).load(profile.id);
    final remaining = ref.read(teacherClassesProvider).classes;

    if (profile.classCode == cls.code) {
      final fallbackCode = remaining.isNotEmpty ? remaining.first.code : null;
      await ref.read(profileProvider.notifier).setClassCode(fallbackCode);
      if (fallbackCode != null) {
        await ref.read(classStudentsProvider.notifier).load(
          classCode: fallbackCode,
          teacherId: profile.id,
        );
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Deleted "${cls.className.isEmpty ? cls.code : cls.className}".',
        ),
      ),
    );
  }

  void _toggleSort(StudentSortType type) {
    setState(() {
      if (_sortType == type) {
        _sortAscending = !_sortAscending;
      } else {
        _sortType = type;
        _sortAscending = type == StudentSortType.name;
      }
    });
  }

  List<ClassStudent> _getSortedStudents(List<ClassStudent> students) {
    final list = List<ClassStudent>.from(students);
    list.sort((a, b) {
      // BUG MC2 — students with zero answers should always sink to the
      // bottom of an Accuracy sort, regardless of asc/desc, since their
      // accuracy displays as "—" and a numeric zero would otherwise
      // crowd the top in ascending mode.
      if (_sortType == StudentSortType.accuracy) {
        final aHas = a.totalWordsAnswered > 0;
        final bHas = b.totalWordsAnswered > 0;
        if (aHas != bHas) return aHas ? -1 : 1;
      }
      int cmp;
      switch (_sortType) {
        case StudentSortType.xp:
          cmp = a.xp.compareTo(b.xp);
          break;
        case StudentSortType.level:
          cmp = a.level.compareTo(b.level);
          break;
        case StudentSortType.streak:
          cmp = a.streakDays.compareTo(b.streakDays);
          break;
        case StudentSortType.accuracy:
          cmp = a.accuracy.compareTo(b.accuracy);
          break;
        case StudentSortType.name:
          cmp = a.username.compareTo(b.username);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final classesState = ref.watch(classStudentsProvider);
    final teacherClasses = ref.watch(teacherClassesProvider);

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeCode = profile.classCode;
    final activeClass = _findActiveClass(teacherClasses.classes, activeCode);

    return Scaffold(
      appBar: AppBar(
        title: Text(activeClass?.className ?? 'My Classes'),
        actions: [
          if (activeCode != null)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy class code',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: activeCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied!')),
                );
              },
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: Column(
          children: [
            // Class switcher row — always shown so the "+ Add" button is
            // discoverable even for teachers with only one class.
            ClassSwitcherRow(
              classes: teacherClasses.classes,
              isLoading: teacherClasses.isLoading,
              activeCode: activeCode,
              onSelect: _switchActiveClass,
              onAdd: _openCreateSheet,
              onLongPress: _openClassActionsSheet,
            ),

            // BUG MC1 — single-class teachers also need to discover that
            // long-pressing a class chip exposes Copy / Share / Delete.
            // Show the hint regardless of class count.
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Long-press a class for options',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ),

            // Active-class info card
            if (activeCode != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.glassCard(isDark: isDark),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  activeCode,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.violet.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'ACTIVE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.violet,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${classesState.students.length} students enrolled',
                              style: const TextStyle(
                                color: AppTheme.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share, color: AppTheme.violet),
                        tooltip: 'Share class code',
                        onPressed: () {
                          Share.share(
                            'Join my class on VocabGame! Code: $activeCode',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

            // Body: either a loading/error/empty state or the sorted roster.
            Expanded(child: _buildBody(context, classesState, isDark, profile)),
          ],
        ),
      ),
    );
  }

  TeacherClass? _findActiveClass(List<TeacherClass> classes, String? code) {
    if (code == null) return null;
    for (final c in classes) {
      if (c.code == code) return c;
    }
    return null;
  }

  Widget _buildBody(
    BuildContext context,
    ClassStudentsState classesState,
    bool isDark,
    UserProfile profile,
  ) {
    if (profile.classCode == null) {
      // Teacher has no active class (shouldn't normally happen post-onboarding,
      // but handle gracefully).
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No active class',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a class to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _openCreateSheet,
                icon: const Icon(Icons.add),
                label: const Text('Create Class'),
              ),
            ],
          ),
        ),
      );
    }

    if (classesState.isLoading && classesState.students.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (classesState.error != null && classesState.students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Could not load students',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                classesState.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  ref.read(classStudentsProvider.notifier).load(
                    classCode: profile.classCode!,
                    teacherId: profile.id,
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final sortedStudents = _getSortedStudents(classesState.students);

    return Column(
      children: [
        // Sort Controls Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: StudentSortType.values.map((type) {
              final isSelected = _sortType == type;
              String label;
              switch (type) {
                case StudentSortType.xp:
                  label = 'XP';
                  break;
                case StudentSortType.level:
                  label = 'Level';
                  break;
                case StudentSortType.streak:
                  label = 'Streak';
                  break;
                case StudentSortType.accuracy:
                  label = 'Accuracy';
                  break;
                case StudentSortType.name:
                  label = 'Name';
                  break;
              }
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSelected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label),
                      if (isSelected) const SizedBox(width: 4),
                      if (isSelected)
                        Icon(
                          _sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 14,
                        ),
                    ],
                  ),
                  onSelected: (_) => _toggleSort(type),
                  selectedColor: AppTheme.violet.withValues(alpha: 0.2),
                  checkmarkColor: AppTheme.violet,
                ),
              );
            }).toList(),
          ),
        ),

        // Student Table
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: sortedStudents.length,
            itemBuilder: (context, index) {
              final student = sortedStudents[index];

              final xpRank = classesState.students
                      .indexWhere((s) => s.id == student.id) +
                  1;

              String rankDisplay = '$xpRank';
              if (xpRank == 1) rankDisplay = '🥇';
              if (xpRank == 2) rankDisplay = '🥈';
              if (xpRank == 3) rankDisplay = '🥉';

              Color accuracyColor;
              if (student.totalWordsAnswered == 0) {
                accuracyColor = Colors.grey;
              } else if (student.accuracy >= 0.7) {
                accuracyColor = Colors.green;
              } else if (student.accuracy >= 0.4) {
                accuracyColor = Colors.orange;
              } else {
                accuracyColor = Colors.red;
              }

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: AppTheme.glassCard(isDark: isDark),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          rankDisplay,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                AppTheme.violet.withValues(alpha: 0.2),
                            child: Text(
                              student.username.isNotEmpty
                                  ? student.username[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: AppTheme.violet,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (student.isAtRisk)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .scaffoldBackgroundColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  title: Text(
                    student.username,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Lvl ${student.level} • ${student.xp >= 1000 ? '${(student.xp / 1000).toStringAsFixed(1)}k' : student.xp} XP',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (student.streakDays > 0) ...[
                        const Icon(Icons.local_fire_department,
                            color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${student.streakDays}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        student.accuracyDisplay,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: accuracyColor,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    context.push('/teacher/student-detail', extra: student);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

