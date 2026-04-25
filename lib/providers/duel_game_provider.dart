import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/duel_service.dart';

/// Phase of an active duel game.
///
/// Drives both UI rendering and navigation. The router/screen treats
/// `finished` as the cue to push the results screen — navigation is a
/// function of state, never of imperative event handlers.
enum DuelPhase {
  countdown,
  playing,
  finishing,
  finished,
  error,
}

/// Arguments needed to construct a duel game.
///
/// Equality is keyed on `duelId` only so a re-entry with the same duel
/// (e.g., a widget rebuild) reuses the same notifier instance instead of
/// constructing a fresh one and restarting the countdown.
@immutable
class DuelGameArgs {
  final String duelId;
  final List<Map<String, dynamic>> words;
  final bool isChallenger;
  final String myId;

  const DuelGameArgs({
    required this.duelId,
    required this.words,
    required this.isChallenger,
    required this.myId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DuelGameArgs && other.duelId == duelId);

  @override
  int get hashCode => duelId.hashCode;
}

/// Immutable snapshot of the duel game.
@immutable
class DuelGameState {
  final DuelGameArgs args;
  final int currentIndex;
  final int myScore;
  final int opponentScore;
  final List<String> currentOptions;
  final bool answered;
  final int? selectedOption;
  final DuelPhase phase;
  final int countdown;
  final int myXpGain;
  final bool didWin;
  final bool isDraw;
  final int finalOpponentScore;
  final String opponentUsername;
  final String? errorMessage;

  const DuelGameState({
    required this.args,
    required this.currentIndex,
    required this.myScore,
    required this.opponentScore,
    required this.currentOptions,
    required this.answered,
    required this.selectedOption,
    required this.phase,
    required this.countdown,
    required this.myXpGain,
    required this.didWin,
    required this.isDraw,
    required this.finalOpponentScore,
    required this.opponentUsername,
    required this.errorMessage,
  });

  Map<String, dynamic> get currentWord => args.words[currentIndex];
  bool get isLastQuestion => currentIndex >= args.words.length - 1;

