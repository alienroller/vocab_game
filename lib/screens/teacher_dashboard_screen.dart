import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/class_service.dart';

/// Teacher Dashboard — shows all students in the teacher's class with stats.
///
/// Accessible from the Profile screen when [isTeacher == true].
/// Displays a sortable table with: Username, XP, Level, Streak, Words, Accuracy.
class TeacherDashboardScreen extends ConsumerStatefulWidget {
  final String classCode;
  const TeacherDashboardScreen({super.key, required this.classCode});

  @override
  ConsumerState<TeacherDashboardScreen> createState() =>
      _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState
    extends ConsumerState<TeacherDashboardScreen> {
  List<Map<String, dynamic>> _students = [];
  bool _loading = true;
  _SortColumn _sortBy = _SortColumn.xp;
  bool _ascending = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final data = await ClassService.getClassStudents(widget.classCode);
    if (mounted) {
      setState(() {
        _students = data;
        _sortStudents();
        _loading = false;
      });
    }
  }

  void _sortStudents() {
    _students.sort((a, b) {
      dynamic aVal, bVal;
      switch (_sortBy) {
        case _SortColumn.username:
          aVal = (a['username'] as String? ?? '').toLowerCase();
          bVal = (b['username'] as String? ?? '').toLowerCase();
          break;
        case _SortColumn.xp:
          aVal = a['xp'] as int? ?? 0;
          bVal = b['xp'] as int? ?? 0;
          break;
        case _SortColumn.level:
          aVal = a['level'] as int? ?? 1;
          bVal = b['level'] as int? ?? 1;
          break;
        case _SortColumn.streak:
          aVal = a['streak_days'] as int? ?? 0;
          bVal = b['streak_days'] as int? ?? 0;
          break;
        case _SortColumn.words:
          aVal = a['total_words_answered'] as int? ?? 0;
          bVal = b['total_words_answered'] as int? ?? 0;
          break;
        case _SortColumn.accuracy:
          aVal = _calcAccuracy(a);
          bVal = _calcAccuracy(b);
          break;
      }
      final cmp = Comparable.compare(aVal as Comparable, bVal as Comparable);
      return _ascending ? cmp : -cmp;
    });
  }

  double _calcAccuracy(Map<String, dynamic> student) {
    final answered = student['total_words_answered'] as int? ?? 0;
    final correct = student['total_correct'] as int? ?? 0;
    if (answered == 0) return 0.0;
    return correct / answered * 100;
  }

  void _onSort(_SortColumn column) {
    setState(() {
      if (_sortBy == column) {
        _ascending = !_ascending;
      } else {
        _sortBy = column;
        _ascending = false;
      }
      _sortStudents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Class Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _loadStudents();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('👩‍🏫', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 16),
                      Text('No students yet',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        'Share class code ${widget.classCode} with your students',
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStudents,
                  child: Column(
                    children: [
                      // Class summary
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StatChip(
                              icon: Icons.people,
                              label: '${_students.length} Students',
                            ),
                            _StatChip(
                              icon: Icons.code,
                              label: widget.classCode,
                            ),
                          ],
                        ),
                      ),
                      // Sort headers
                      _buildSortHeader(theme),
                      const Divider(height: 1),
                      // Student rows
                      Expanded(
                        child: ListView.separated(
                          itemCount: _students.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final s = _students[index];
                            final accuracy = _calcAccuracy(s);

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  // Rank
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: index < 3
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme
                                                .onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  // Avatar + Name
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: theme
                                              .colorScheme.primaryContainer,
                                          child: Text(
                                            (s['username'] as String? ??
                                                    '?')[0]
                                                .toUpperCase(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: theme.colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            s['username'] ?? '???',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // XP
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${s['xp'] ?? 0}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  // Level
                                  SizedBox(
                                    width: 32,
                                    child: Text(
                                      '${s['level'] ?? 1}',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  // Streak
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      '${s['streak_days'] ?? 0}🔥',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  // Words
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${s['total_words_answered'] ?? 0}',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  // Accuracy
                                  SizedBox(
                                    width: 48,
                                    child: Text(
                                      '${accuracy.round()}%',
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: accuracy >= 70
                                            ? Colors.green
                                            : accuracy >= 40
                                                ? Colors.orange
                                                : Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSortHeader(ThemeData theme) {
    Widget header(String label, _SortColumn col,
        {int flex = 1, double? width}) {
      final isActive = _sortBy == col;
      final child = InkWell(
        onTap: () => _onSort(col),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (isActive)
              Icon(
                _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      );

      if (width != null) return SizedBox(width: width, child: child);
      return Expanded(flex: flex, child: child);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 28), // rank spacer
          header('Name', _SortColumn.username, flex: 3),
          header('XP', _SortColumn.xp, flex: 2),
          header('Lvl', _SortColumn.level, width: 32),
          header('🔥', _SortColumn.streak, width: 40),
          header('Words', _SortColumn.words, flex: 2),
          header('Acc', _SortColumn.accuracy, width: 48),
        ],
      ),
    );
  }
}

enum _SortColumn { username, xp, level, streak, words, accuracy }

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }
}
