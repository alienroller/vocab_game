import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/assignment_service.dart';

import '../../models/vocab.dart';
import '../../providers/profile_provider.dart';
import '../../services/word_session_service.dart';
import '../../services/word_stats_service.dart';
import '../../services/xp_service.dart';
import '../../theme/app_theme.dart';
import '../../games/quiz_game.dart';
import '../../games/flashcard_game.dart';
import '../../games/matching_game.dart';
import '../../games/memory_game.dart';
import '../../games/fill_blank_game.dart';

/// Library screen — the student's entry point to all word content.
///
/// Three layers: Collection grid → Unit list → Play.
/// Fetches published collections from Supabase with category filtering.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  List<Map<String, dynamic>> _collections = [];
  bool _loading = true;
  String _filter = 'all'; // 'all' | 'esl' | 'fiction' | 'academic'

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    try {
      final data = await Supabase.instance.client
          .from('collections')
          .select(
              'id, short_title, description, category, difficulty, cover_emoji, cover_color, total_units')
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load library: $e')),
        );
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
        title: const Text('Word Library',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 8),
                  _buildFilterBar(),
                  Expanded(
                    child: _collections.isEmpty
                        ? _buildEmptyState()
                        : _buildCollectionGrid(),
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
            'No collections yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your teacher will add word collections soon.',
            style: TextStyle(
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionGrid() {
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No ${_filter == "all" ? "" : _filter} collections found.',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
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
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UnitListScreen(collection: c),
            ),
          ),
        );
      },
    );
  }
}

// ─── Collection Card ─────────────────────────────────────────────────

class _CollectionCard extends StatelessWidget {
  final Map<String, dynamic> collection;
  final VoidCallback onTap;

