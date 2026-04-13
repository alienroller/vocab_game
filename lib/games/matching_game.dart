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

class MatchingGame extends ConsumerStatefulWidget {
  final List<Vocab>? customWords;
  final String? assignmentId;

  const MatchingGame({super.key, this.customWords, this.assignmentId});

  @override
  ConsumerState<MatchingGame> createState() => _MatchingGameState();
}

class _MatchingGameState extends ConsumerState<MatchingGame>
    with GameStreakMixin, TickerProviderStateMixin {
  late List<Vocab> _gameWords;
  late List<Vocab> _leftColumn;
  late List<Vocab> _rightColumn;

  Vocab? _selectedLeft;
  Vocab? _selectedRight;

  final Set<String> _matchedIds = {};
  int _score = 0;
  int _moves = 0;
  int _totalXp = 0;
  int _lastXpGain = 0;
  bool _showXpFloat = false;
  String? _lastMatchId; // glow effect for latest match

  @override
  void initState() {
    super.initState();
    _initGame();
    checkAndShowStreak();
  }

  void _initGame() {
    final List<Vocab> allVocab = widget.customWords ?? ref.read(vocabProvider);
    _gameWords = List<Vocab>.from(allVocab)..shuffle(Random());
    // Use up to 6 pairs for a matching round
    if (_gameWords.length > 6) {
      _gameWords = _gameWords.sublist(0, 6);
    }

    _leftColumn = List<Vocab>.from(_gameWords)..shuffle(Random());
    _rightColumn = List<Vocab>.from(_gameWords)..shuffle(Random());

    _matchedIds.clear();
    _selectedLeft = null;
    _selectedRight = null;
    _score = 0;
    _moves = 0;
    _totalXp = 0;
  }

  void _handleTap(Vocab word, bool isLeft) {
    if (_matchedIds.contains(word.id)) return;

    setState(() {
      if (isLeft) {
        _selectedLeft = _selectedLeft == word ? null : word;
      } else {
        _selectedRight = _selectedRight == word ? null : word;
      }
    });

    if (_selectedLeft != null && _selectedRight != null) {
      _moves++;
      final isMatch = _selectedLeft!.id == _selectedRight!.id;

      // Record for spaced repetition mastery
      WordSessionService.recordAnswer(
        wordId: _selectedLeft!.id,
        isCorrect: isMatch,
      );

      // Record for teacher analytics
      final profileBox = Hive.box('userProfile');
      final studentId = profileBox.get('id') as String?;
      final classCode = profileBox.get('classCode') as String?;
      if (studentId != null) {
        WordStatsService.recordWordAnswer(
          studentId: studentId,
          classCode: classCode,
          wordEnglish: _selectedLeft!.english,
          wordUzbek: _selectedLeft!.uzbek,
          wasCorrect: isMatch,
        );
      }

      if (isMatch) {
        final matchedId = _selectedLeft!.id;
        _matchedIds.add(matchedId);
        _score++;
        // Award XP per correct match
        final streakDays =
            Hive.box('userProfile').get('streakDays', defaultValue: 0) as int;
        final xp = XpService.calculateXp(
          correct: true,
          secondsLeft: 15,
          maxSeconds: 20,
          streakDays: streakDays,
        );
        _totalXp += xp;
        _lastXpGain = xp;
        _showXpFloat = true;
        _lastMatchId = matchedId;
        _selectedLeft = null;
        _selectedRight = null;

        // Hide XP float after animation
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _showXpFloat = false);
        });

        // Clear glow after a bit
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _lastMatchId = null);
        });

        if (_matchedIds.length == _gameWords.length) {
          Future.delayed(const Duration(milliseconds: 500), () async {
            if (!mounted) return;

            await ref.read(profileProvider.notifier).recordGameSession(
              xpGained: _totalXp,
              totalQuestions: _moves,
              correctAnswers: _score,
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
                    wordsMasteredDelta: _score,
                    totalWords: _gameWords.length,
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
                'score': _score,
                'total': _moves,
                'gameName': 'Matching',
                'gameRoute': '/games/matching',
                'xpGained': _totalXp,
                'customWords': widget.customWords,
                'assignmentId': widget.assignmentId,
              });
            }
          });
        }
      } else {
        // Incorrect match, delay and clear
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          setState(() {
            _selectedLeft = null;
            _selectedRight = null;
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_gameWords.isEmpty) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
        title: const Text('Matching'),
        actions: [
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
                  // Column headers
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0288D1)
                                    .withValues(alpha: isDark ? 0.15 : 0.1),
                                borderRadius: AppTheme.borderRadiusSm,
                              ),
                              child: const Text(
                                '🇬🇧 English',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF4FC3F7),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE65100)
                                    .withValues(alpha: isDark ? 0.15 : 0.1),
                                borderRadius: AppTheme.borderRadiusSm,
                              ),
                              child: const Text(
                                '🇺🇿 Uzbek',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFFFFB74D),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Game columns
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          // Left Column (English)
                          Expanded(
                            child: Column(
                              children: _leftColumn.map((word) {
                                final isMatched =
                                    _matchedIds.contains(word.id);
                                final isSelected = _selectedLeft == word;
                                final justMatched =
                                    _lastMatchId == word.id;

                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 5, horizontal: 4),
                                    child: _MatchCard(
                                      text: word.english,
                                      isMatched: isMatched,
                                      isSelected: isSelected,
                                      justMatched: justMatched,
                                      isDark: isDark,
                                      gradientColors: const [
                                        Color(0xFF4FC3F7),
                                        Color(0xFF0288D1),
                                      ],
                                      onTap: isMatched
                                          ? null
                                          : () => _handleTap(word, true),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Right Column (Uzbek)
                          Expanded(
                            child: Column(
                              children: _rightColumn.map((word) {
                                final isMatched =
                                    _matchedIds.contains(word.id);
                                final isSelected = _selectedRight == word;
                                final justMatched =
                                    _lastMatchId == word.id;

                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 5, horizontal: 4),
                                    child: _MatchCard(
                                      text: word.uzbek,
                                      isMatched: isMatched,
                                      isSelected: isSelected,
                                      justMatched: justMatched,
                                      isDark: isDark,
                                      gradientColors: const [
                                        Color(0xFFFFB74D),
                                        Color(0xFFE65100),
                                      ],
                                      onTap: isMatched
                                          ? null
                                          : () => _handleTap(word, false),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Matches counter
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      '${_matchedIds.length} / ${_gameWords.length} matched',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _matchedIds.length == _gameWords.length
                            ? AppTheme.success
                            : AppTheme.violet,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // XP float animation overlay
            if (_showXpFloat)
              Positioned(
                top: MediaQuery.of(context).size.height * 0.4,
                left: 0,
                right: 0,
                child: Center(
                  child: XpFloatWidget(
                    key: ValueKey('xp_match_$_score$_lastXpGain'),
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

// ─── Glass Match Card ─────────────────────────────────────────────────

class _MatchCard extends StatefulWidget {
  final String text;
  final bool isMatched;
  final bool isSelected;
  final bool justMatched;
  final bool isDark;
  final List<Color> gradientColors;
  final VoidCallback? onTap;

  const _MatchCard({
    required this.text,
    required this.isMatched,
    required this.isSelected,
    required this.justMatched,
    required this.isDark,
    required this.gradientColors,
    this.onTap,
  });

  @override
  State<_MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<_MatchCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapCtrl;
  late Animation<double> _tapScale;

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _tapScale = Tween(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _tapCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isMatched
        ? AppTheme.success.withValues(alpha: 0.4)
        : widget.isSelected
            ? widget.gradientColors.first
            : (widget.isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06));

    final bgGradient = widget.isMatched
        ? LinearGradient(
            colors: [
              AppTheme.success.withValues(alpha: widget.isDark ? 0.12 : 0.08),
              AppTheme.success.withValues(alpha: widget.isDark ? 0.06 : 0.04),
            ],
          )
        : widget.isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.gradientColors.first
                      .withValues(alpha: widget.isDark ? 0.2 : 0.12),
                  widget.gradientColors.last
                      .withValues(alpha: widget.isDark ? 0.1 : 0.06),
                ],
              )
            : (widget.isDark
                ? AppTheme.darkGlassGradient
                : AppTheme.lightGlassGradient);

    return ScaleTransition(
      scale: _tapScale,
      child: GestureDetector(
        onTapDown: widget.onTap != null ? (_) => _tapCtrl.forward() : null,
        onTapUp: widget.onTap != null
            ? (_) {
                _tapCtrl.reverse();
                widget.onTap!();
              }
            : null,
        onTapCancel:
            widget.onTap != null ? () => _tapCtrl.reverse() : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: bgGradient,
            borderRadius: AppTheme.borderRadiusMd,
            border: Border.all(
              color: borderColor,
              width: widget.isSelected || widget.justMatched ? 2 : 1,
            ),
            boxShadow: [
              if (widget.isSelected)
                BoxShadow(
                  color: widget.gradientColors.first
                      .withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              if (widget.justMatched)
                BoxShadow(
                  color: AppTheme.success.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
            ],
          ),
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontWeight:
                  widget.isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: widget.isSelected ? 16 : 15,
              color: widget.isMatched
                  ? AppTheme.success
                  : widget.isSelected
                      ? widget.gradientColors.first
                      : (widget.isDark ? Colors.white : const Color(0xFF1A1D3A)),
              decoration: widget.isMatched
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
            ),
            textAlign: TextAlign.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isMatched)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: AppTheme.success.withValues(alpha: 0.7),
                      ),
                    ),
                  Flexible(
                    child: Text(
                      widget.text,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
