import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/vocab.dart';
import '../providers/vocab_provider.dart';
import '../services/game_constants.dart';
import '../services/unit_best_xp_service.dart';
import '../services/word_session_service.dart';
import '../services/word_stats_service.dart';
import '../services/xp_service.dart';
import '../services/assignment_service.dart';
import '../providers/profile_provider.dart';
import '../providers/assignment_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/xp_float_widget.dart';
import 'game_streak_mixin.dart';

class QuizGame extends ConsumerStatefulWidget {
  final List<Vocab>? customWords;
  final String? assignmentId;

  /// Set when the game was launched from a library/assignment unit. Presence
  /// of [unitId] means this run is XP-eligible; the banked amount is the delta
  /// over the user's previous best on this unit.
  final String? unitId;

  const QuizGame({
    super.key,
    this.customWords,
    this.assignmentId,
    this.unitId,
  });

  @override
  ConsumerState<QuizGame> createState() => _QuizGameState();
}

class _QuizGameState extends ConsumerState<QuizGame>
    with GameStreakMixin {
  late List<Vocab> _allVocab;
  late List<Vocab> _quizVocab;
  int _currentIndex = 0;
  int _score = 0;
  int _totalXp = 0;
  int _lastXpGain = 0;
  bool _showXpFloat = false;
  List<String> _currentOptions = [];
  bool _answered = false;
  int? _selectedIndex;
  late DateTime _questionStartTime;

  /// Library/assignment plays earn XP; personal-practice plays don't.
  bool get _awardsXp => widget.unitId != null;

  @override
  void initState() {
    super.initState();
    final List<Vocab> allVocab = widget.customWords ?? ref.read(vocabProvider);
    _allVocab = allVocab;
    _quizVocab = List<Vocab>.from(_allVocab)..shuffle(Random());
    if (widget.customWords == null &&
        _quizVocab.length > GameConstants.defaultSessionSize) {
      _quizVocab = _quizVocab.sublist(0, GameConstants.defaultSessionSize);
    }

    _generateOptions();
    checkAndShowStreak();
  }

  void _generateOptions() {
    final currentWord = _quizVocab[_currentIndex];
    final random = Random();
    
    // Get wrong options
    final distractors = _allVocab
        .where((v) => v.id != currentWord.id)
        .toList()
      ..shuffle(random);
      
    final selectedDistractors = distractors
        .take(GameConstants.multipleChoiceDistractors)
        .map((v) => v.uzbek)
        .toList();

    // Fallback if the user has < 4 total words in their entire dictionary
    if (selectedDistractors.length < GameConstants.multipleChoiceDistractors) {
      final fallbacks = List<String>.from(GameConstants.fallbackDistractors)
        ..shuffle(random);
      while (selectedDistractors.length <
              GameConstants.multipleChoiceDistractors &&
          fallbacks.isNotEmpty) {
        final f = fallbacks.removeLast();
        if (f != currentWord.uzbek && !selectedDistractors.contains(f)) {
          selectedDistractors.add(f);
        }
      }
    }
    
    _currentOptions = [currentWord.uzbek, ...selectedDistractors];
    _currentOptions.shuffle(random);
    _answered = false;
    _selectedIndex = null;
    _questionStartTime = DateTime.now();
  }

  void _checkAnswer(int index) {
    if (_answered) return;
    
    final selectedUzbek = _currentOptions[index];
    final isCorrect = selectedUzbek == _quizVocab[_currentIndex].uzbek;

    // Record for spaced repetition mastery
    WordSessionService.recordAnswer(
      wordId: _quizVocab[_currentIndex].id,
      isCorrect: isCorrect,
    );

    // Record for teacher analytics
    final profileBox = Hive.box('userProfile');
    final studentId = profileBox.get('id') as String?;
    final classCode = profileBox.get('classCode') as String?;
    if (studentId != null) {
      WordStatsService.recordWordAnswer(
        studentId: studentId,
        classCode: classCode,
        wordEnglish: _quizVocab[_currentIndex].english,
        wordUzbek: _quizVocab[_currentIndex].uzbek,
        wasCorrect: isCorrect,
      );
    }

    // Calculate XP for this answer (only for XP-eligible plays)
    int xpGained = 0;
    if (_awardsXp) {
      final elapsed = DateTime.now().difference(_questionStartTime).inSeconds;
      final secondsLeft =
          max(0, GameConstants.questionTimerSeconds - elapsed);
      final streakDays =
          Hive.box('userProfile').get('streakDays', defaultValue: 0) as int;
      xpGained = XpService.calculateXp(
        correct: isCorrect,
        secondsLeft: secondsLeft,
        maxSeconds: GameConstants.questionTimerSeconds,
        streakDays: streakDays,
      );
    }

    setState(() {
      _answered = true;
      _selectedIndex = index;
      if (isCorrect) {
        _score++;
        _totalXp += xpGained;
        _lastXpGain = xpGained;
        _showXpFloat = _awardsXp;
      } else {
        _showXpFloat = false;
      }
    });

    // Hide XP float after animation
    if (isCorrect && _awardsXp) {
      Future.delayed(GameConstants.xpFloatDuration, () {
        if (mounted) setState(() => _showXpFloat = false);
      });
    }

    Future.delayed(GameConstants.answerRevealDelay, () async {
      if (!mounted) return;
      
      if (_currentIndex < _quizVocab.length - 1) {
        setState(() {
          _currentIndex++;
          _generateOptions();
        });
      } else {
        // Game Over — compute banked XP (delta over previous best for unit
        // plays; 0 for personal practice).
        int previousBest = 0;
        int bankedXp = 0;
        if (_awardsXp) {
          previousBest = UnitBestXpService.getBest(widget.unitId!);
          bankedXp = await UnitBestXpService.recordRun(
            unitId: widget.unitId!,
            runXp: _totalXp,
          );
        }

        await ref.read(profileProvider.notifier).recordGameSession(
          xpGained: bankedXp,
          totalQuestions: _quizVocab.length,
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
              );
              ref.read(assignmentProvider.notifier).loadStudentAssignments(
                classCode: classCode,
                studentId: studentId,
              );
            } catch (e, s) {
              debugPrint('Assignment progress update failed: $e\n$s');
            }
          }
        }

        if (mounted) {
          context.pushReplacement('/result', extra: {
            'score': _score,
            'total': _quizVocab.length,
            'gameName': 'Quiz',
            'gameRoute': '/games/quiz',
            'runXp': _totalXp,
            'bankedXp': bankedXp,
            'previousBest': previousBest,
            'unitId': widget.unitId,
            'customWords': widget.customWords,
            'assignmentId': widget.assignmentId,
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_quizVocab.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentWord = _quizVocab[_currentIndex];

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
        title: const Text('Quiz'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.violet.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Score: $_score',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.violet),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: Stack(
        children: [
          SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress bar
              Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (_currentIndex + 1) / _quizVocab.length,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: AppTheme.primaryGradient,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Question ${_currentIndex + 1} of ${_quizVocab.length}',
                style: TextStyle(
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // English Word Card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                decoration: AppTheme.glassCard(isDark: isDark),
                child: Column(
                  children: [
                    Text(
                      'Translate this word:',
                      style: TextStyle(
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      currentWord.english,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              // Options List
              Expanded(
                child: ListView.separated(
                  itemCount: _currentOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final option = _currentOptions[index];
                    final isCorrectOption = option == currentWord.uzbek;
                    final isSelected = _selectedIndex == index;

                    Color getBg() {
                      if (!_answered) return isDark ? const Color(0xFF1E2140).withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.8);
                      if (isCorrectOption) return AppTheme.success.withValues(alpha: isDark ? 0.15 : 0.1);
                      if (isSelected && !isCorrectOption) return AppTheme.error.withValues(alpha: isDark ? 0.15 : 0.1);
                      return isDark ? const Color(0xFF1E2140).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.6);
                    }

                    Color getBorder() {
                      if (!_answered) return isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
                      if (isCorrectOption) return AppTheme.success;
                      if (isSelected && !isCorrectOption) return AppTheme.error;
                      return isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03);
                    }

                    return InkWell(
                      onTap: () => _checkAnswer(index),
                      borderRadius: AppTheme.borderRadiusMd,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: getBg(),
                          borderRadius: AppTheme.borderRadiusMd,
                          border: Border.all(color: getBorder(), width: 2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.violet.withValues(alpha: 0.1),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                ['A', 'B', 'C', 'D'][index],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.violet,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                option,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (_answered && isCorrectOption)
                              const Icon(Icons.check_circle_rounded, color: AppTheme.success)
                            else if (_answered && isSelected && !isCorrectOption)
                              const Icon(Icons.cancel_rounded, color: AppTheme.error)
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
          // XP float animation overlay
          if (_showXpFloat)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.35,
              left: 0,
              right: 0,
              child: Center(
                child: XpFloatWidget(
                  key: ValueKey('xp_$_currentIndex$_lastXpGain'),
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
