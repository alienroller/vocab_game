import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import '../../providers/profile_provider.dart';
import '../../theme/app_theme.dart';
import '../models/speaking_models.dart';
import '../services/context_builder.dart';
import '../services/evaluation_engine.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../widgets/feedback_card.dart';
import '../widgets/live_transcript.dart';
import '../widgets/mic_button.dart';
import '../widgets/step_widgets.dart';

/// Main speaking lesson screen — the orchestrator.
///
/// Manages the full lesson flow: step rendering, mic recording,
/// Gemini evaluation, feedback display, and progression.
class SpeakingLessonScreen extends ConsumerStatefulWidget {
  final SpeakingLesson lesson;

  const SpeakingLessonScreen({super.key, required this.lesson});

  @override
  ConsumerState<SpeakingLessonScreen> createState() => _SpeakingLessonScreenState();
}

class _SpeakingLessonScreenState extends ConsumerState<SpeakingLessonScreen> {
  final _speechService = SpeechService();
  final _ttsService = TtsService();

  late final UserProgress _progress;
  late GeminiSessionContext _ctx;

  MicState _micState = MicState.idle;
  String _interimTranscript = '';
  String _finalTranscript = '';
  double _soundLevel = 0.0;
  bool _hasPlayedAudio = false;
  bool _useTextInput = kIsWeb; // Web often has STT issues, default to text

  List<ConversationTurn> _chatHistory = [];

  EvaluationResult? _currentResult;
  StepOutcome? _currentOutcome;
  int _attemptCount = 0;
  String? _currentHint;
  bool _lessonComplete = false;
  LessonSummary? _summary;

  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _recordingTimer;

  // ─── Getters ──────────────────────────────────────────────────────

  LessonStep get _currentStep =>
      widget.lesson.steps[_progress.currentStepIndex];

  double get _progressFraction =>
      (_progress.currentStepIndex + 1) / widget.lesson.steps.length;

  // ─── Lifecycle ────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _progress = UserProgress();
    _ctx = ContextBuilder.build(
      lesson: widget.lesson,
      progress: _progress,
      currentStep: _currentStep,
    );
    _initServices();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _speechService.stopListening();
    _ttsService.stop();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initServices() async {
    final available = await _speechService.init();
    await _ttsService.init();
    if (!available && mounted) {
      setState(() => _useTextInput = true);
    }
    setState(() => _micState = MicState.ready);
  }

  // ─── TTS ──────────────────────────────────────────────────────────

  Future<void> _playTargetPhrase() async {
    final phrase =
        _currentStep.targetPhrase ?? _currentStep.promptQuestion ?? '';
    if (phrase.isEmpty) return;

    await _ttsService.speak(
      text: phrase,
      languageCode: widget.lesson.languageCode,
      level: widget.lesson.cefrLevel,
    );
    if (mounted) setState(() => _hasPlayedAudio = true);
  }

