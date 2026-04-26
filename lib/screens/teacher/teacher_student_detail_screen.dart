import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/class_student.dart';
import '../../models/assignment_progress.dart';
import '../../providers/class_students_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/assignment_service.dart';
import '../../services/class_service.dart';
import '../../theme/app_theme.dart';

class TeacherStudentDetailScreen extends ConsumerStatefulWidget {
  final ClassStudent student;
  const TeacherStudentDetailScreen({super.key, required this.student});

  @override
  ConsumerState<TeacherStudentDetailScreen> createState() =>
      _TeacherStudentDetailScreenState();
}

class _TeacherStudentDetailScreenState
    extends ConsumerState<TeacherStudentDetailScreen> {
  Map<String, AssignmentProgress>? _progressMap;
  List<Map<String, dynamic>> _assignments = []; // We will fetch basic info of all active class assignments
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final progressMap = await AssignmentService.getStudentProgressMap(studentId: widget.student.id);
      final assignmentsList = await AssignmentService.getStudentAssignments(classCode: widget.student.classCode ?? '');
      
      if (mounted) {
        setState(() {
          _progressMap = progressMap;
          _assignments = assignmentsList.map((a) => {'id': a.id, 'title': a.unitTitle, 'book': a.bookTitle, 'total': a.wordCount}).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmRemove() async {
    final classCode = widget.student.classCode;
    if (classCode == null || classCode.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from class?'),
        content: Text(
          'Remove @${widget.student.username} from this class.\n\n'
          'Their XP, streak, and progress are kept — they can rejoin '
          'with the class code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ClassService.removeStudentFromClass(
        studentId: widget.student.id,
        classCode: classCode,
      );
      if (!mounted) return;
      // Refresh the active class's student list so the removed student
      // disappears immediately when the teacher pops back.
      final profile = ref.read(profileProvider);
      if (profile != null && profile.classCode != null) {
        await ref.read(classStudentsProvider.notifier).load(
          classCode: profile.classCode!,
          teacherId: profile.id,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed @${widget.student.username} from the class.'),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasClass = (widget.student.classCode ?? '').isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('@${widget.student.username}'),
        actions: [
          if (hasClass)
            PopupMenuButton<String>(
              tooltip: 'Student actions',
              onSelected: (v) {
                if (v == 'remove') _confirmRemove();
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove_outlined,
                          color: Colors.red, size: 18),
                      SizedBox(width: 10),
                      Text(
                        'Remove from class',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D3A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatCol('Level', '${widget.student.level}', Icons.star, Colors.blue),
                  _StatCol('XP', '${widget.student.xp}', Icons.bolt, Colors.orange),
                  _StatCol('Streak', '${widget.student.streakDays}', Icons.local_fire_department, Colors.red),
                  _StatCol('Accuracy', widget.student.accuracyDisplay, Icons.check_circle, Colors.green),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Detail Stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D3A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _DetailRow('Total Words Answered', '${widget.student.totalWordsAnswered}'),
                  const Divider(),
                  _DetailRow('Total Correct Answers', '${widget.student.totalCorrect}'),
                  const Divider(),
                  _DetailRow('Last Active', widget.student.daysSinceActive == null ? 'Never' : (widget.student.daysSinceActive == 0 ? 'Today' : '${widget.student.daysSinceActive} days ago')),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('Assignments Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (_assignments.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No active assignments for this class.')))
            else
              ..._assignments.map((assignment) {
                final aId = assignment['id'] as String;
                final progress = _progressMap?[aId];
                final mastered = progress?.wordsMastered ?? 0;
                final total = assignment['total'] as int;
                final pct = total > 0 ? mastered / total : 0.0;
                final isCompleted = progress?.isCompleted ?? false;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1D3A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(assignment['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(assignment['book'], style: const TextStyle(fontSize: 12, color: Colors.grey, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                          if (isCompleted)
                            const Icon(Icons.check_circle, color: Colors.green)
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: LinearProgressIndicator(value: pct, backgroundColor: isCompleted ? Colors.green.withValues(alpha: 0.2) : AppTheme.violet.withValues(alpha: 0.2), color: isCompleted ? Colors.green : AppTheme.violet, borderRadius: BorderRadius.circular(4), minHeight: 8)),
                          const SizedBox(width: 12),
                          Text('$mastered/$total', style: TextStyle(fontWeight: FontWeight.bold, color: isCompleted ? Colors.green : null)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCol(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
