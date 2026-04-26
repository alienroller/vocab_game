import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/teacher_class.dart';
import '../../../providers/assignment_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/teacher_classes_provider.dart';
import '../../../services/assignment_service.dart';
import '../../../theme/app_theme.dart';

class TeacherLibraryScreen extends ConsumerStatefulWidget {
  const TeacherLibraryScreen({super.key});

  @override
  ConsumerState<TeacherLibraryScreen> createState() => _TeacherLibraryScreenState();
}

class _TeacherLibraryScreenState extends ConsumerState<TeacherLibraryScreen> {
  List<Map<String, dynamic>> _collections = [];
  bool _loading = true;
  String _filter = 'all'; 

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    try {
      final data = await Supabase.instance.client
          .from('collections')
          .select('id, short_title, description, category, difficulty, cover_emoji, cover_color, total_units')
          .eq('is_published', true)
          .order('category')
          .order('difficulty');

      if (mounted) {
        setState(() {
          _collections = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load library: $e')));
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _collections;
    return _collections.where((c) => c['category'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Library', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 8),
                  _buildFilterBar(),
                  Expanded(
                    child: _collections.isEmpty ? _buildEmptyState() : _buildCollectionGrid(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      ('all', 'All'),
      ('esl', 'ESL'),
      ('fiction', 'Fiction'),
      ('academic', 'Academic'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final selected = _filter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f.$2),
              selected: selected,
              onSelected: (_) => setState(() => _filter = f.$1),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📚', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'No collections available',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Published word collections will appear here.',
            style: TextStyle(color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionGrid() {
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return Center(
        child: Text('No ${_filter == "all" ? "" : _filter} collections found.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final c = filtered[index];
         return _CollectionCard(
          collection: c,
          onTap: () {
            final profile = ref.read(profileProvider);
            if (profile != null && profile.classCode != null) {
              ref.read(assignmentProvider.notifier).loadTeacherAssignments(
                classCode: profile.classCode!,
                teacherId: profile.id,
              );
            }
            context.push('/teacher/library/units', extra: c);
          },
        );
      },
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final Map<String, dynamic> collection;
  final VoidCallback onTap;

  const _CollectionCard({required this.collection, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorHex = collection['cover_color'] as String? ?? '#4F46E5';
    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(collection['cover_emoji'] ?? '📚', style: const TextStyle(fontSize: 36)),
            const Spacer(),
            Text(
              collection['short_title'] ?? '',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _DifficultyBadge(collection['difficulty'] ?? 'A1'),
                const SizedBox(width: 6),
                Text('${collection['total_units'] ?? 0} units', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final String level;
  const _DifficultyBadge(this.level);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(6)),
      child: Text(level, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class TeacherUnitListScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> collection;
  const TeacherUnitListScreen({super.key, required this.collection});

  @override
  ConsumerState<TeacherUnitListScreen> createState() => _TeacherUnitListScreenState();
}

class _TeacherUnitListScreenState extends ConsumerState<TeacherUnitListScreen> {
  List<Map<String, dynamic>> _units = [];
  bool _loading = true;
  String? _assigningUnitId;

  @override
  void initState() {
    super.initState();
    _loadUnits();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(profileProvider);
      if (profile == null) return;
      // Make sure the teacher's classes are loaded so the assign sheet
      // can render multi-select even if the teacher landed straight here.
      ref.read(teacherClassesProvider.notifier).load(profile.id);
      if (profile.classCode != null) {
        ref.read(assignmentProvider.notifier).loadTeacherAssignments(
          classCode: profile.classCode!,
          teacherId: profile.id,
        );
      }
    });
  }

  Future<void> _loadUnits() async {
    try {
      final units = await Supabase.instance.client
          .from('units')
          .select('id, title, unit_number, word_count')
          .eq('collection_id', widget.collection['id'])
          .order('unit_number');

      if (mounted) {
        setState(() {
          _units = List<Map<String, dynamic>>.from(units);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAssignSheet(Map<String, dynamic> unit) async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    final classes = ref.read(teacherClassesProvider).classes;
    if (classes.isEmpty) {
      // Fall back: nothing to assign to. This shouldn't happen post-onboarding,
      // but better than a silent no-op.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a class before assigning units.')),
      );
      return;
    }

    final unitId = unit['id'] as String;
    Set<String> alreadyAssigned;
    try {
      alreadyAssigned = await AssignmentService.getAssignedClassCodesForUnit(
        teacherId: profile.id,
        unitId: unitId,
      );
    } catch (_) {
      alreadyAssigned = const <String>{};
    }
    if (!mounted) return;

    final result = await showModalBottomSheet<_AssignResult?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _AssignToClassesSheet(
        classes: classes,
        activeClassCode: profile.classCode,
        alreadyAssignedCodes: alreadyAssigned,
        unitTitle: unit['title']?.toString() ?? 'Unit',
      ),
    );
    if (result == null || result.classCodes.isEmpty) return;

    setState(() => _assigningUnitId = unitId);
    final failures = <String>[];
    try {
      for (final code in result.classCodes) {
        try {
          await AssignmentService.createAssignment(
            classCode: code,
            teacherId: profile.id,
            bookId: widget.collection['id'],
            bookTitle: widget.collection['short_title'] ?? '',
            unitId: unitId,
            unitTitle: unit['title'] ?? '',
            wordCount: unit['word_count'] ?? 10,
            dueDate: result.dueDate,
          );
        } catch (e) {
          failures.add('$code: $e');
        }
      }

      if (mounted) {
        if (profile.classCode != null) {
          unawaited(
            ref.read(assignmentProvider.notifier).loadTeacherAssignments(
              classCode: profile.classCode!,
              teacherId: profile.id,
            ),
          );
        }
        final messenger = ScaffoldMessenger.of(context);
        if (failures.isEmpty) {
          final n = result.classCodes.length;
          final dueSuffix = result.dueDate != null
              ? ' • due ${result.dueDate}'
              : '';
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Assigned to $n class${n == 1 ? '' : 'es'}$dueSuffix',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Some assignments failed: ${failures.join('; ')}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _assigningUnitId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assignmentState = ref.watch(assignmentProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(widget.collection['short_title'] ?? 'Units')),
      body: Container(
        decoration: BoxDecoration(gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient),
        child: _loading || assignmentState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : _units.isEmpty
                ? Center(child: Text('No units available yet.', style: TextStyle(color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight)))
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + kToolbarHeight + 16, 16, 24),
                    itemCount: _units.length,
                    itemBuilder: (context, index) {
                      final unit = _units[index];
                      final unitId = unit['id'] as String;
                      final total = unit['word_count'] as int? ?? 10;
                      
                      // "Assigned" badge reflects only the *active* class.
                      // Multi-class teachers get a fuller view inside the
                      // assign sheet (shows already-assigned classes greyed).
                      final isAssignedToActive = assignmentState.assignments
                          .any((a) => a.unitId == unitId && a.isActive);
                      final isBusy = _assigningUnitId == unitId;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.glassCard(isDark: isDark),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(12)),
                              alignment: Alignment.center,
                              child: Text(
                                '${unit['unit_number'] ?? index + 1}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(unit['title'] ?? 'Unit ${unit['unit_number']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text('$total words', style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight)),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: AppTheme.borderRadiusMd,
                              ),
                              child: FilledButton(
                                onPressed: isBusy
                                    ? null
                                    : () => _openAssignSheet(unit),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                child: isBusy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        isAssignedToActive
                                            ? 'Assigned ✓ • Assign more'
                                            : 'Assign',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

/// Result returned by [_AssignToClassesSheet] when the teacher confirms.
class _AssignResult {
  final List<String> classCodes;
  final String? dueDate; // ISO YYYY-MM-DD or null

  const _AssignResult({required this.classCodes, this.dueDate});
}

/// Bottom sheet that lets a teacher pick *which* classes to assign a unit
/// to (multi-select) and an optional due date. Classes that already have
/// an active assignment for this unit are pre-checked and disabled so the
/// teacher can see they are covered without re-assigning.
class _AssignToClassesSheet extends StatefulWidget {
  final List<TeacherClass> classes;
  final String? activeClassCode;
  final Set<String> alreadyAssignedCodes;
  final String unitTitle;

  const _AssignToClassesSheet({
    required this.classes,
    required this.activeClassCode,
    required this.alreadyAssignedCodes,
    required this.unitTitle,
  });

  @override
  State<_AssignToClassesSheet> createState() => _AssignToClassesSheetState();
}

class _AssignToClassesSheetState extends State<_AssignToClassesSheet> {
  late final Set<String> _selected;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    // Default selection: the active class, if it isn't already assigned.
    _selected = <String>{};
    final active = widget.activeClassCode;
    if (active != null &&
        !widget.alreadyAssignedCodes.contains(active) &&
        widget.classes.any((c) => c.code == active)) {
      _selected.add(active);
    }
  }

  Future<void> _pickDueDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? today.add(const Duration(days: 7)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  String? _formattedDueDate() {
    if (_dueDate == null) return null;
    final y = _dueDate!.year.toString().padLeft(4, '0');
    final m = _dueDate!.month.toString().padLeft(2, '0');
    final d = _dueDate!.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _selected.isNotEmpty;
    final dueText = _formattedDueDate() ?? 'No deadline';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Assign "${widget.unitTitle}"',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pick which classes get this unit.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.classes.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final c = widget.classes[i];
                  final alreadyAssigned =
                      widget.alreadyAssignedCodes.contains(c.code);
                  final checked =
                      alreadyAssigned || _selected.contains(c.code);
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: checked,
                    onChanged: alreadyAssigned
                        ? null
                        : (v) => setState(() {
                              if (v == true) {
                                _selected.add(c.code);
                              } else {
                                _selected.remove(c.code);
                              }
                            }),
                    title: Text(
                      c.className.isEmpty ? c.code : c.className,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      alreadyAssigned
                          ? 'Already assigned • ${c.studentCount} student'
                            '${c.studentCount == 1 ? '' : 's'}'
                          : '${c.code} • ${c.studentCount} student'
                            '${c.studentCount == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Due date'),
              subtitle: Text(dueText, style: const TextStyle(fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_dueDate != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Clear due date',
                      onPressed: () => setState(() => _dueDate = null),
                    ),
                  TextButton(
                    onPressed: _pickDueDate,
                    child: Text(_dueDate == null ? 'Set date' : 'Change'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: canSubmit
                      ? () => Navigator.pop(
                            context,
                            _AssignResult(
                              classCodes: _selected.toList(),
                              dueDate: _formattedDueDate(),
                            ),
                          )
                      : null,
                  child: Text(
                    canSubmit
                        ? 'Assign to ${_selected.length}'
                        : 'Pick classes',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
