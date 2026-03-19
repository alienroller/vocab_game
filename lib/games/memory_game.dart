import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/vocab_provider.dart';
import '../screens/result_screen.dart';

class MemoryCard {
  final String id;
  final String text;
  final bool isEnglish;
  final String pairId;
  bool isFaceUp = false;
  bool isMatched = false;

  MemoryCard({
    required this.id,
    required this.text,
    required this.isEnglish,
    required this.pairId,
  });
}

class MemoryGame extends ConsumerStatefulWidget {
  const MemoryGame({super.key});

  @override
  ConsumerState<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends ConsumerState<MemoryGame> {
  late List<MemoryCard> _cards;
  int _moves = 0;
  List<int> _flippedIndices = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  void _initGame() {
    final allVocab = ref.read(vocabProvider);
    var selectedVocab = List.from(allVocab)..shuffle(Random());
    if (selectedVocab.length > 6) {
      selectedVocab = selectedVocab.sublist(0, 6); // Max 12 cards (3x4 grid)
    }

    _cards = [];
    final random = Random();
    for (var vocab in selectedVocab) {
      final String pairId = vocab.id;
      _cards.add(MemoryCard(
        id: '${pairId}_en',
        text: vocab.english,
        isEnglish: true,
        pairId: pairId,
      ));
      _cards.add(MemoryCard(
        id: '${pairId}_uz',
        text: vocab.uzbek,
        isEnglish: false,
        pairId: pairId,
      ));
    }
    
    _cards.shuffle(random);
    _moves = 0;
    _flippedIndices = [];
    _isProcessing = false;
  }

  void _onCardTap(int index) {
    if (_isProcessing || _cards[index].isFaceUp || _cards[index].isMatched) return;

    setState(() {
      _cards[index].isFaceUp = true;
      _flippedIndices.add(index);
    });

    if (_flippedIndices.length == 2) {
      _moves++;
      _isProcessing = true;
      
      final idx1 = _flippedIndices[0];
      final idx2 = _flippedIndices[1];
      
      if (_cards[idx1].pairId == _cards[idx2].pairId) {
        // Match!
        setState(() {
          _cards[idx1].isMatched = true;
          _cards[idx2].isMatched = true;
          _flippedIndices.clear();
          _isProcessing = false;
        });
        
        // Check win
        if (_cards.every((card) => card.isMatched)) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ResultScreen(
                  score: _cards.length ~/ 2,
                  total: _moves,
                  gameName: 'Memory',
                  onPlayAgain: () => setState(() => _initGame()),
                ),
              ),
            );
          });
        }
      } else {
        // No match, flip back down
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (!mounted) return;
          setState(() {
            _cards[idx1].isFaceUp = false;
            _cards[idx2].isFaceUp = false;
            _flippedIndices.clear();
            _isProcessing = false;
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final theme = Theme.of(context);
    final columns = _cards.length > 8 ? 3 : 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                'Moves: $_moves',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: 0.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _cards.length,
            itemBuilder: (context, index) {
              final card = _cards[index];
              final isRevealed = card.isFaceUp || card.isMatched;

              return GestureDetector(
                onTap: () => _onCardTap(index),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    final rotateAnim = Tween(begin: 3.14, end: 0.0).animate(animation);
                    return AnimatedBuilder(
                      animation: rotateAnim,
                      child: child,
                      builder: (context, widget) {
                        final isUnder = (ValueKey(isRevealed) != widget?.key);
                        var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
                        tilt *= isUnder ? -1.0 : 1.0;
                        final value = isUnder ? min(rotateAnim.value, 3.14 / 2) : rotateAnim.value;
                        
                        return Transform(
                          transform: Matrix4.rotationY(value)..setEntry(3, 0, tilt),
                          alignment: Alignment.center,
                          child: widget,
                        );
                      },
                    );
                  },
                  child: Container(
                    key: ValueKey(isRevealed),
                    decoration: BoxDecoration(
                      color: isRevealed 
                          ? (card.isMatched ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5) : theme.colorScheme.surface)
                          : theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isRevealed ? theme.colorScheme.outlineVariant : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isRevealed ? [] : [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: isRevealed
                        ? Text(
                            card.text,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: card.isMatched 
                                  ? theme.colorScheme.outline 
                                  : (card.isEnglish ? theme.colorScheme.primary : theme.colorScheme.secondary),
                            ),
                            textAlign: TextAlign.center,
                          )
                        : Icon(
                            Icons.question_mark_rounded,
                            size: 48,
                            color: theme.colorScheme.onPrimary.withOpacity(0.5),
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
