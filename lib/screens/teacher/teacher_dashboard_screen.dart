import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/class_students_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/class_service.dart';
import '../../services/teacher_message_service.dart';
import '../../theme/app_theme.dart';
import '../../models/teacher_message.dart';

class TeacherDashboardScreen extends ConsumerStatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  ConsumerState<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends ConsumerState<TeacherDashboardScreen> {
  TeacherMessage? _message;
  bool _isLoadingMessage = true;
  String? _className;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profile = ref.read(profileProvider);
    if (profile == null || profile.classCode == null) return;

    ref.read(classStudentsProvider.notifier).load(
      classCode: profile.classCode!,
      teacherId: profile.id,
    );

    // Fetch class name
    try {
      final classInfo = await ClassService.getClassInfo(profile.classCode!);
      if (mounted && classInfo != null) {
        setState(() => _className = classInfo['class_name'] as String?);
      }
    } catch (_) {}

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pin a Message', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () async {
                      try {
                        await TeacherMessageService.deleteMessage(classCode);
                        setState(() => _message = null);
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to clear: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    child: const Text('Clear', style: TextStyle(color: Colors.red)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final trimmed = controller.text.trim();
                        if (trimmed.isNotEmpty) {
                          await TeacherMessageService.setMessage(
                            classCode: classCode,
                            teacherId: teacherId,
                            message: trimmed,
                          );
                          final newMsg = await TeacherMessageService.getMessage(classCode);
                          if (context.mounted) setState(() => _message = newMsg);
                        }
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to save message. Try again.'),
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
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final classesState = ref.watch(classStudentsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(_className ?? (profile.classCode != null ? 'Class ${profile.classCode}' : 'Dashboard')),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              if (profile.classCode != null) {
                Share.share('Join my class on VocabGame! Code: ${profile.classCode}');
              }
            },
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
              // 1. Class Health Card
              if (classesState.healthScore != null) ...[
                GestureDetector(
                  onTap: () => context.push('/teacher/analytics'),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _getColorForTier(classesState.healthScore!.colorTier).withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getColorForTier(classesState.healthScore!.colorTier).withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        const Text('Class Health', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          '${classesState.healthScore!.score.round()}',
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                            color: _getColorForTier(classesState.healthScore!.colorTier),
                            height: 1,
                          ),
                        ),
                        Text(
                          classesState.healthScore!.label,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _getColorForTier(classesState.healthScore!.colorTier),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: [
                                Text('${(classesState.healthScore!.avgAccuracy * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const Text('Avg Accuracy', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                            Container(width: 1, height: 30, color: Colors.grey.withValues(alpha: 0.3)),
                            Column(
                              children: [
                                Text('${classesState.healthScore!.activeStudentsThisWeek}/${classesState.healthScore!.totalStudents}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const Text('Active (7d)', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 2. Teacher Message Card
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
              const SizedBox(height: 24),

              // 3. At-Risk Section
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
              ],
            ],
          ),
        ),
      ),
    ));
  }

  Color _getColorForTier(String tier) {
    switch (tier) {
      case 'green': return Colors.green;
      case 'amber': return Colors.orangeAccent;
      case 'orange': return Colors.orange;
      case 'red': return Colors.red;
      default: return Colors.grey;
    }
  }
}