  DuelGameState copyWith({
    int? currentIndex,
    int? myScore,
    int? opponentScore,
    List<String>? currentOptions,
    bool? answered,
    Object? selectedOption = _sentinel,
    DuelPhase? phase,
    int? countdown,
    int? myXpGain,
    bool? didWin,
    bool? isDraw,
    int? finalOpponentScore,
    String? opponentUsername,
    Object? errorMessage = _sentinel,
  }) {
    return DuelGameState(
      args: args,
      currentIndex: currentIndex ?? this.currentIndex,
      myScore: myScore ?? this.myScore,
      opponentScore: opponentScore ?? this.opponentScore,
      currentOptions: currentOptions ?? this.currentOptions,
      answered: answered ?? this.answered,
      selectedOption: identical(selectedOption, _sentinel)
          ? this.selectedOption
          : selectedOption as int?,
      phase: phase ?? this.phase,
      countdown: countdown ?? this.countdown,
      myXpGain: myXpGain ?? this.myXpGain,
      didWin: didWin ?? this.didWin,
      isDraw: isDraw ?? this.isDraw,
      finalOpponentScore: finalOpponentScore ?? this.finalOpponentScore,
      opponentUsername: opponentUsername ?? this.opponentUsername,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const _sentinel = Object();

/// Owns all state and side-effects for an active duel game.
///
/// Replaces the scattered widget-state + ad-hoc realtime callbacks of the
/// old `duel_game_screen.dart`. One realtime channel, one timer set, one
/// authoritative state object. Navigation to the results screen is driven
/// by phase transitions in this notifier — the widget just listens.
class DuelGameNotifier extends StateNotifier<DuelGameState> {
  static const _answerRevealMs = 1200;
  static const _finishWaitTimeout = Duration(seconds: 30);

  final DuelGameArgs args;
  RealtimeChannel? _channel;
  Timer? _countdownTimer;
  Timer? _nextQuestionTimer;
  Timer? _finishTimeoutTimer;

  DuelGameNotifier(this.args) : super(_initialState(args)) {
    _subscribe();
    _startCountdown();
  }

  static DuelGameState _initialState(DuelGameArgs args) {
    return DuelGameState(
      args: args,
      currentIndex: 0,
      myScore: 0,
      opponentScore: 0,
      currentOptions: _generateOptions(args.words, 0),
      answered: false,
      selectedOption: null,
      phase: DuelPhase.countdown,
      countdown: 3,
      myXpGain: 0,
      didWin: false,
      isDraw: false,
      finalOpponentScore: 0,
      opponentUsername: '???',
      errorMessage: null,
    );
  }

  static List<String> _generateOptions(
      List<Map<String, dynamic>> words, int index) {
    if (index >= words.length) return const [];
    final current = words[index];
    final correct = current['translation'] as String;
    final distractors = words
        .where((w) => w['id'] != current['id'])
        .map((w) => w['translation'] as String)
        .toList()
      ..shuffle(Random());
    final options = <String>[correct, ...distractors.take(3)];
    options.shuffle(Random());
    return options;
  }

  // ─── Subscriptions ───────────────────────────────────────────────

  void _subscribe() {
    _channel = Supabase.instance.client.channel('duel:${args.duelId}')
      ..onBroadcast(
        event: 'score_update',
        callback: (payload) {
          if (!mounted) return;
          final senderId = payload['userId'] as String?;
          if (senderId == args.myId) return;
          final score = (payload['score'] as num?)?.toInt();
          if (score != null && score != state.opponentScore) {
            state = state.copyWith(opponentScore: score);
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'duels',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: args.duelId,
        ),
        callback: _onDbUpdate,
      )
      ..subscribe();
  }

  void _onDbUpdate(PostgresChangePayload payload) {
    if (!mounted) return;
    final row = payload.newRecord;

    // Score sync — DB is the reliability net for missed broadcasts.
    final opponentField =
        args.isChallenger ? 'opponent_score' : 'challenger_score';
    final dbOpponentScore = (row[opponentField] as num?)?.toInt();
    if (dbOpponentScore != null && dbOpponentScore != state.opponentScore) {
      state = state.copyWith(opponentScore: dbOpponentScore);
    }

    // Authoritative finish — opponent's RPC completed before ours.
    final status = row['status'] as String?;
    if (status == 'finished' && state.phase != DuelPhase.finished) {
      _consumeFinishedRow(row);
    }
  }

  void _consumeFinishedRow(Map<String, dynamic> row) {
    if (!mounted) return;
    final winnerId = row['winner_id'] as String?;
    final myXp = args.isChallenger
        ? ((row['challenger_xp'] ?? row['challenger_xp_gain']) as num?)
                ?.toInt() ??
            0
        : ((row['opponent_xp'] ?? row['opponent_xp_gain']) as num?)?.toInt() ??
            0;
    final opponentScore = args.isChallenger
        ? (row['opponent_score'] as num?)?.toInt() ?? state.opponentScore
        : (row['challenger_score'] as num?)?.toInt() ?? state.opponentScore;
    final opponentName = args.isChallenger
        ? row['opponent_username'] as String? ?? state.opponentUsername
        : row['challenger_username'] as String? ?? state.opponentUsername;

    _finishTimeoutTimer?.cancel();
    state = state.copyWith(
      phase: DuelPhase.finished,
      myXpGain: myXp,
      didWin: winnerId == args.myId,
      isDraw: winnerId == null,
      finalOpponentScore: opponentScore,
      opponentUsername: opponentName,
    );
  }

  // ─── Countdown ───────────────────────────────────────────────────

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (state.countdown > 1) {
        state = state.copyWith(countdown: state.countdown - 1);
      } else {
        state = state.copyWith(phase: DuelPhase.playing, countdown: 0);
        t.cancel();
      }
    });
  }

  // ─── Commands ────────────────────────────────────────────────────

  void checkAnswer(int index) {
    if (state.answered || state.phase != DuelPhase.playing) return;

    final word = state.currentWord;
    final selected = state.currentOptions[index];
    final correct = word['translation'] as String;
    final isCorrect = selected == correct;

    final newScore = isCorrect
        ? state.myScore + 1
        : (state.myScore > 0 ? state.myScore - 1 : 0);

    state = state.copyWith(
      myScore: newScore,
      answered: true,
      selectedOption: index,
    );

    _channel?.sendBroadcastMessage(
      event: 'score_update',
      payload: {'userId': args.myId, 'score': newScore},
    );

    DuelService.updateScore(
      duelId: args.duelId,
      playerId: args.myId,
      isChallenger: args.isChallenger,
      newScore: newScore,
    );

    _nextQuestionTimer?.cancel();
    _nextQuestionTimer = Timer(
      const Duration(milliseconds: _answerRevealMs),
      _advance,
    );
  }

  void _advance() {
    if (!mounted || state.phase != DuelPhase.playing) return;

    if (!state.isLastQuestion) {
      final next = state.currentIndex + 1;
      state = state.copyWith(
        currentIndex: next,
        currentOptions: _generateOptions(args.words, next),
        answered: false,
        selectedOption: null,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (!mounted) return;
    state = state.copyWith(phase: DuelPhase.finishing);

    final result = await DuelService.finishDuel(
      duelId: args.duelId,
      isChallenger: args.isChallenger,
      myFinalScore: state.myScore,
    );

    if (!mounted) return;

    if (result == null) {
      // Network error — wait for Postgres Changes 'finished' event,
      // with a hard timeout to force-settle if the opponent vanishes.
      _scheduleFinishTimeout();
      return;
    }

    final status = result['status'] as String?;
    if (status == 'finished') {
      _consumeFinishedRow(result);
    } else if (status == 'waiting') {
      _scheduleFinishTimeout();
    } else {
      state = state.copyWith(
        phase: DuelPhase.error,
        errorMessage: 'Could not finish duel: ${result['reason'] ?? status}',
      );
    }
  }

  void _scheduleFinishTimeout() {
    _finishTimeoutTimer?.cancel();
    _finishTimeoutTimer = Timer(_finishWaitTimeout, () async {
      if (!mounted || state.phase == DuelPhase.finished) return;
      final result = await DuelService.forceFinishDuel(args.duelId);
      if (!mounted) return;
      if (result != null && result['status'] == 'finished') {
        _consumeFinishedRow(result);
      } else {
        state = state.copyWith(
          phase: DuelPhase.error,
          errorMessage: 'Opponent never finished. Try again later.',
        );
      }
    });
  }

  /// Player chose to quit mid-duel — forfeit and force-settle.
  Future<void> quit() async {
    if (state.phase == DuelPhase.finished ||
        state.phase == DuelPhase.error) {
      return;
    }
    state = state.copyWith(phase: DuelPhase.finishing);
    final result = await DuelService.forceFinishDuel(args.duelId);
    if (!mounted) return;
    if (result != null && result['status'] == 'finished') {
      _consumeFinishedRow(result);
    } else {
      state = state.copyWith(
        phase: DuelPhase.error,
        errorMessage: 'Could not quit cleanly.',
      );
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _nextQuestionTimer?.cancel();
    _finishTimeoutTimer?.cancel();
    final channel = _channel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
      _channel = null;
    }
    super.dispose();
  }
}

/// Auto-disposed family — one notifier per active duel. When the last
/// widget watching it unmounts, the notifier disposes itself, cancelling
/// timers and unsubscribing the realtime channel. No leaks.
final duelGameProvider = StateNotifierProvider.autoDispose
    .family<DuelGameNotifier, DuelGameState, DuelGameArgs>(
  (ref, args) => DuelGameNotifier(args),
);
