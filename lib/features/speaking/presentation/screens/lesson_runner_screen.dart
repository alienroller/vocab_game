import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../theme/app_theme.dart';
import '../../application/lesson_runner_controller.dart';
import '../../application/providers.dart';
import '../../domain/models/speaking_exercise.dart';
import '../../domain/models/speaking_scenario.dart';
import '../exercises/listen_repeat_widget.dart';
import '../exercises/listen_widget.dart';
import '../exercises/recall_widget.dart';
import '../exercises/word_breakdown_widget.dart';
import 'scenario_complete_screen.dart';

/// Runs a scenario's exercises in order.
///
/// A single `ChangeNotifier` drives state; the shell just re-renders
/// the right exercise widget based on `controller.current` and swaps
/// them in with an [AnimatedSwitcher].
class LessonRunnerScreen extends ConsumerStatefulWidget {
  final String scenarioId;
  const LessonRunnerScreen({super.key, required this.scenarioId});

  @override
  ConsumerState<LessonRunnerScreen> createState() => _LessonRunnerScreenState();
}

class _LessonRunnerScreenState extends ConsumerState<LessonRunnerScreen> {
  LessonRunnerController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scenario = ref.watch(falouScenarioByIdProvider(widget.scenarioId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (scenario == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Scenario missing')),
      );
    }

    _controller ??= LessonRunnerController(scenario: scenario);

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, _) {
        final runner = _controller!;
        final state = runner.state;

        if (state.completed) {
          // Post-frame so we don't navigate during build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final stats = runner.buildStats();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => ScenarioCompleteScreen(
                  scenario: scenario,
                  stats: stats,
                ),
              ),
            );
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final exercise = runner.current;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: _TopBar(
            progress: (state.index + 1) / state.total,
            onClose: () => _confirmExit(context),
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppTheme.darkBgGradient
                  : AppTheme.lightBgGradient,
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(exercise.id),
                    child: _buildExercise(exercise, scenario, runner),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExercise(
    SpeakingExercise exercise,
    SpeakingScenario scenario,
    LessonRunnerController runner,
  ) {
    return switch (exercise) {
      ListenExercise() => ListenExerciseWidget(
          exercise: exercise,
          cefr: scenario.cefr,
          onDone: () {
            runner.markListenComplete();
            runner.advance();
          },
        ),
      ListenRepeatExercise() => ListenRepeatWidget(
          exercise: exercise,
          cefr: scenario.cefr,
          runner: runner,
          onPass: runner.advance,
        ),
      WordBreakdownExercise() => WordBreakdownWidget(
          exercise: exercise,
          cefr: scenario.cefr,
          runner: runner,
          onPass: runner.advance,
        ),
      RecallExercise() => RecallWidget(
          exercise: exercise,
          cefr: scenario.cefr,
          runner: runner,
          onDone: runner.advance,
        ),
    };
  }

  Future<void> _confirmExit(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave lesson?'),
        content: const Text('Your progress in this scenario will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && context.mounted) {
      context.pop();
    }
  }
}

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  final double progress;
  final VoidCallback onClose;
  const _TopBar({required this.progress, required this.onClose});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 16, 0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: onClose,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  minHeight: 8,
                  backgroundColor:
                      AppTheme.violet.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation(AppTheme.violet),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
