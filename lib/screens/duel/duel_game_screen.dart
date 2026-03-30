import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/duel_service.dart';
import 'duel_results_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _myId = Hive.box('userProfile').get('id') as String;
    _generateOptions();
    _subscribeToScores();
  }

  void _subscribeToScores() {
    _channel = Supabase.instance.client.channel('duel-${widget.duelId}');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'duels',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.duelId,
          ),
          callback: (payload) {
            final newData = payload.newRecord;
            if (mounted) {
              setState(() {
                if (widget.isChallenger) {
                  _opponentScore =
                      (newData['opponent_score'] as int?) ?? _opponentScore;
                } else {
                  _opponentScore =
                      (newData['challenger_score'] as int?) ?? _opponentScore;
                }
              });
            }
          },
        )
        .subscribe();
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
    if (_answered) return;

    final selected = _currentOptions[index];
    final correct =
        widget.words[_currentIndex]['translation'] as String;
    final isCorrect = selected == correct;

    setState(() {
      _answered = true;
      _selectedOption = index;
      if (isCorrect) _myScore++;
    });

    // Update score in real-time
    DuelService.updateScore(
      duelId: widget.duelId,
      playerId: _myId,
      isChallenger: widget.isChallenger,
      newScore: _myScore,
    );

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

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

  Future<void> _finishDuel() async {
    final challengerId = widget.isChallenger
        ? _myId
        : (await Supabase.instance.client
                .from('duels')
                .select('challenger_id')
                .eq('id', widget.duelId)
                .single())['challenger_id'] as String;
    final opponentId = widget.isChallenger
        ? (await Supabase.instance.client
                .from('duels')
                .select('opponent_id')
                .eq('id', widget.duelId)
                .single())['opponent_id'] as String
        : _myId;

    // Get the opponent's username from the duel record
    final duelData = await Supabase.instance.client
        .from('duels')
        .select('challenger_username, opponent_username')
        .eq('id', widget.duelId)
        .single();
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

    if (mounted) {
      final myXpGain = widget.isChallenger
          ? (result?['challenger_xp'] as int?) ?? 0
          : (result?['opponent_xp'] as int?) ?? 0;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DuelResultsScreen(
            myScore: _myScore,
            opponentScore: _opponentScore,
            totalWords: widget.words.length,
            myXpGain: myXpGain,
            didWin: _myScore > _opponentScore,
            isDraw: _myScore == _opponentScore,
            opponentUsername: opponentName,
          ),
        ),
      );
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚔️ Duel'),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / widget.words.length,
          ),
        ),
      ),
      body: Column(
        children: [
          // Score bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const Text('You',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '$_myScore',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                Text(
                  'VS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Column(
                  children: [
                    const Text('Opponent',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '$_opponentScore',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Word card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    'Translate:',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currentWord['word'] as String? ?? '',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Options
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _currentOptions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final option = _currentOptions[index];
                final isCorrect =
                    option == currentWord['translation'];
                final isSelected = _selectedOption == index;

                Color bgColor = theme.colorScheme.surface;
                Color borderColor = theme.colorScheme.outline;

                if (_answered) {
                  if (isCorrect) {
                    bgColor = Colors.green.withValues(alpha: 0.15);
                    borderColor = Colors.green;
                  } else if (isSelected) {
                    bgColor = Colors.red.withValues(alpha: 0.15);
                    borderColor = Colors.red;
                  }
                }

                return InkWell(
                  onTap: () => _checkAnswer(index),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor, width: 2),
                    ),
                    child: Text(
                      option,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
