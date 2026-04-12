import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/class_student.dart';
import '../../providers/class_students_provider.dart';
import '../../providers/profile_provider.dart';
import '../../theme/app_theme.dart';

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
      if (profile != null && profile.classCode != null) {
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

  void _toggleSort(StudentSortType type) {
    setState(() {
      if (_sortType == type) {
        _sortAscending = !_sortAscending;
      } else {
        _sortType = type;
        // Default descending for stats, ascending for name
        _sortAscending = type == StudentSortType.name;
      }
    });
  }

  List<ClassStudent> _getSortedStudents(List<ClassStudent> students) {
    final list = List<ClassStudent>.from(students);
    list.sort((a, b) {
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

    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (classesState.isLoading && classesState.students.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (classesState.error != null && classesState.students.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Class')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                const Text('Could not load students', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text(classesState.error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    if (profile.classCode != null) {
                      ref.read(classStudentsProvider.notifier).load(
                        classCode: profile.classCode!,
                        teacherId: profile.id,
                      );
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sortedStudents = _getSortedStudents(classesState.students);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Class'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              if (profile.classCode != null) {
                Clipboard.setData(ClipboardData(text: profile.classCode!));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Class Info Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D3A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.classCode ?? '', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${classesState.students.length} students enrolled', style: const TextStyle(color: AppTheme.textSecondaryLight)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: AppTheme.violet),
                    onPressed: () {
                      if (profile.classCode != null) {
                        Share.share('Join my class on VocabGame! Code: ${profile.classCode}');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // 2. Sort Controls Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: StudentSortType.values.map((type) {
                final isSelected = _sortType == type;
                String label;
                switch (type) {
                  case StudentSortType.xp: label = 'XP'; break;
                  case StudentSortType.level: label = 'Level'; break;
                  case StudentSortType.streak: label = 'Streak'; break;
                  case StudentSortType.accuracy: label = 'Accuracy'; break;
                  case StudentSortType.name: label = 'Name'; break;
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
                        if (isSelected) Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 14),
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

          // 3. Student Table
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: sortedStudents.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final student = sortedStudents[index];
                
                // Original rank based on XP for 1,2,3 badges
                final xpRank = classesState.students.indexWhere((s) => s.id == student.id) + 1;
                
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

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 24, child: Text(rankDisplay, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                      const SizedBox(width: 12),
                      Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.violet.withValues(alpha: 0.2),
                            child: Text(student.username.isNotEmpty ? student.username[0].toUpperCase() : '?', style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.bold)),
                          ),
                          if (student.isAtRisk)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 12, height: 12,
                                decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  title: Text(student.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Lvl ${student.level} • ${student.xp >= 1000 ? '${(student.xp / 1000).toStringAsFixed(1)}k' : student.xp} XP'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (student.streakDays > 0) ...[
                        const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text('${student.streakDays}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        student.accuracyDisplay,
                        style: TextStyle(fontWeight: FontWeight.bold, color: accuracyColor),
                      ),
                    ],
                  ),
                  onTap: () {
                    context.push('/teacher/student-detail', extra: student);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