  const _CollectionCard({required this.collection, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorHex = collection['cover_color'] as String? ?? '#4F46E5';
    final color =
        Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              collection['cover_emoji'] ?? '📚',
              style: const TextStyle(fontSize: 36),
            ),
            const Spacer(),
            Text(
              collection['short_title'] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _DifficultyBadge(collection['difficulty'] ?? 'A1'),
                const SizedBox(width: 6),
                Text(
                  '${collection['total_units'] ?? 0} units',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
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
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        level,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─── Unit List Screen ────────────────────────────────────────────────

/// Shows all units within a collection with mastery progress.
class UnitListScreen extends StatefulWidget {
  final Map<String, dynamic> collection;
  const UnitListScreen({super.key, required this.collection});

  @override
  State<UnitListScreen> createState() => _UnitListScreenState();
}

class _UnitListScreenState extends State<UnitListScreen> {
  List<Map<String, dynamic>> _units = [];
  bool _loading = true;
  String? _launchingUnitId;

  @override
  void initState() {
    super.initState();
    _loadUnits();
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
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _playUnit(Map<String, dynamic> unit) async {
    final unitId = unit['id'] as String;
    if (_launchingUnitId != null) return;
    setState(() => _launchingUnitId = unitId);

    try {
      // Load the best 10 words for this unit via spaced repetition
      final words = await WordSessionService.selectSessionWords(
        unitId: unit['id'] as String,
      );

      if (words.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No words found in this unit.')),
          );
        }
        return;
      }

      // Convert Supabase words to local Vocab model
      final vocabWords = words
          .map((w) => Vocab(
                id: w['id'] as String,
                english: w['word'] as String,
                uzbek: w['translation'] as String,
              ))
          .toList();

      if (!mounted) return;

      // Navigate to game selection with loaded words
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UnitGameSelectionScreen(
            unitTitle: unit['title'] as String? ?? 'Unit',
            unitId: unit['id'] as String,
            words: vocabWords,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading words: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _launchingUnitId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.collection['short_title'] ?? 'Units'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _units.isEmpty
                ? Center(
                    child: Text(
                      'No units available yet.',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                        16, MediaQuery.of(context).padding.top + kToolbarHeight + 16, 16, 24),
                    itemCount: _units.length,
                    itemBuilder: (context, index) {
                      final unit = _units[index];
                      final total = unit['word_count'] as int? ?? 10;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.glassCard(isDark: isDark),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${unit['unit_number'] ?? index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    unit['title'] ?? 'Unit ${unit['unit_number']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$total words',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? AppTheme.textSecondaryDark
                                          : AppTheme.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: AppTheme.borderRadiusMd,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.violet.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: FilledButton(
                                onPressed: _launchingUnitId != null ? null : () => _playUnit(unit),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                ),
                                child: _launchingUnitId == unit['id']
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Play ▶',
                                        style: TextStyle(fontWeight: FontWeight.w700)),
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

// ─── Unit Game Selection Screen ──────────────────────────────────────

/// Game selection screen specifically for Supabase unit words.
/// Shows the 5 standard games adapting pre-loaded words.
class UnitGameSelectionScreen extends StatefulWidget {
  final String unitTitle;
  final String unitId;
  final List<Vocab> words;
  final String? assignmentId; // non-null when launched from assignment mode

  const UnitGameSelectionScreen({
    super.key,
    required this.unitTitle,
    required this.unitId,
    required this.words,
    this.assignmentId,
  });

  @override
  State<UnitGameSelectionScreen> createState() => _UnitGameSelectionScreenState();
}

class _UnitGameSelectionScreenState extends State<UnitGameSelectionScreen> {
  bool _isNavigating = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final games = [
      {
        'title': 'Flashcards',
        'icon': Icons.style_rounded,
        'gradient': const [Color(0xFF4FC3F7), Color(0xFF0288D1)],
        'description': 'Flip cards to memorize vocabulary',
        'route': '/games/flashcard',
      },
      {
        'title': 'Quiz',
        'icon': Icons.quiz_rounded,
        'gradient': const [Color(0xFF66BB6A), Color(0xFF2E7D32)],
        'description': 'Test your knowledge with multiple choice',
        'route': '/games/quiz',
      },
      {
        'title': 'Matching',
        'icon': Icons.join_inner_rounded,
        'gradient': const [Color(0xFFFFB74D), Color(0xFFE65100)],
        'description': 'Match English and Uzbek word pairs',
        'route': '/games/matching',
      },
      {
        'title': 'Memory',
        'icon': Icons.grid_view_rounded,
        'gradient': const [Color(0xFFCE93D8), Color(0xFF7B1FA2)],
        'description': 'Find matching pairs in a grid',
        'route': '/games/memory',
      },
      {
        'title': 'Fill in Blank',
        'icon': Icons.keyboard_rounded,
        'gradient': const [Color(0xFFEF5350), Color(0xFFC62828)],
        'description': 'Type the missing translated letters',
        'route': '/games/fill-blank',
      },
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.unitTitle),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  '${widget.words.length} words loaded — choose a game:',
                  style: TextStyle(
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: games.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final game = games[index];
                    return GestureDetector(
                      onTap: () async {
                        if (_isNavigating) return;
                        setState(() => _isNavigating = true);
                        await context.push(
                          game['route'] as String,
                          extra: {
                            'customWords': widget.words,
                            'assignmentId': widget.assignmentId,
                          },
                        );
                        if (mounted) setState(() => _isNavigating = false);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: AppTheme.glassCard(isDark: isDark),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: game['gradient'] as List<Color>,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: (game['gradient'] as List<Color>).first.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                game['icon'] as IconData,
                                size: 28,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    game['title'] as String,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    game['description'] as String,
                                    style: TextStyle(
                                      color: isDark
                                          ? AppTheme.textSecondaryDark
                                          : AppTheme.textSecondaryLight,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: isDark
                                    ? AppTheme.textSecondaryDark
                                    : AppTheme.textSecondaryLight),
                          ],
                        ),
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
}
