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

class FillBlankGame extends ConsumerStatefulWidget {
  final List<Vocab>? customWords;
  final String? assignmentId;

  const FillBlankGame({super.key, this.customWords, this.assignmentId});

  @override
  ConsumerState<FillBlankGame> createState() => _FillBlankGameState();
}

class _FillBlankGameState extends ConsumerState<FillBlankGame>
    with GameStreakMixin {
  late List<Vocab> _gameVocab;
  int _currentIndex = 0;
  int _score = 0;

  late String _targetWord;
  late List<String> _displayChars;
  late List<bool> _isBlanked;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _answered = false;
  bool _isCorrect = false;
  int _totalXp = 0;
  int _lastXpGain = 0;
  bool _showXpFloat = false;
  late DateTime _questionStartTime;

  @override
  void initState() {
    super.initState();
    final List<Vocab> allVocab = widget.customWords ?? ref.read(vocabProvider);
    _gameVocab = List<Vocab>.from(allVocab)..shuffle(Random());
    if (widget.customWords == null && _gameVocab.length > 10) {
      _gameVocab = _gameVocab.sublist(0, 10);
    }
    _setupQuestion();
    checkAndShowStreak();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setupQuestion() {
    final currentVocab = _gameVocab[_currentIndex];
    _targetWord = currentVocab.uzbek.toLowerCase();

    _displayChars = _targetWord.split('');
    _isBlanked = List.generate(_displayChars.length, (index) => false);

    // Blank out ~50% of characters (but at least 1, and don't blank spaces)
    final random = Random();
    int lettersToBlank = max(1, (_displayChars.length / 2).ceil());
    int blanked = 0;

    // Don't blank out spaces or standard punctuation, but DO blank Uzbek letters and apostrophes
    final validIndices = <int>[];
    final letterRegex = RegExp(r"[\p{L}'’‘ʻ]", unicode: true);
    for (int i = 0; i < _displayChars.length; i++) {
      if (letterRegex.hasMatch(_displayChars[i])) {
        validIndices.add(i);
      }
    }

    validIndices.shuffle(random);

    for (int i = 0; i < validIndices.length && blanked < lettersToBlank; i++) {
      _isBlanked[validIndices[i]] = true;
      blanked++;
    }

    _controller.clear();
    _answered = false;
    _isCorrect = false;
    _questionStartTime = DateTime.now();

    // Auto-focus after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _checkAnswer() {
    if (_answered || _controller.text.trim().isEmpty) return;

    final guess = _controller.text.trim().toLowerCase();

    setState(() {
      _answered = true;
      _isCorrect = guess == _targetWord;

      // Record for spaced repetition mastery
      WordSessionService.recordAnswer(
        wordId: _gameVocab[_currentIndex].id,
        isCorrect: _isCorrect,
      );

      // Record for teacher analytics
      final profileBox = Hive.box('userProfile');
      final studentId = profileBox.get('id') as String?;
      final classCode = profileBox.get('classCode') as String?;
      if (studentId != null) {
        WordStatsService.recordWordAnswer(
          studentId: studentId,
          classCode: classCode,
          wordEnglish: _gameVocab[_currentIndex].english,
          wordUzbek: _gameVocab[_currentIndex].uzbek,
          wasCorrect: _isCorrect,
        );
      }

      if (_isCorrect) {
        _score++;
        // Calculate XP with speed bonus
        final elapsed =
            DateTime.now().difference(_questionStartTime).inSeconds;
        final secondsLeft = max(0, 20 - elapsed);
        final streakDays =
            Hive.box('userProfile').get('streakDays', defaultValue: 0) as int;
        final xp = XpService.calculateXp(
          correct: true,
          secondsLeft: secondsLeft,
          maxSeconds: 20,
          streakDays: streakDays,
        );
        _totalXp += xp;
        _lastXpGain = xp;
        _showXpFloat = true;
      }
    });

    _focusNode.unfocus();

    if (_isCorrect) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _showXpFloat = false);
      });
    }

    Future.delayed(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;

      if (_currentIndex < _gameVocab.length - 1) {
        setState(() {
          _currentIndex++;
          _setupQuestion();
        });
      } else {
        await ref.read(profileProvider.notifier).recordGameSession(
          xpGained: _totalXp,
          totalQuestions: _gameVocab.length,
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
                totalWords: _gameVocab.length,
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
            'total': _gameVocab.length,
            'gameName': 'Fill in the Blank',
            'gameRoute': '/games/fill-blank',
            'xpGained': _totalXp,
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_gameVocab.isEmpty) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentWord = _gameVocab[_currentIndex];

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
        title: const Text('Fill in the Blank'),
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
                  'Score: $_score',
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
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor:
                            (_currentIndex + 1) / _gameVocab.length,
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
                      'Word ${_currentIndex + 1} of ${_gameVocab.length}',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // English Prompt — Glass Card
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 32, horizontal: 24),
                      decoration: AppTheme.glassCard(isDark: isDark),
                      child: Column(
                        children: [
                          Text(
                            'Translate this word:',
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondaryLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🇬🇧',
                                  style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  currentWord.english,
                                  style:
                                      theme.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Clue Display — Glass Letter Slots
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 12,
                        children: List.generate(_displayChars.length,
                            (index) {
                          final char = _displayChars[index];
                          final isBlank = _isBlanked[index];

                          // Don't draw boxes for spaces
                          if (char == ' ') {
                            return const SizedBox(width: 12, height: 52);
                          }

                          // Determine slot color based on state
                          Color slotBg;
                          Color slotBorder;
                          Color textColor;

                          if (_answered && isBlank) {
                            if (_isCorrect) {
                              slotBg = AppTheme.success
                                  .withValues(alpha: isDark ? 0.15 : 0.1);
                              slotBorder = AppTheme.success;
                              textColor = AppTheme.success;
                            } else {
                              slotBg = AppTheme.error
                                  .withValues(alpha: isDark ? 0.15 : 0.1);
                              slotBorder = AppTheme.error;
                              textColor = AppTheme.error;
                            }
                          } else if (isBlank) {
                            slotBg = AppTheme.violet
                                .withValues(alpha: isDark ? 0.1 : 0.06);
                            slotBorder = AppTheme.violet
                                .withValues(alpha: 0.3);
                            textColor = AppTheme.violet;
                          } else {
                            slotBg = isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.black.withValues(alpha: 0.03);
                            slotBorder = isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06);
                            textColor = isDark
                                ? Colors.white
                                : const Color(0xFF1A1D3A);
                          }

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 38,
                            height: 52,
                            decoration: BoxDecoration(
                              color: slotBg,
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: slotBorder, width: 1.5),
                              boxShadow: isBlank && !_answered
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.violet
                                            .withValues(alpha: 0.1),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              isBlank
                                  ? (_answered ? char : '?')
                                  : char,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Input Field — Styled glass
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: AppTheme.borderRadiusMd,
                        boxShadow: AppTheme.shadowSoft,
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: 'Type the full Uzbek word...',
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 12, right: 8),
                            child: Text('🇺🇿',
                                style: TextStyle(fontSize: 18)),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                              minWidth: 0, minHeight: 0),
                          suffixIcon: Container(
                            margin: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.send_rounded,
                                  color: Colors.white, size: 20),
                              onPressed: _checkAnswer,
                            ),
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _checkAnswer(),
                        enabled: !_answered,
                        autocorrect: false,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Feedback
                    if (_answered)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              (_isCorrect
                                      ? AppTheme.success
                                      : AppTheme.error)
                                  .withValues(
                                      alpha: isDark ? 0.15 : 0.1),
                              (_isCorrect
                                      ? AppTheme.success
                                      : AppTheme.error)
                                  .withValues(
                                      alpha: isDark ? 0.05 : 0.03),
                            ],
                          ),
                          borderRadius: AppTheme.borderRadiusMd,
                          border: Border.all(
                            color: (_isCorrect
                                    ? AppTheme.success
                                    : AppTheme.error)
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isCorrect
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              color: _isCorrect
                                  ? AppTheme.success
                                  : AppTheme.error,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                _isCorrect
                                    ? 'Correct! 🎉'
                                    : 'The word was: $_targetWord',
                                style: TextStyle(
                                  color: _isCorrect
                                      ? AppTheme.success
                                      : AppTheme.error,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // XP float animation overlay
            if (_showXpFloat)
              Positioned(
                top: MediaQuery.of(context).size.height * 0.3,
                left: 0,
                right: 0,
                child: Center(
                  child: XpFloatWidget(
                    key: ValueKey('xp_fill_$_currentIndex$_lastXpGain'),
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
