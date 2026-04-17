import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/exam_service.dart';
import '../../theme/app_theme.dart';

/// Runs the actual exam for a student.
///
/// Flow:
/// 1. Load questions + any previously submitted answers (resume support).
/// 2. Shuffle question order using the student's `shuffle_seed`.
/// 3. Show one MC question at a time with a per-question countdown.
/// 4. On answer tap → call `submit-answer` Edge Function → show result → next.
/// 5. On last question → navigate to results.
class StudentExamScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const StudentExamScreen({super.key, required this.sessionId});

  @override
  ConsumerState<StudentExamScreen> createState() => _StudentExamScreenState();
}

class _StudentExamScreenState extends ConsumerState<StudentExamScreen>
    with WidgetsBindingObserver {
  // Session metadata
  int _perQuestionSeconds = 30;
  int _totalSeconds = 900;
  DateTime? _sessionStartedAt;

  // Questions & progress
  List<Map<String, dynamic>> _questions = [];
  final Set<String> _answeredIds = {};
  int _currentIndex = 0;
  int _correctCount = 0;
  int _totalAnswered = 0;

  // Per-question state
  Timer? _questionTimer;
  int _secondsLeft = 0;
  DateTime? _questionStartTime;
  String? _selectedAnswer;
  bool? _lastAnswerCorrect;
  String? _lastCorrectAnswer;
  bool _submitting = false;
  bool _showingResult = false;

  // Session timer
  Timer? _sessionTimer;
  int _sessionSecondsLeft = 0;

  // Loading / error
  bool _loading = true;
  String? _error;
  bool _finished = false;

  // Shuffle seed from participant row
  int _shuffleSeed = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadExamState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _questionTimer?.cancel();
    _sessionTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Student backgrounded the app — increment counter server-side.
      _reportBackgrounded();
    }
    if (state == AppLifecycleState.resumed) {
      // Re-sync timers on resume.
      _syncTimers();
    }
  }

  Future<void> _loadExamState() async {
    try {
      // Fetch session, questions, participation, and prior answers in parallel.
      final sessionFuture = ExamService.fetchSession(widget.sessionId);
      final questionsFuture = ExamService.fetchQuestions(widget.sessionId);
      final participationFuture =
          ExamService.fetchMyParticipation(widget.sessionId);
      final answersFuture = ExamService.fetchMyAnswers(widget.sessionId);

      final session = await sessionFuture;
      final questions = await questionsFuture;
      final participation = await participationFuture;
      final myAnswers = await answersFuture;

      if (session == null || participation == null) {
        setState(() {
          _loading = false;
          _error = 'Session or participation not found.';
        });
        return;
      }

      _perQuestionSeconds = session.perQuestionSeconds;
      _totalSeconds = session.totalSeconds;
      _sessionStartedAt = session.startedAt;
      _shuffleSeed = (participation['shuffle_seed'] as num?)?.toInt() ?? 0;

      // Deterministic shuffle keyed by the student's seed.
      final shuffled = _deterministicShuffle(questions, _shuffleSeed);

      // Build answered set from prior answers (resume case).
      for (final a in myAnswers) {
        _answeredIds.add(a['question_id'].toString());
        if (a['is_correct'] == true) _correctCount++;
        _totalAnswered++;
      }

      // Find the first unanswered question.
      int resumeIndex = 0;
      for (int i = 0; i < shuffled.length; i++) {
        if (!_answeredIds.contains(shuffled[i]['id'].toString())) {
          resumeIndex = i;
          break;
        }
        if (i == shuffled.length - 1) {
          // All questions answered — exam finished.
          resumeIndex = shuffled.length;
        }
      }

      if (!mounted) return;
      setState(() {
        _questions = shuffled;
        _currentIndex = resumeIndex;
        _loading = false;
        _finished = resumeIndex >= shuffled.length;
      });

      _startSessionTimer();
      if (!_finished) _startQuestionTimer();
    } catch (e, s) {
      debugPrint('Exam load failed: $e\n$s');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> _deterministicShuffle(
    List<Map<String, dynamic>> items,
    int seed,
  ) {
    final rng = Random(seed);
    final copy = List<Map<String, dynamic>>.from(items);
    for (int i = copy.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = copy[i];
      copy[i] = copy[j];
      copy[j] = tmp;
    }
    return copy;
  }

  void _startSessionTimer() {
    if (_sessionStartedAt == null) return;
    final elapsed =
        DateTime.now().toUtc().difference(_sessionStartedAt!).inSeconds;
    _sessionSecondsLeft = max(0, _totalSeconds - elapsed);
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _sessionSecondsLeft--);
      if (_sessionSecondsLeft <= 0) {
        _sessionTimer?.cancel();
        _onSessionExpired();
      }
    });
  }

  void _startQuestionTimer() {
    _secondsLeft = _perQuestionSeconds;
    _questionStartTime = DateTime.now();
    _questionTimer?.cancel();
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _questionTimer?.cancel();
        _onQuestionTimeout();
      }
    });
  }

  void _syncTimers() {
    // Session timer — recalculate from server started_at.
    if (_sessionStartedAt != null) {
      final elapsed =
          DateTime.now().toUtc().difference(_sessionStartedAt!).inSeconds;
      _sessionSecondsLeft = max(0, _totalSeconds - elapsed);
      if (_sessionSecondsLeft <= 0) {
        _onSessionExpired();
        return;
      }
    }
    // Question timer — recalculate from question start time.
    if (_questionStartTime != null && !_showingResult && !_finished) {
      final elapsed =
          DateTime.now().difference(_questionStartTime!).inSeconds;
      _secondsLeft = max(0, _perQuestionSeconds - elapsed);
      if (_secondsLeft <= 0) {
        _onQuestionTimeout();
      }
    }
  }

  void _onQuestionTimeout() {
    if (_submitting || _showingResult || _finished) return;
    _submitAnswer('__timed_out__');
  }

  void _onSessionExpired() {
    if (_finished) return;
    setState(() => _finished = true);
    _questionTimer?.cancel();
    _sessionTimer?.cancel();
    _showFinishScreen();
  }

  /// Optimistic-UI answer submit.
  ///
  /// Grades the tap against the locally-cached `correct_answer` and shows
  /// green/red INSTANTLY — no waiting on the network. The server submit
  /// runs in the background with retries and swallows benign 409s
  /// ("already answered") so a slow network never produces a red banner
  /// or leaves the student stuck on a question.
  Future<void> _submitAnswer(String answer) async {
    if (_submitting || _showingResult || _finished) return;
    final q = _questions[_currentIndex];
    final questionId = q['id'].toString();
    final correctAnswer = (q['correct_answer'] as String?)?.trim() ?? '';
    final secondsTaken = _questionStartTime != null
        ? DateTime.now().difference(_questionStartTime!).inSeconds
        : _perQuestionSeconds;

    // Grade locally. Timeouts are always wrong; otherwise compare trimmed,
    // case-insensitive (same rule the server uses).
    final isTimedOut = answer == '__timed_out__';
    final isCorrect = !isTimedOut &&
        answer.trim().toLowerCase() == correctAnswer.toLowerCase();

    // Light tap feedback so the UI feels responsive even on slow networks.
    if (!isTimedOut) {
      unawaited(HapticFeedback.lightImpact());
    }

    _questionTimer?.cancel();
    setState(() {
      _submitting = true;
      _showingResult = true;
      _selectedAnswer = answer;
      _lastAnswerCorrect = isCorrect;
      _lastCorrectAnswer = correctAnswer;
      _answeredIds.add(questionId);
      _totalAnswered++;
      if (isCorrect) _correctCount++;
    });

    // Fire-and-forget the server submit. Retries silently on flaky network.
    unawaited(_sendSubmitInBackground(
      questionId: questionId,
      answer: answer,
      secondsTaken: secondsTaken,
    ));

    // Short pause so the student sees the green/red feedback, then advance.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _submitting = false);
    _advanceToNext();
  }

  /// Server-side submit, retried silently so transient failures never hit
  /// the UI. Treats 409 "already answered" as success (the server already
  /// has this answer — a common outcome when a previous request's response
  /// was lost but the row was written).
  Future<void> _sendSubmitInBackground({
    required String questionId,
    required String answer,
    required int secondsTaken,
  }) async {
    const maxAttempts = 4;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await ExamService.submitAnswer(
          sessionId: widget.sessionId,
          questionId: questionId,
          answer: answer,
          secondsTaken: secondsTaken,
        );
        return; // success
      } catch (e) {
        final msg = e.toString().toLowerCase();
        // Server already has this answer — benign, nothing to do.
        if (msg.contains('already answered')) return;
        // Terminal states — retrying will never succeed.
        if (msg.contains('you already finished') ||
            msg.contains('session is not in progress') ||
            msg.contains('session time expired')) {
          debugPrint('submit-answer terminal: $e');
          return;
        }
        if (attempt < maxAttempts) {
          // Exponential-ish backoff: 2s, 4s, 6s.
          await Future<void>.delayed(Duration(seconds: attempt * 2));
          continue;
        }
        debugPrint(
            'submit-answer final failure after $attempt attempts: $e');
      }
    }
  }

  void _advanceToNext() {
    if (_finished) {
      _showFinishScreen();
      return;
    }
    setState(() {
      _currentIndex++;
      // Defensive: skip any already-answered questions. Protects against
      // resume edge cases where server-side answers from a prior attempt
      // landed on shuffled positions that aren't contiguous.
      while (_currentIndex < _questions.length &&
          _answeredIds
              .contains(_questions[_currentIndex]['id'].toString())) {
        _currentIndex++;
      }
      _selectedAnswer = null;
      _lastAnswerCorrect = null;
      _lastCorrectAnswer = null;
      _showingResult = false;
      if (_currentIndex >= _questions.length) {
        _finished = true;
      }
    });
    if (_finished) {
      _showFinishScreen();
    } else {
      _startQuestionTimer();
    }
  }

  void _showFinishScreen() {
    _questionTimer?.cancel();
    _sessionTimer?.cancel();
    if (!mounted) return;
    context.pushReplacement(
      '/student/exam/${widget.sessionId}/results',
      extra: <String, dynamic>{
        'correctCount': _correctCount,
        'totalCount': _totalAnswered,
        'totalQuestions': _questions.length,
      },
    );
  }

  Future<void> _reportBackgrounded() async {
    try {
      final row = await ExamService.fetchMyParticipation(widget.sessionId);
      final current = ((row?['backgrounded_count'] as num?)?.toInt() ?? 0) + 1;
      final myId = Hive.box('userProfile').get('id') as String?;
      if (myId == null) return;
      await Supabase.instance.client
          .from('exam_participants')
          .update(<String, dynamic>{
            'backgrounded_count': current,
          })
          .eq('session_id', widget.sessionId)
          .eq('student_id', myId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exam')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exam')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: $_error',
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ),
      );
    }
    if (_finished || _currentIndex >= _questions.length) {
      // Safety: if we're finished but haven't navigated yet, show a loader.
      return Scaffold(
        appBar: AppBar(title: const Text('Exam')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final q = _questions[_currentIndex];
    final options = (q['options'] as List).cast<String>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Shuffle options deterministically per question using seed + order_index.
    final optSeed = _shuffleSeed + (q['order_index'] as int);
    final shuffledOptions = _deterministicShuffleStrings(options, optSeed);

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('Question ${_currentIndex + 1} / ${_questions.length}'),
          actions: [
            // Session timer
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _sessionSecondsLeft <= 60
                        ? Colors.redAccent.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatTime(_sessionSecondsLeft),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _sessionSecondsLeft <= 60
                          ? Colors.redAccent
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              children: [
                // Top row: circular countdown + score pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _CircularTimer(
                      secondsLeft: _secondsLeft,
                      totalSeconds: _perQuestionSeconds,
                    ),
                    _ScorePill(
                      correct: _correctCount,
                      total: _totalAnswered,
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Question + options — animate between questions.
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.08, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: SingleChildScrollView(
                      key: ValueKey<int>(_currentIndex),
                      child: Column(
                        children: [
                          Text(
                            q['prompt'] as String,
                            style: const TextStyle(
                                fontSize: 30, fontWeight: FontWeight.w800),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'What is the Uzbek translation?',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 28),
                          ...shuffledOptions
                              .map((opt) => _buildOption(opt, isDark)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> _deterministicShuffleStrings(List<String> items, int seed) {
    final rng = Random(seed);
    final copy = List<String>.from(items);
    for (int i = copy.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = copy[i];
      copy[i] = copy[j];
      copy[j] = tmp;
    }
    return copy;
  }

  Widget _buildOption(String option, bool isDark) {
    final bool isSelected = _selectedAnswer == option;
    final bool isCorrectOption =
        _showingResult && option == _lastCorrectAnswer;
    final bool isWrongSelection =
        _showingResult && isSelected && !(_lastAnswerCorrect ?? false);

    Color bgColor;
    Color borderColor;
    if (_showingResult) {
      if (isCorrectOption) {
        bgColor = Colors.green.withValues(alpha: 0.15);
        borderColor = Colors.green;
      } else if (isWrongSelection) {
        bgColor = Colors.redAccent.withValues(alpha: 0.15);
        borderColor = Colors.redAccent;
      } else {
        bgColor = isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.grey.withValues(alpha: 0.06);
        borderColor = Colors.transparent;
      }
    } else if (isSelected) {
      bgColor = AppTheme.violet.withValues(alpha: 0.12);
      borderColor = AppTheme.violet;
    } else {
      bgColor = isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.white;
      borderColor = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.08);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bgColor,
        borderRadius: AppTheme.borderRadiusMd,
        child: InkWell(
          borderRadius: AppTheme.borderRadiusMd,
          onTap: (_showingResult || _submitting)
              ? null
              : () => _submitAnswer(option),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: 1.5),
              borderRadius: AppTheme.borderRadiusMd,
            ),
            child: Text(
              option,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isWrongSelection
                    ? Colors.redAccent
                    : isCorrectOption
                        ? Colors.green
                        : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// Circular countdown ring. Colour shifts green → amber → red as the per-
/// question timer drains, so students feel the pressure at a glance.
class _CircularTimer extends StatelessWidget {
  final int secondsLeft;
  final int totalSeconds;
  const _CircularTimer({
    required this.secondsLeft,
    required this.totalSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = totalSeconds > 0 ? (secondsLeft / totalSeconds) : 0.0;
    final color = fraction > 0.5
        ? Colors.green
        : fraction > 0.25
            ? Colors.amber
            : Colors.redAccent;
    return SizedBox(
      width: 68,
      height: 68,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 68,
            height: 68,
            child: CircularProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              strokeWidth: 5,
              backgroundColor: color.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$secondsLeft',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'sec',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Running score chip. Green pill with correct/answered so the student
/// sees their run at a glance.
class _ScorePill extends StatelessWidget {
  final int correct;
  final int total;
  const _ScorePill({required this.correct, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: Colors.green.shade400),
          const SizedBox(width: 6),
          Text(
            '$correct / $total',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
