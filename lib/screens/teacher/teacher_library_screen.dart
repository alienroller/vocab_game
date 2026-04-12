import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../providers/assignment_provider.dart';
import '../../../providers/profile_provider.dart';
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
      if (profile != null && profile.classCode != null) {
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

  Future<void> _assignUnit(Map<String, dynamic> unit) async {
    final profile = ref.read(profileProvider);
    if (profile == null || profile.classCode == null) return;

    if (_assigningUnitId != null) return;
    setState(() => _assigningUnitId = unit['id'] as String);

    try {
      await AssignmentService.createAssignment(
        classCode: profile.classCode!,
        teacherId: profile.id,
        bookId: widget.collection['id'],
        bookTitle: widget.collection['short_title'] ?? '',
        unitId: unit['id'],
        unitTitle: unit['title'] ?? '',
        wordCount: unit['word_count'] ?? 10,
      );

      if (mounted) {
        ref.read(assignmentProvider.notifier).loadTeacherAssignments(
          classCode: profile.classCode!,
          teacherId: profile.id,
        );
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assigned successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error assigning unit: $e'), backgroundColor: Colors.red));
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
                      
                      final isAssigned = assignmentState.assignments.any((a) => a.unitId == unitId && a.isActive);

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
                                color: isAssigned ? (isDark ? Colors.grey[800] : Colors.grey[300]) : null,
                                gradient: isAssigned ? null : AppTheme.primaryGradient,
                                borderRadius: AppTheme.borderRadiusMd,
                              ),
                              child: FilledButton(
                                onPressed: isAssigned || _assigningUnitId != null ? null : () => _assignUnit(unit),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  disabledForegroundColor: isAssigned ? (isDark ? Colors.grey[400] : Colors.grey[600]) : Colors.white,
                                ),
                                child: _assigningUnitId == unit['id']
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text(isAssigned ? 'Assigned ✓' : 'Assign to Class', style: const TextStyle(fontWeight: FontWeight.w700)),
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
