import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

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
  List<Map<String, dynamic>> _weakWords = const [];
  bool _loadingWeakWords = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _loadWeakWords();
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

  /// Loads this student's hardest words for the per-word breakdown
  /// (BUG SD2). Fails silently — the section auto-collapses if empty.
  Future<void> _loadWeakWords() async {
    try {
      final rows = await AssignmentService.getStudentWeakWords(
        studentId: widget.student.id,
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        _weakWords = rows;
        _loadingWeakWords = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingWeakWords = false);
    }
  }

  /// Copies a teacher → student nudge message template to the clipboard
  /// AND opens a share sheet so the teacher can paste it into whatever
  /// chat app the family uses (BUG SD4). Single-tap fix for the most
  /// common at-risk intervention.
  Future<void> _nudgeStudent() async {
    final daysSince = widget.student.daysSinceActive;
    final nameish = '@${widget.student.username}';
    final body = daysSince == null
        ? 'Hi $nameish — when you have a moment, please open VocabGame '
            'and start a quick practice session. Even 5 minutes a day adds up.'
        : 'Hi $nameish — I noticed your last VocabGame practice was '
            '$daysSince days ago. Spend 5 minutes today to keep your streak '
            'and grades on track.';
    await Clipboard.setData(ClipboardData(text: body));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied. Opening share sheet…'),
        duration: Duration(seconds: 2),
      ),
    );
    await Share.share(body);
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
          // BUG SD4 — Nudge action surfaces a copy/share message template
          // so the teacher can paste it into Telegram / WhatsApp / SMS.
          IconButton(
            tooltip: 'Send a nudge',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: _nudgeStudent,
          ),
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
                  _DetailRow('Total words answered', '${widget.student.totalWordsAnswered}'),
                  const Divider(),
                  _DetailRow('Total correct answers', '${widget.student.totalCorrect}'),
                  const Divider(),
                  // BUG SD3 — sentence case to match Dashboard / My Classes.
                  _DetailRow(
                    'Last active',
                    widget.student.daysSinceActive == null
                        ? 'Never'
                        : (widget.student.daysSinceActive == 0
                            ? 'Today'
                            : '${widget.student.daysSinceActive} day'
                                '${widget.student.daysSinceActive == 1 ? '' : 's'} ago'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // BUG SD2 — per-word weak spots. Highest-impact UX gap on this
            // screen ("which words is Sardor failing?" had no answer).
            _buildWeakWordsSection(isDark),

            const Text('Assignments progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  /// Per-word breakdown for this student. Shows their hardest 5 words
  /// (worst accuracy) so the teacher can drill into a remediation
  /// conversation. Auto-collapses when there's nothing to show.
  Widget _buildWeakWordsSection(bool isDark) {
    if (_loadingWeakWords) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.glassCard(isDark: isDark),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_weakWords.isEmpty) return const SizedBox(height: 8);

    final top = _weakWords.take(5).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hardest words for this student',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Sorted by accuracy (lowest first)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 12),
          Container(
            decoration: AppTheme.glassCard(isDark: isDark),
            child: Column(
              children: [
                for (var i = 0; i < top.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                top[i]['word_english']?.toString() ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15),
                              ),
                              Text(
                                top[i]['word_uzbek']?.toString() ?? '',
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
                        _accChip(top[i]),
                      ],
                    ),
                  ),
                  if (i < top.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accChip(Map<String, dynamic> row) {
    final shown = (row['times_shown'] as num?)?.toInt() ?? 0;
    final correct = (row['times_correct'] as num?)?.toInt() ?? 0;
    final pct = shown == 0 ? 0 : ((correct / shown) * 100).round();
    final color = pct >= 70
        ? Colors.green
        : pct >= 40
            ? Colors.orange
            : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$pct% ($correct/$shown)',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
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
