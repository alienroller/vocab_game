import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/vocab.dart';
import '../providers/vocab_provider.dart';
import '../services/word_session_service.dart';
import '../services/word_stats_service.dart';
import '../services/xp_service.dart';
import '../services/assignment_service.dart';
import '../providers/profile_provider.dart';
import '../providers/assignment_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/xp_float_widget.dart';
import 'game_streak_mixin.dart';

class MemoryCard {
  final String id;
  final String text;
  final bool isEnglish;
  final String pairId;
  bool isFaceUp = false;
  bool isMatched = false;

  MemoryCard({
    required this.id,
    required this.text,
    required this.isEnglish,
    required this.pairId,
  });
}

class MemoryGame extends ConsumerStatefulWidget {
  final List<Vocab>? customWords;
  final String? assignmentId;

  const MemoryGame({super.key, this.customWords, this.assignmentId});

  @override
  ConsumerState<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends ConsumerState<MemoryGame>
    with GameStreakMixin {
  late List<MemoryCard> _cards;
  int _moves = 0;
  int _totalXp = 0;
  int _lastXpGain = 0;
  bool _showXpFloat = false;
  int _combo = 0;
  List<int> _flippedIndices = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initGame();
    checkAndShowStreak();
  }

  void _initGame() {
    final List<Vocab> allVocab = widget.customWords ?? ref.read(vocabProvider);
    var selectedVocab = List<Vocab>.from(allVocab)..shuffle(Random());
    if (widget.customWords == null && selectedVocab.length > 6) {
      selectedVocab = selectedVocab.sublist(0, 6); // Max 12 cards (3x4 grid)
    }

    _cards = [];
    final random = Random();
    for (var vocab in selectedVocab) {
      final String pairId = vocab.id;
      _cards.add(MemoryCard(
        id: '${pairId}_en',
        text: vocab.english,
        isEnglish: true,
        pairId: pairId,
      ));
      _cards.add(MemoryCard(
        id: '${pairId}_uz',
        text: vocab.uzbek,
        isEnglish: false,
        pairId: pairId,
      ));
    }

    _cards.shuffle(random);
    _moves = 0;
    _totalXp = 0;
    _combo = 0;
    _flippedIndices = [];
    _isProcessing = false;
  }

  void _onCardTap(int index) {
    if (_isProcessing ||
        _cards[index].isFaceUp ||
        _cards[index].isMatched) {
      return;
    }

    setState(() {
      _cards[index].isFaceUp = true;
      _flippedIndices.add(index);
    });

    if (_flippedIndices.length == 2) {
      _moves++;
      _isProcessing = true;

      final idx1 = _flippedIndices[0];
      final idx2 = _flippedIndices[1];
      final isMatch = _cards[idx1].pairId == _cards[idx2].pairId;

      // Record for spaced repetition mastery (only record on the first attempt per pair to avoid spamming if they click multiple times, but memory game handles attempts per pair naturally)
      WordSessionService.recordAnswer(
        wordId: _cards[idx1].pairId,
        isCorrect: isMatch,
      );

      // Extract english/uzbek from the grid for the target word (idx1)
      final card1 = _cards[idx1];
      final card1Pair = _cards.firstWhere((c) => c.pairId == card1.pairId && c.id != card1.id);
      
      final profileBox = Hive.box('userProfile');
      final studentId = profileBox.get('id') as String?;
      final classCode = profileBox.get('classCode') as String?;
      if (studentId != null) {
        WordStatsService.recordWordAnswer(
          studentId: studentId,
          classCode: classCode,
          wordEnglish: card1.isEnglish ? card1.text : card1Pair.text,
          wordUzbek: !card1.isEnglish ? card1.text : card1Pair.text,
          wasCorrect: isMatch,
        );
      }

      if (isMatch) {
        // Match!
        _combo++;
        setState(() {
          _cards[idx1].isMatched = true;
          _cards[idx2].isMatched = true;
          _flippedIndices.clear();
          _isProcessing = false;
        });

        // Award XP per pair match (combo bonus via speed)
        final streakDays =
            Hive.box('userProfile').get('streakDays', defaultValue: 0) as int;
        final xp = XpService.calculateXp(
          correct: true,
          secondsLeft: 15 + min(_combo, 5), // combo gives speed bonus
          maxSeconds: 20,
          streakDays: streakDays,
        );
        _totalXp += xp;
        _lastXpGain = xp;
        _showXpFloat = true;

        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _showXpFloat = false);
        });

