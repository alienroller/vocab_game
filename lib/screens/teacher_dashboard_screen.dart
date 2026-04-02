import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/class_service.dart';
import '../theme/app_theme.dart';

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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title:
            const Text('Class Dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _loading = true);
              _loadStudents();
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('👩‍🏫', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 16),
                      Text('No students yet',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 8),
                      Text(
                        'Share class code ${widget.classCode} with your students',
                        style: TextStyle(
                            color: isDark
                                ? AppTheme.textSecondaryDark
                                : AppTheme.textSecondaryLight),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStudents,
                  child: Column(
                    children: [
                      // Class summary - glass card
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.fromLTRB(
                            16, MediaQuery.of(context).padding.top + kToolbarHeight + 8, 16, 12),
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.glassCard(isDark: isDark),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StatChip(
                              icon: Icons.people_rounded,
                              label: '${_students.length} Students',
                              isDark: isDark,
                            ),
                            Container(
                              width: 1,
                              height: 28,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                            _StatChip(
                              icon: Icons.code_rounded,
                              label: widget.classCode,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                      // Sort headers
                      _buildSortHeader(theme, isDark),
                      Divider(
                        height: 1,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                      ),
                      // Student rows
                      Expanded(
                        child: ListView.separated(
                          itemCount: _students.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.black.withValues(alpha: 0.03),
                          ),
                          itemBuilder: (context, index) {
                            final s = _students[index];
                            final accuracy = _calcAccuracy(s);

                            return Container(
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
                                        fontWeight: FontWeight.w800,
                                        color: index < 3
                                            ? AppTheme.violet
                                            : (isDark
                                                ? AppTheme.textSecondaryDark
                                                : AppTheme.textSecondaryLight),
                                      ),
                                    ),
                                  ),
                                  // Avatar + Name
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: AppTheme.primaryGradient,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            (s['username'] as String? ??
                                                    '?')[0]
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                              color: Colors.white,
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
                                          fontWeight: FontWeight.w700),
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
                                        fontWeight: FontWeight.w800,
                                        color: accuracy >= 70
                                            ? AppTheme.success
                                            : accuracy >= 40
                                                ? AppTheme.amber
                                                : AppTheme.error,
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
      ),
    );
  }

  Widget _buildSortHeader(ThemeData theme, bool isDark) {
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
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? AppTheme.violet
                    : (isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight),
              ),
            ),
            if (isActive)
              Icon(
                _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: AppTheme.violet,
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
  final bool isDark;
  const _StatChip({required this.icon, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppTheme.violet),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14)),
      ],
    );
  }
}
