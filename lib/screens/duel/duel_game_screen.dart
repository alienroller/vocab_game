import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/duel_service.dart';
import '../../theme/app_theme.dart';

/// Live duel game screen — both players answer the same words simultaneously.
///
/// Opponent's score updates in real-time via Supabase Realtime.
class DuelGameScreen extends StatefulWidget {
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
  State<DuelGameScreen> createState() => _DuelGameScreenState();
}

class _DuelGameScreenState extends State<DuelGameScreen> {
  int _currentIndex = 0;
  int _myScore = 0;
  int _opponentScore = 0;
  bool _answered = false;
  int? _selectedOption;
  late List<String> _currentOptions;
  late String _myId;
  RealtimeChannel? _channel;

  bool _isStarted = false;
  int _countdown = 3;
  bool _isFinishedLocally = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _myId = Hive.box('userProfile').get('id') as String;
    _generateOptions();
    _subscribeToScores();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          _isStarted = true;
          timer.cancel();
        }
      });
    });
  }

  void _subscribeToScores() {
    _channel = Supabase.instance.client.channel('duel:${widget.duelId}')
      // BROADCAST: opponent's live score arrives here within ~50ms of each answer.
      // Sender echoes back too — ignore messages from self.
      ..onBroadcast(
        event: 'score_update',
        callback: (payload) {
          if (!mounted) return;
          final senderId = payload['userId'] as String?;
          if (senderId == _myId) return; // ignore own echo
          setState(() {
            _opponentScore =
                (payload['score'] as num?)?.toInt() ?? _opponentScore;
          });
        },
      )
      // POSTGRES CHANGES: only used for status transitions (finished/settling).
      // Score updates no longer come through this path — they come via Broadcast.
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'duels',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: widget.duelId,
        ),
        callback: (payload) {
          if (!mounted) return;
          final status = payload.newRecord['status'] as String?;
          if (status == 'finished' && !_isFinishedLocally) {
            _forceEndDuel();
          }
        },
      )
      ..subscribe();
  }

  void _generateOptions() {
    if (_currentIndex >= widget.words.length) return;

    final currentWord = widget.words[_currentIndex];
    final correctAnswer = currentWord['translation'] as String;

    // Get 3 wrong answers from other words
    final distractors = widget.words
        .where((w) => w['id'] != currentWord['id'])
        .map((w) => w['translation'] as String)
        .toList()
      ..shuffle();

    _currentOptions = [correctAnswer, ...distractors.take(3)];
    _currentOptions.shuffle();
    _answered = false;
    _selectedOption = null;
  }

  void _checkAnswer(int index) {
    if (_answered || !_isStarted || _isFinishedLocally) return;

    final selected = _currentOptions[index];
    final correct =
        widget.words[_currentIndex]['translation'] as String;
    final isCorrect = selected == correct;

    setState(() {
      _answered = true;
      _selectedOption = index;
      if (isCorrect) {
        _myScore++;
      } else {
        if (_myScore > 0) _myScore--;
      }
    });

    // Broadcast score to opponent immediately (<50ms delivery).
    _channel?.sendBroadcastMessage(
      event: 'score_update',
      payload: {'userId': _myId, 'score': _myScore},
    );

    // Persist score to DB (source of truth for final results).
    DuelService.updateScore(
      duelId: widget.duelId,
      playerId: _myId,
      isChallenger: widget.isChallenger,
      newScore: _myScore,
    );

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted || _isFinishedLocally) return;

      if (_currentIndex < widget.words.length - 1) {
        setState(() {
          _currentIndex++;
          _generateOptions();
        });
      } else {
        _finishDuel();
      }
    });
  }

  Future<void> _forceEndDuel() async {
    setState(() => _isFinishedLocally = true);

    // status == 'finished' means winner_id and XP are already committed.
    // A small delay guards against the edge case where the finishing device
    // writes 'finished' a fraction before the XP columns land.
    await Future.delayed(const Duration(milliseconds: 400));

    final duelData = await Supabase.instance.client
        .from('duels')
        .select()
        .eq('id', widget.duelId)
        .single();

    if (!mounted) return;

    final myXpGain = widget.isChallenger
        ? (duelData['challenger_xp_gain'] as int?) ?? 0
        : (duelData['opponent_xp_gain'] as int?) ?? 0;

    final winnerId = duelData['winner_id'] as String?;
    final didWin = winnerId == _myId;
    final isDraw = winnerId == null;

    final opponentName = widget.isChallenger
        ? duelData['opponent_username'] as String? ?? '???'
        : duelData['challenger_username'] as String? ?? '???';

    // Use DB scores as source of truth — broadcast may have missed a packet.
    final opponentDbScore = widget.isChallenger
        ? (duelData['opponent_score'] as int?) ?? _opponentScore
        : (duelData['challenger_score'] as int?) ?? _opponentScore;

    context.pushReplacement('/duels/results', extra: {
      'myScore': _myScore,
      'opponentScore': opponentDbScore,
      'totalWords': widget.words.length,
      'myXpGain': myXpGain,
      'didWin': didWin,
      'isDraw': isDraw,
      'opponentUsername': opponentName,
    });
  }

  Future<void> _finishDuel() async {
    if (_isFinishedLocally) return;
    setState(() => _isFinishedLocally = true);

    // Fetch both IDs and usernames in a single query.
    final duelData = await Supabase.instance.client
        .from('duels')
        .select('challenger_id, opponent_id, challenger_username, opponent_username')
        .eq('id', widget.duelId)
        .single();

    final challengerId = duelData['challenger_id'] as String;
    final opponentId = duelData['opponent_id'] as String;
    final opponentName = widget.isChallenger
        ? duelData['opponent_username'] as String? ?? '???'
        : duelData['challenger_username'] as String? ?? '???';

    final myChallengerScore = widget.isChallenger ? _myScore : _opponentScore;
    final myOpponentScore = widget.isChallenger ? _opponentScore : _myScore;

    final result = await DuelService.finishDuel(
      duelId: widget.duelId,
      challengerId: challengerId,
      opponentId: opponentId,
      challengerScore: myChallengerScore,
      opponentScore: myOpponentScore,
    );

    if (result == null) {
      // finishDuel returned null — either the other device already claimed
      // the finish (CAS guard in DuelService) or a transient error occurred.
      // Reset the flag so the Postgres Changes 'finished' event can still
      // trigger _forceEndDuel and navigate us to results.
      if (mounted) setState(() => _isFinishedLocally = false);
      return;
    }

    if (mounted) {
      final myXpGain = widget.isChallenger
          ? (result['challenger_xp'] as int?) ?? 0
          : (result['opponent_xp'] as int?) ?? 0;

      context.pushReplacement('/duels/results', extra: {
        'myScore': _myScore,
        'opponentScore': _opponentScore,
        'totalWords': widget.words.length,
        'myXpGain': myXpGain,
        'didWin': _myScore > _opponentScore,
        'isDraw': _myScore == _opponentScore,
        'opponentUsername': opponentName,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.words.isEmpty) {
      return const Scaffold(
          body: Center(child: Text('No words available')));
    }

    final currentWord = widget.words[_currentIndex];

    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Quit Duel?'),
            content: const Text('Are you sure you want to quit? You will forfeit this duel.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Quit'),
              ),
            ],
          ),
        );
        if (shouldPop == true && context.mounted) {
          context.pop();
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
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
        child: !_isStarted
            ? _buildCountdown(isDark)
            : Column(
        children: [
          // Score bar — glass
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: AppTheme.glassCard(isDark: isDark),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Text('You',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        )),
                    const SizedBox(height: 4),
                    Text(
                      '$_myScore',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.violet,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                Column(
                  children: [
                    Text('Opponent',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        )),
                    const SizedBox(height: 4),
                    Text(
                      '$_opponentScore',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Progress
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Question ${_currentIndex + 1} of ${widget.words.length}',
              style: TextStyle(
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Word card — glass
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
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

          // Options — glass cards
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _currentOptions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final option = _currentOptions[index];
                final isCorrect =
                    option == currentWord['translation'];
                final isSelected = _selectedOption == index;

                Color getBg() {
                  if (!_answered) {
                    return isDark
                        ? const Color(0xFF1E2140).withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.8);
                  }
                  if (isCorrect) return AppTheme.success.withValues(alpha: isDark ? 0.15 : 0.1);
                  if (isSelected && !isCorrect) return AppTheme.error.withValues(alpha: isDark ? 0.15 : 0.1);
                  return isDark ? const Color(0xFF1E2140).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.6);
                }

                Color getBorder() {
                  if (!_answered) return isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
                  if (isCorrect) return AppTheme.success;
                  if (isSelected && !isCorrect) return AppTheme.error;
                  return isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03);
                }

                return InkWell(
                  onTap: () => _checkAnswer(index),
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
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (_answered && isCorrect)
                          const Icon(Icons.check_circle_rounded, color: AppTheme.success)
                        else if (_answered && isSelected && !isCorrect)
                          const Icon(Icons.cancel_rounded, color: AppTheme.error),
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
      ),
    );
  }

  Widget _buildCountdown(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Ready...',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
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
              '$_countdown',
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

  @override
  void dispose() {
    _countdownTimer?.cancel();
    // removeChannel unsubscribes AND removes the channel from the client's
    // internal list — prevents ghost channels on screen re-entry.
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }
}