        // Check win
        if (_cards.every((card) => card.isMatched)) {
          Future.delayed(const Duration(milliseconds: 500), () async {
            if (!mounted) return;

            final score = _cards.length ~/ 2;
            await ref.read(profileProvider.notifier).recordGameSession(
              xpGained: _totalXp,
              totalQuestions: _moves,
              correctAnswers: score,
            );

            if (widget.assignmentId != null) {
              final profileBox = Hive.box('userProfile');
              final studentId = profileBox.get('id') as String?;
              final classCode = profileBox.get('classCode') as String?;
              if (studentId != null && classCode != null) {
                try {
                  await AssignmentService.updateAssignmentProgress(
                    assignmentId: widget.assignmentId!,
                    studentId: studentId,
                    classCode: classCode,
                    wordsMasteredDelta: score,
                    totalWords: score,
                  );
                  ref.read(assignmentProvider.notifier).loadStudentAssignments(
                    classCode: classCode,
                    studentId: studentId,
                  );
                } catch (_) {}
              }
            }

            if (mounted) {
              context.pushReplacement('/result', extra: {
                'score': score,
                'total': _moves,
                'gameName': 'Memory',
                'gameRoute': '/games/memory',
                'xpGained': _totalXp,
                'customWords': widget.customWords,
                'assignmentId': widget.assignmentId,
              });
            }
          });
        }
      } else {
        // No match, reset combo
        _combo = 0;
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (!mounted) return;
          setState(() {
            _cards[idx1].isFaceUp = false;
            _cards[idx2].isFaceUp = false;
            _flippedIndices.clear();
            _isProcessing = false;
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final columns = _cards.length > 8 ? 3 : 2;
    final matchedCount = _cards.where((c) => c.isMatched).length ~/ 2;
    final totalPairs = _cards.length ~/ 2;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await showExitConfirmation(context);
        if (shouldPop == true && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Memory'),
        actions: [
          // Combo indicator
          if (_combo > 1)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: AppTheme.fireGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '🔥 x$_combo',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.violet.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Moves: $_moves',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.violet),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient:
              isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // Progress indicator
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Column(
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor:
                                totalPairs > 0 ? matchedCount / totalPairs : 0,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                gradient: AppTheme.successGradient,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$matchedCount / $totalPairs pairs found',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isDark
                                ? AppTheme.textSecondaryDark
                                : AppTheme.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Card grid
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: GridView.builder(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _cards.length,
                        itemBuilder: (context, index) {
                          final card = _cards[index];
                          return _MemoryCardWidget(
                            card: card,
                            isDark: isDark,
                            onTap: () => _onCardTap(index),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // XP float animation overlay
            if (_showXpFloat)
              Positioned(
                top: MediaQuery.of(context).size.height * 0.35,
                left: 0,
                right: 0,
                child: Center(
                  child: XpFloatWidget(
                    key: ValueKey('xp_mem_$_moves$_lastXpGain'),
                    xp: _lastXpGain,
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

// ─── Memory Card Widget ───────────────────────────────────────────────

class _MemoryCardWidget extends StatefulWidget {
  final MemoryCard card;
  final bool isDark;
  final VoidCallback onTap;

  const _MemoryCardWidget({
    required this.card,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_MemoryCardWidget> createState() => _MemoryCardWidgetState();
}

class _MemoryCardWidgetState extends State<_MemoryCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;
  bool _showFront = false;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnim = CurvedAnimation(
      parent: _flipCtrl,
      curve: Curves.easeInOutCubic,
    );
    _showFront = widget.card.isFaceUp || widget.card.isMatched;
    if (_showFront) _flipCtrl.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _MemoryCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldShowFront = widget.card.isFaceUp || widget.card.isMatched;
    if (shouldShowFront != _showFront) {
      _showFront = shouldShowFront;
      if (_showFront) {
        _flipCtrl.forward();
      } else {
        _flipCtrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _flipAnim,
        builder: (context, child) {
          final angle = (1 - _flipAnim.value) * pi;
          final showBack = angle > pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateY(angle),
            child: showBack ? _buildBack() : _buildFront(),
          );
        },
      ),
    );
  }

  Widget _buildBack() {
    // Gradient card back
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7C4DFF),
            Color(0xFF5C2FE0),
            Color(0xFF3D1F9E),
          ],
        ),
        borderRadius: AppTheme.borderRadiusMd,
        boxShadow: [
          BoxShadow(
            color: AppTheme.violet.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.question_mark_rounded,
            size: 36,
            color: Colors.white.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 4),
          Text(
            'TAP',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFront() {
    final card = widget.card;
    final isMatched = card.isMatched;

    // Language-based colors
    final accentColor = card.isEnglish
        ? const Color(0xFF4FC3F7) // Blue for English
        : const Color(0xFFFFB74D); // Orange for Uzbek
    final flag = card.isEnglish ? '🇬🇧' : '🇺🇿';

    return Container(
      decoration: BoxDecoration(
        gradient: widget.isDark
            ? AppTheme.darkGlassGradient
            : AppTheme.lightGlassGradient,
        borderRadius: AppTheme.borderRadiusMd,
        border: Border.all(
          color: isMatched
              ? AppTheme.success.withValues(alpha: 0.4)
              : accentColor.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: isMatched
            ? [
                BoxShadow(
                  color: AppTheme.success.withValues(alpha: 0.2),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : AppTheme.shadowSoft,
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(flag, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              card.text,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isMatched
                    ? AppTheme.success
                    : (widget.isDark
                        ? Colors.white
                        : const Color(0xFF1A1D3A)),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          ),
          if (isMatched) ...[
            const SizedBox(height: 4),
            Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: AppTheme.success.withValues(alpha: 0.7),
            ),
          ],
        ],
      ),
    );
  }
}