  // ─── Recording ────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (_micState == MicState.recording) {
      await _stopRecording();
      return;
    }

    if (!kIsWeb) {
      final status = await Permission.microphone.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone access denied. Switching to text input.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          setState(() => _useTextInput = true);
        }
        return;
      }
    }

    setState(() {
      _micState = MicState.recording;
      _interimTranscript = '';
      _finalTranscript = '';
      _currentResult = null;
      _currentOutcome = null;
    });

    _recordingTimer?.cancel();
    // Safety timeout since web STT can hang without firing events
    _recordingTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _micState == MicState.recording) {
        _stopRecording();
      }
    });

    await _speechService.startListening(
      languageCode: widget.lesson.languageCode,
      onResult: _onSpeechResult,
      onSoundLevel: (level) {
        if (mounted) setState(() => _soundLevel = level);
      },
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    
    // Reset timer on activity
    if (_micState == MicState.recording) {
      _recordingTimer?.cancel();
      _recordingTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && _micState == MicState.recording) {
          _stopRecording();
        }
      });
    }

    setState(() {
      if (result.finalResult) {
        _finalTranscript = result.recognizedWords;
        _stopRecording();
      } else {
        _interimTranscript = result.recognizedWords;
      }
    });
  }

  Future<void> _stopRecording() async {
    if (_micState == MicState.processing) return;
    
    _recordingTimer?.cancel();
    
    // Do not await stopListening here! The Web Speech API blocks 
    // for several seconds to finalize audio, causing the UI to hang.
    // Instead, fire and forget to instantly evaluate what we have.
    _speechService.stopListening().catchError((_) {});
    
    if (!mounted) return;

    final transcript =
        _finalTranscript.isNotEmpty ? _finalTranscript : _interimTranscript;

    setState(() {
      _finalTranscript = transcript;
      _micState = MicState.processing;
    });

    await _evaluate(transcript);
  }

  // ─── Text Input Fallback ──────────────────────────────────────────

  Future<void> _submitTextInput() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _finalTranscript = text;
      _micState = MicState.processing;
      _currentResult = null;
      _currentOutcome = null;
    });
    _textController.clear();

    await _evaluate(text);
  }

  // ─── Evaluation ───────────────────────────────────────────────────

  Future<void> _evaluate(String transcript) async {
    final normalized = SpeechService.normalize(transcript);
    _attemptCount++;

    // Update context with current attempt number
    _ctx.attemptNumber = _attemptCount;

    final result = await EvaluationEngine.evaluateStep(
      step: _currentStep,
      transcript: normalized,
      ctx: _ctx,
      history: _chatHistory,
    );

    if (!mounted) return;

    final outcome = EvaluationEngine.resolveNextAction(
      result: result,
      step: _currentStep,
      attemptNumber: _attemptCount,
    );

    if (outcome.action == StepAction.continueConversation) {
      setState(() {
        _chatHistory = [
          ..._chatHistory,
          ConversationTurn(role: ConversationRole.user, text: transcript),
        ];

        if (result.chatReply != null) {
          _chatHistory = [
            ..._chatHistory,
            ConversationTurn(role: ConversationRole.model, text: result.chatReply!),
          ];
        }

        _micState = MicState.ready;
        _interimTranscript = '';
        _finalTranscript = '';
        _textController.clear();
      });

      // Automatically play AI's response
      if (result.chatReply != null) {
        await _ttsService.speak(
          text: result.chatReply!,
          languageCode: widget.lesson.languageCode,
          level: widget.lesson.cefrLevel,
        );
      }
      return; // Early return, don't show feedback block
    }

    // Process evaluation for completed conversations or standard steps
    if (result.isConversationComplete == true && result.chatReply != null) {
      // Append final turn on completion
      setState(() {
        _chatHistory = [
          ..._chatHistory,
          ConversationTurn(role: ConversationRole.user, text: transcript),
          ConversationTurn(role: ConversationRole.model, text: result.chatReply!),
        ];
      });
      // Optionally speak it out
      _ttsService.speak(
        text: result.chatReply!,
        languageCode: widget.lesson.languageCode,
        level: widget.lesson.cefrLevel,
      );
    }

    setState(() {
      _currentResult = result;
      _currentOutcome = outcome;
      _micState =
          result.passed ? MicState.success : MicState.error;

      // Update hint if outcome provides one
      if (outcome.hint != null) {
        _currentHint = outcome.hint;
      }
    });

    // Scroll to show feedback
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // If silent retry, reset after a brief pause
    if (outcome.action == StepAction.silentRetry) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _micState = MicState.ready;
            _currentResult = null;
            _currentOutcome = null;
          });
        }
      });
    }
  }

  // ─── Progression ──────────────────────────────────────────────────

  void _advanceToNextStep() {
    // Record step result
    final stepResult = StepResult(
      stepId: _currentStep.id,
      attempts: [
        SpeechAttempt(
          transcript: _finalTranscript,
          score: _currentResult?.score ?? 0,
          feedback: _currentResult?.feedback ?? '',
          specificIssue: _currentResult?.specificIssue,
          timestamp: DateTime.now(),
        ),
      ],
      passed: _currentResult?.passed ?? false,
      xpEarned: _currentOutcome?.xpEarned ?? 0,
    );

    _progress.stepResults.add(stepResult);
    _progress.totalXpEarned += _currentOutcome?.xpEarned ?? 0;

    // Update context
    ContextBuilder.updateAfterStep(_ctx, stepResult);

    // Check if lesson is complete
    if (_progress.currentStepIndex >= widget.lesson.steps.length - 1) {
      _completelesson();
      return;
    }

    // Advance
    setState(() {
      _progress.currentStepIndex++;
      _micState = MicState.ready;
      _interimTranscript = '';
      _finalTranscript = '';
      _currentResult = null;
      _currentOutcome = null;
      _attemptCount = 0;
      _currentHint = null;
      _hasPlayedAudio = false;
      _chatHistory = []; // Reset history for next step

      // Rebuild context for new step
      _ctx = ContextBuilder.build(
        lesson: widget.lesson,
        progress: _progress,
        currentStep: _currentStep,
      );
    });
  }

  Future<void> _completelesson() async {
    setState(() => _lessonComplete = true);

    // Save strictly earned XP to the unified UserProfile Gamification Engine
    if (_progress.totalXpEarned > 0) {
      final totalCorrect = _progress.stepResults.where((r) => r.passed).length;
      ref.read(profileProvider.notifier).recordGameSession(
        xpGained: _progress.totalXpEarned,
        totalQuestions: widget.lesson.steps.length,
        correctAnswers: totalCorrect,
      );
    }

    // Generate summary
    final summary = await EvaluationEngine.generateSummary(
      lesson: widget.lesson,
      progress: _progress,
      ctx: _ctx,
    );

    if (summary.badgeEarned != null && summary.badgeEarned!.isNotEmpty) {
      await ref.read(profileProvider.notifier).awardBadge(summary.badgeEarned!);
    }

    if (mounted) {
      setState(() => _summary = summary);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    if (_lessonComplete) {
      return _buildCompletionScreen(isDark, theme);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final shouldPop = await _showExitDialog();
        if (shouldPop == true && mounted) {
          nav.pop();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(widget.lesson.title),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: AppTheme.xpGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_progress.totalXpEarned} XP',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
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
          child: SafeArea(
            child: Column(
              children: [
                // Progress bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
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
                          widthFactor: _progressFraction,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: AppTheme.primaryGradient,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Step ${_progress.currentStepIndex + 1} of ${widget.lesson.steps.length}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondaryLight,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                _currentStep.type.emoji,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _currentStep.type.displayName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.violet,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Step-specific content
                        _buildStepContent(),

                        const SizedBox(height: 32),

                        // Live transcript
                        if (_micState == MicState.recording ||
                            _finalTranscript.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: LiveTranscript(
                              text: _micState == MicState.recording
                                  ? _interimTranscript
                                  : _finalTranscript,
                              isListening: _micState == MicState.recording,
                              isFinal: _finalTranscript.isNotEmpty &&
                                  _micState != MicState.recording,
                            ),
                          ),

                        // Mic button
                        if (!_useTextInput) ...[
                          MicButton(
                            state: _micState,
                            onTap: _onMicTap,
                            soundLevel: _soundLevel,
                          ),
                        ],

                        // Text input fallback
                        if (_useTextInput) ...[
                          _buildTextInput(isDark),
                        ],

                        // Toggle input mode
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _useTextInput = !_useTextInput);
                          },
                          icon: Icon(
                            _useTextInput
                                ? Icons.mic_rounded
                                : Icons.keyboard_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _useTextInput
                                ? 'Use microphone'
                                : 'Type instead',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),

                        // Current hint
                        if (_currentHint != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.amber.withValues(alpha: 0.1),
                              borderRadius: AppTheme.borderRadiusSm,
                              border: Border.all(
                                color: AppTheme.amber.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Text('💡',
                                    style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _currentHint!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.amber,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Feedback card
                        if (_currentResult != null)
                          FeedbackCard(
                            result: _currentResult!,
                            outcome: _currentOutcome,
                            onContinue: _advanceToNextStep,
                          ),

                        const SizedBox(height: 40),
                      ],
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

  // ─── Step Content Builder ─────────────────────────────────────────

  Widget _buildStepContent() {
    switch (_currentStep.type) {
      case StepType.listenAndRepeat:
        return ListenAndRepeatStep(
          step: _currentStep,
          hasPlayed: _hasPlayedAudio,
          onPlayAudio: _playTargetPhrase,
        );
      case StepType.readAndSpeak:
        return ReadAndSpeakStep(step: _currentStep);
      case StepType.promptResponse:
        return PromptResponseStep(
          step: _currentStep,
          hasPlayedQuestion: _hasPlayedAudio,
          onPlayQuestion: _playTargetPhrase,
        );
      case StepType.fillTheGap:
        return FillTheGapStep(step: _currentStep);
      case StepType.freeConversation:
        return FreeConversationStep(
          step: _currentStep,
          history: _chatHistory,
        );
    }
  }

  // ─── Mic Tap Handler ──────────────────────────────────────────────

  void _onMicTap() {
    switch (_micState) {
      case MicState.idle:
      case MicState.ready:
      case MicState.error:
        _startRecording();
        break;
      case MicState.recording:
        _stopRecording();
        break;
      case MicState.success:
        // Already showing feedback — ignore
        break;
      case MicState.processing:
      case MicState.countdown:
        // Busy — ignore
        break;
    }
  }

  // ─── Text Input Widget ────────────────────────────────────────────

  Widget _buildTextInput(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _textController,
            decoration: InputDecoration(
              hintText: 'Type your answer...',
              border: OutlineInputBorder(
                borderRadius: AppTheme.borderRadiusMd,
              ),
            ),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submitTextInput(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _submitTextInput,
          icon: const Icon(Icons.send_rounded),
        ),
      ],
    );
  }

  // ─── Completion Screen ────────────────────────────────────────────

  Widget _buildCompletionScreen(bool isDark, ThemeData theme) {
    final avgScore = _progress.stepResults.isEmpty
        ? 0.0
        : _progress.stepResults.fold<double>(
                0.0,
                (sum, r) =>
                    sum +
                    (r.attempts.isNotEmpty ? r.attempts.last.score : 0.0)) /
            _progress.stepResults.length;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Trophy
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    boxShadow: AppTheme.shadowGlow(AppTheme.violet),
                  ),
                  child: const Text('🏆', style: TextStyle(fontSize: 56)),
                ),
                const SizedBox(height: 24),
                Text(
                  'Lesson Complete!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.lesson.title,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 32),

                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatCard(
                      label: 'Score',
                      value: '${(avgScore * 100).round()}%',
                      icon: '📊',
                      isDark: isDark,
                    ),
                    _StatCard(
                      label: 'XP Earned',
                      value: '+${_progress.totalXpEarned}',
                      icon: '⭐',
                      isDark: isDark,
                    ),
                    _StatCard(
                      label: 'Steps',
                      value: '${_progress.stepResults.length}',
                      icon: '✅',
                      isDark: isDark,
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // AI Summary
                if (_summary != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.glassCard(isDark: isDark),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _summary!.headline,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SummaryRow(
                          emoji: '💪',
                          label: 'Strength',
                          text: _summary!.strength,
                        ),
                        const SizedBox(height: 10),
                        _SummaryRow(
                          emoji: '🎯',
                          label: 'Focus Next',
                          text: _summary!.focusNext,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _summary!.encouragement,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  if (_summary!.badgeEarned != null && _summary!.badgeEarned!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: AppTheme.borderRadiusLg,
                        boxShadow: AppTheme.shadowGlow(AppTheme.violet),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white24,
                            ),
                            child: const Text('🏅', style: TextStyle(fontSize: 24)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'New Badge Unlocked!',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _summary!.badgeEarned!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(),
                  ),
                  Text(
                    'Generating your personalized summary...',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight,
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Action buttons
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Done'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
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

  // ─── Exit Dialog ──────────────────────────────────────────────────

  Future<bool?> _showExitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quit Lesson?'),
        content: const Text(
            'Are you sure you want to quit? Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
  }
}

// ─── Helper Widgets ─────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String icon;
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: AppTheme.glassCard(isDark: isDark),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.violet,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String emoji;
  final String label;
  final String text;

  const _SummaryRow({
    required this.emoji,
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
