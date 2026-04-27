import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/assignment_provider.dart';
import '../../../providers/class_students_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/teacher_classes_provider.dart';
import '../../../providers/word_stats_provider.dart';
import '../../../services/assignment_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/class_health_card.dart';

class TeacherAnalyticsScreen extends ConsumerStatefulWidget {
  const TeacherAnalyticsScreen({super.key});

  @override
  ConsumerState<TeacherAnalyticsScreen> createState() => _TeacherAnalyticsScreenState();
}

class _TeacherAnalyticsScreenState extends ConsumerState<TeacherAnalyticsScreen> {
  final Map<String, Map<String, int>> _completionCache = {};
  bool _loading = false;
  bool _allClassesStats = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure the teacher's class list is loaded so the cross-class toggle
      // knows which codes to aggregate.
      final profile = ref.read(profileProvider);
      if (profile != null) {
        ref.read(teacherClassesProvider.notifier).load(profile.id);
      }
      _loadData();
    });
  }

  Future<void> _loadWordStats() async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    if (_allClassesStats) {
      final classes = ref.read(teacherClassesProvider).classes;
      final codes = classes.map((c) => c.code).toList();
      if (codes.isEmpty && profile.classCode != null) {
        codes.add(profile.classCode!);
      }
      await ref.read(wordStatsProvider.notifier).loadForTeacher(codes);
    } else if (profile.classCode != null) {
      await ref.read(wordStatsProvider.notifier).load(profile.classCode!);
    }
  }

  Future<void> _loadData() async {
    final profile = ref.read(profileProvider);
    if (profile == null || profile.classCode == null) return;

    setState(() => _loading = true);

    // Refresh students/health for the active class so the Class Health card
    // is current. classStudentsProvider is shared with Dashboard / My Classes.
    await ref.read(classStudentsProvider.notifier).load(
      classCode: profile.classCode!,
      teacherId: profile.id,
    );
    await ref.read(assignmentProvider.notifier).loadTeacherAssignments(classCode: profile.classCode!, teacherId: profile.id);
    await _loadWordStats();

    final state = ref.read(assignmentProvider);
    for (final assignment in state.assignments) {
      if (!_completionCache.containsKey(assignment.id)) {
        final summary = await AssignmentService.getAssignmentCompletionSummary(assignmentId: assignment.id, classCode: profile.classCode!);
        if (mounted) {
          setState(() {
            _completionCache[assignment.id] = summary;
          });
        }
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    // React to the active class changing so analytics reflect the new class.
    ref.listen<String?>(
      profileProvider.select((p) => p?.classCode),
      (prev, next) {
        if (prev != next) {
          _completionCache.clear();
          _loadData();
        }
      },
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assignmentState = ref.watch(assignmentProvider);
    final statsState = ref.watch(wordStatsProvider);
    final teacherClasses = ref.watch(teacherClassesProvider).classes;
    final classesState = ref.watch(classStudentsProvider);
    final showScopeToggle = teacherClasses.length >= 2;

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (classesState.healthScore != null) ...[
                ClassHealthCard(
                  score: classesState.healthScore!,
                  isDark: isDark,
                ),
                const SizedBox(height: 24),
              ],
              const Text('Assigned Units', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (_loading && assignmentState.assignments.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else if (assignmentState.assignments.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No active assignments. Go to Library to assign units.')))
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: assignmentState.assignments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final assignment = assignmentState.assignments[index];
                    final summary = _completionCache[assignment.id];
                    final completed = summary?['completed'] ?? 0;
                    final total = summary?['total'] ?? 0;
                    final pct = total > 0 ? completed / total : 0.0;

                    return Dismissible(
                      key: Key(assignment.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Remove Assignment?'),
                            content: const Text('Students will no longer see this in their assignments list. This does not delete their progress.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) {
                        AssignmentService.deactivateAssignment(assignment.id);
                        ref.read(assignmentProvider.notifier).removeAssignment(assignment.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A1D3A) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(assignment.unitTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(assignment.bookTitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: LinearProgressIndicator(value: pct, backgroundColor: AppTheme.violet.withValues(alpha: 0.2), color: AppTheme.violet, borderRadius: BorderRadius.circular(4), minHeight: 8)),
                                const SizedBox(width: 12),
                                Text('$completed/$total', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 32),

              Text(
                _allClassesStats
                    ? 'All-Classes Struggling Words'
                    : 'Class Struggling Words',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _allClassesStats
                    ? 'Aggregated across all your classes'
                    : 'Words students answer incorrectly most often',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              if (showScopeToggle) ...[
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('This class'),
                      icon: Icon(Icons.class_outlined, size: 16),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('All my classes'),
                      icon: Icon(Icons.workspaces_outline, size: 16),
                    ),
                  ],
                  selected: {_allClassesStats},
                  onSelectionChanged: (selection) async {
                    setState(() => _allClassesStats = selection.first);
                    await _loadWordStats();
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (statsState.isLoading && statsState.stats.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else if (statsState.stats.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No word stats available yet.')))
              else
                ...statsState.stats.take(20).map((stat) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1D3A) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(stat.wordEnglish, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text(stat.wordUzbek, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${(stat.accuracy * 100).round()}%', style: TextStyle(fontWeight: FontWeight.bold, color: stat.accuracy < 0.4 ? Colors.red : (stat.accuracy < 0.7 ? Colors.orange : Colors.green))),
                            Text('${stat.timesShown} attempts', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
