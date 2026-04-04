import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/vocab.dart';
import '../../providers/profile_provider.dart';
import '../../services/word_session_service.dart';
import '../../services/xp_service.dart';
import '../../theme/app_theme.dart';

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
          builder: (_) => _UnitGameSelectionScreen(
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
/// Shows the same game types but uses pre-loaded words instead of Hive vocab.
class _UnitGameSelectionScreen extends StatelessWidget {
  final String unitTitle;
  final String unitId;
  final List<Vocab> words;

  const _UnitGameSelectionScreen({
    required this.unitTitle,
    required this.unitId,
    required this.words,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final games = [
      {
        'title': 'Quiz',
        'icon': Icons.quiz,
        'gradient': AppTheme.primaryGradient,
        'description': 'Test your knowledge with multiple choice',
      },
      {
        'title': 'Flashcards',
        'icon': Icons.style,
        'gradient': const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
        ),
        'description': 'Flip cards to memorize vocabulary',
      },
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(unitTitle),
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
                  '${words.length} words loaded — choose a game:',
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UnitQuizGame(
                              unitId: unitId,
                              unitTitle: unitTitle,
                              words: words,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: AppTheme.glassCard(isDark: isDark),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: game['gradient'] as LinearGradient,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.violet.withValues(alpha: 0.2),
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

// ─── Unit Quiz Game ──────────────────────────────────────────────────

/// Quiz game that uses Supabase-loaded words with XP, mastery tracking,
/// and speed bonuses.
class UnitQuizGame extends ConsumerStatefulWidget {
  final String unitId;
  final String unitTitle;
  final List<Vocab> words;

  const UnitQuizGame({
    super.key,
    required this.unitId,
    required this.unitTitle,
    required this.words,
  });

  @override
  ConsumerState<UnitQuizGame> createState() => _UnitQuizGameState();
}

class _UnitQuizGameState extends ConsumerState<UnitQuizGame> {
  late List<Vocab> _quizWords;
  int _currentIndex = 0;
  int _score = 0;
  int _totalXp = 0;
  List<String> _options = [];
  bool _answered = false;
  int? _selectedIndex;
  late DateTime _questionStartTime;

  @override
  void initState() {
    super.initState();
    _quizWords = List.from(widget.words)..shuffle(Random());
    _generateOptions();
  }

  void _generateOptions() {
    final current = _quizWords[_currentIndex];
    final distractors = widget.words
        .where((v) => v.id != current.id)
        .toList()
      ..shuffle(Random());
    final wrongAnswers =
        distractors.take(3).map((v) => v.uzbek).toList();
    _options = [current.uzbek, ...wrongAnswers]..shuffle(Random());
    _answered = false;
    _selectedIndex = null;
    _questionStartTime = DateTime.now();
  }

  void _onAnswer(int index) {
    if (_answered) return;

    final isCorrect = _options[index] == _quizWords[_currentIndex].uzbek;
    final elapsed =
        DateTime.now().difference(_questionStartTime).inSeconds;
    final secondsLeft = max(0, 20 - elapsed);

    // Calculate XP via speed bonus
    final streakDays =
        Hive.box('userProfile').get('streakDays', defaultValue: 0) as int;
    final xpGained = XpService.calculateXp(
      correct: isCorrect,
      secondsLeft: secondsLeft,
      maxSeconds: 20,
      streakDays: streakDays,
    );

    setState(() {
      _answered = true;
      _selectedIndex = index;
      if (isCorrect) {
        _score++;
        _totalXp += xpGained;
      }
    });

    // Record mastery for this word
    WordSessionService.recordAnswer(
      wordId: _quizWords[_currentIndex].id,
      isCorrect: isCorrect,
    );

    // Advance after short delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (_currentIndex < _quizWords.length - 1) {
        setState(() {
          _currentIndex++;
          _generateOptions();
        });
      } else {
        _finishGame();
      }
    });
  }

  Future<void> _finishGame() async {
    // Use ProfileProvider as the single source of truth —
    // handles XP, accuracy stats, Hive persistence, and Supabase sync.
    await ref.read(profileProvider.notifier).recordGameSession(
      xpGained: _totalXp,
      totalQuestions: _quizWords.length,
      correctAnswers: _score,
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _UnitResultScreen(
          unitTitle: widget.unitTitle,
          score: _score,
          total: _quizWords.length,
          xpGained: _totalXp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final current = _quizWords[_currentIndex];
    final progress = (_currentIndex + 1) / _quizWords.length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.unitTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_currentIndex + 1}/${_quizWords.length}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                const SizedBox(height: 10),
                // XP counter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Score: $_score',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.amber.withValues(alpha: isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('⚡ $_totalXp XP',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.amber,
                          )),
                    ),
                  ],
                ),
                const Spacer(),
                // Question - glass card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  decoration: AppTheme.glassCard(isDark: isDark),
                  child: Column(
                    children: [
                      Text(
                        current.english,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'What is the Uzbek translation?',
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Options - glass cards
                ...List.generate(_options.length, (i) {
                  Color getBg() {
                    if (!_answered) {
                      return isDark
                          ? const Color(0xFF1E2140).withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.8);
                    }
                    if (_options[i] == current.uzbek) {
                      return AppTheme.success.withValues(alpha: isDark ? 0.15 : 0.1);
                    }
                    if (i == _selectedIndex) {
                      return AppTheme.error.withValues(alpha: isDark ? 0.15 : 0.1);
                    }
                    return isDark
                        ? const Color(0xFF1E2140).withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.6);
                  }

                  Color getBorder() {
                    if (!_answered) {
                      return isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06);
                    }
                    if (_options[i] == current.uzbek) return AppTheme.success;
                    if (i == _selectedIndex) return AppTheme.error;
                    return isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03);
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: _answered ? null : () => _onAnswer(i),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: getBg(),
                          borderRadius: AppTheme.borderRadiusMd,
                          border: Border.all(color: getBorder(), width: 2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.violet.withValues(alpha: 0.1),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                ['A', 'B', 'C', 'D'][i],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.violet,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                _options[i],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: i == _selectedIndex
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (_answered && _options[i] == current.uzbek)
                              const Icon(Icons.check_circle_rounded,
                                  color: AppTheme.success, size: 22)
                            else if (_answered && i == _selectedIndex && _options[i] != current.uzbek)
                              const Icon(Icons.cancel_rounded,
                                  color: AppTheme.error, size: 22),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Unit Result Screen ──────────────────────────────────────────────

class _UnitResultScreen extends StatelessWidget {
  final String unitTitle;
  final int score;
  final int total;
  final int xpGained;

  const _UnitResultScreen({
    required this.unitTitle,
    required this.score,
    required this.total,
    required this.xpGained,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final percent = total > 0 ? (score / total * 100).round() : 0;
    final emoji = percent >= 80
        ? '🏆'
        : percent >= 50
            ? '👍'
            : '💪';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Results')),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.amber.withValues(alpha: 0.3),
                        AppTheme.amber.withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: AppTheme.amber.withValues(alpha: 0.3),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.amber.withValues(alpha: 0.2),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 48)),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '$score / $total correct',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$percent% accuracy',
                  style: TextStyle(
                    fontSize: 18,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.amber.withValues(alpha: isDark ? 0.2 : 0.15),
                        AppTheme.amber.withValues(alpha: isDark ? 0.08 : 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '+$xpGained XP',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.amber,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  unitTitle,
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
                const Spacer(),
                
                // Back to Game (Pops to game selection)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: AppTheme.borderRadiusMd,
                      boxShadow: AppTheme.shadowGlow(AppTheme.violet),
                    ),
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Back to Game',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.borderRadiusMd,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // More Units (Pops back twice to UnitListScreen)
                OutlinedButton.icon(
                  onPressed: () {
                    // Pop this result screen, and the game selection screen
                    Navigator.of(context)..pop()..pop();
                  },
                  icon: const Icon(Icons.list_rounded),
                  label: const Text('More Units',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    side: BorderSide(
                      color: isDark 
                          ? Colors.white.withValues(alpha: 0.2) 
                          : Colors.black.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Back to Home (Clears library stack and goes to home)
                TextButton.icon(
                  onPressed: () {
                    // Clear the library navigator stack before switching to Home branch
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    context.go('/home');
                  },
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Back to Home',
                      style: TextStyle(fontSize: 16)),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    foregroundColor: isDark 
                        ? AppTheme.textSecondaryDark 
                        : AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

