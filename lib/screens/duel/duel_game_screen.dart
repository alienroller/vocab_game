import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../providers/duel_game_provider.dart';
import '../../theme/app_theme.dart';

/// Live duel game screen — pure view over [duelGameProvider].
///
/// All state, timers, realtime subscriptions, and finish logic live in
/// [DuelGameNotifier]. This widget only renders state and forwards user
/// input back to the notifier. Navigation to the results screen is
/// triggered by a phase transition (state-driven, not event-driven), so
/// there is no path that can cause double-pushes or countdown restarts.
class DuelGameScreen extends ConsumerStatefulWidget {
  final String duelId;
  final List<Map<String, dynamic>> words;
  final bool isChallenger;

  const DuelGameScreen({
    super.key,
    required this.duelId,
    required this.words,
    required this.isChallenger,
  });

  @override
  ConsumerState<DuelGameScreen> createState() => _DuelGameScreenState();
}

class _DuelGameScreenState extends ConsumerState<DuelGameScreen> {
  late final DuelGameArgs _args;

  @override
  void initState() {
    super.initState();
    final myId = Hive.box('userProfile').get('id') as String;
    _args = DuelGameArgs(
      duelId: widget.duelId,
      words: widget.words,
      isChallenger: widget.isChallenger,
      myId: myId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.words.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No words available')),
      );
    }

    final state = ref.watch(duelGameProvider(_args));

    // Drive navigation off phase transitions — never off events. This is
    // the structural reason loops can't happen anymore: the screen reaches
    // 'finished' exactly once per state instance.
    ref.listen<DuelGameState>(duelGameProvider(_args), (prev, next) {
      if (prev?.phase != DuelPhase.finished &&
          next.phase == DuelPhase.finished) {
        context.pushReplacement('/duels/results', extra: {
          'myScore': next.myScore,
          'opponentScore': next.finalOpponentScore,
          'totalWords': widget.words.length,
          'myXpGain': next.myXpGain,
          'didWin': next.didWin,
          'isDraw': next.isDraw,
          'opponentUsername': next.opponentUsername,
        });
      } else if (prev?.phase != DuelPhase.error &&
          next.phase == DuelPhase.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'Duel error'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (state.phase == DuelPhase.finished ||
            state.phase == DuelPhase.error) {
          if (context.mounted) context.pop();
          return;
        }
        final shouldQuit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Quit Duel?'),
            content: const Text(
                'Are you sure you want to quit? You will forfeit this duel.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Quit'),
              ),
            ],
          ),
        );
        if (shouldQuit == true) {
          await ref.read(duelGameProvider(_args).notifier).quit();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('⚔️ Duel'),
          automaticallyImplyLeading: false,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient:
                isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
          ),
          child: SafeArea(
            child: _buildBody(state, theme, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(DuelGameState state, ThemeData theme, bool isDark) {
    switch (state.phase) {
      case DuelPhase.countdown:
        return _buildCountdown(state, isDark);
      case DuelPhase.finishing:
        return _buildFinishing(isDark);
      case DuelPhase.error:
        return _buildError(state, isDark);
      case DuelPhase.playing:
      case DuelPhase.finished:
        // While 'finished' lasts a frame before navigation, keep showing
        // the play UI rather than flashing the countdown.
        return _buildPlay(state, theme, isDark);
    }
  }

  Widget _buildPlay(DuelGameState state, ThemeData theme, bool isDark) {
    final currentWord = state.currentWord;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: AppTheme.glassCard(isDark: isDark),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ScoreColumn(
                label: 'You',
                score: state.myScore,
                color: AppTheme.violet,
                isDark: isDark,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppTheme.fireGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '⚔️ VS',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
              _ScoreColumn(
                label: 'Opponent',
                score: state.opponentScore,
                color: AppTheme.error,
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Question ${state.currentIndex + 1} of ${widget.words.length}',
            style: TextStyle(
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
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
                const SizedBox(height: 14),
                Text(
                  currentWord['word'] as String? ?? '',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: state.currentOptions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final option = state.currentOptions[index];
              final isCorrect = option == currentWord['translation'];
              final isSelected = state.selectedOption == index;
              final answered = state.answered;

              Color getBg() {
                if (!answered) {
                  return isDark
                      ? const Color(0xFF1E2140).withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.8);
                }
                if (isCorrect) {
                  return AppTheme.success
                      .withValues(alpha: isDark ? 0.15 : 0.1);
                }
                if (isSelected && !isCorrect) {
                  return AppTheme.error
                      .withValues(alpha: isDark ? 0.15 : 0.1);
                }
                return isDark
                    ? const Color(0xFF1E2140).withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.6);
              }

              Color getBorder() {
                if (!answered) {
                  return isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06);
                }
                if (isCorrect) return AppTheme.success;
                if (isSelected && !isCorrect) return AppTheme.error;
                return isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03);
              }

              return InkWell(
                onTap: () => ref
                    .read(duelGameProvider(_args).notifier)
                    .checkAnswer(index),
                borderRadius: AppTheme.borderRadiusMd,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: getBg(),
                    borderRadius: AppTheme.borderRadiusMd,
                    border: Border.all(color: getBorder(), width: 2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
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
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          option,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (answered && isCorrect)
                        const Icon(Icons.check_circle_rounded,
                            color: AppTheme.success)
                      else if (answered && isSelected && !isCorrect)
                        const Icon(Icons.cancel_rounded,
                            color: AppTheme.error),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCountdown(DuelGameState state, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Ready...',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.violet.withValues(alpha: 0.15),
            ),
            child: Text(
              '${state.countdown}',
              style: const TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.w900,
                color: AppTheme.violet,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishing(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            'Settling duel...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(DuelGameState state, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                color: AppTheme.error, size: 56),
            const SizedBox(height: 16),
            Text(
              state.errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/duels'),
              child: const Text('Back to Lobby'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  final String label;
  final int score;
  final Color color;
  final bool isDark;

  const _ScoreColumn({
    required this.label,
    required this.score,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: isDark
                ? AppTheme.textSecondaryDark
                : AppTheme.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$score',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
