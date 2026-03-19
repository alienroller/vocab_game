import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vocab.dart';
import '../providers/vocab_provider.dart';
import '../screens/result_screen.dart';

class MatchingGame extends ConsumerStatefulWidget {
  const MatchingGame({super.key});

  @override
  ConsumerState<MatchingGame> createState() => _MatchingGameState();
}

class _MatchingGameState extends ConsumerState<MatchingGame> {
  late List<Vocab> _gameWords;
  late List<Vocab> _leftColumn;
  late List<Vocab> _rightColumn;
  
  Vocab? _selectedLeft;
  Vocab? _selectedRight;
  
  final Set<String> _matchedIds = {};
  int _score = 0;
  int _moves = 0;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  void _initGame() {
    final allVocab = ref.read(vocabProvider);
    _gameWords = List.from(allVocab)..shuffle(Random());
    // Use up to 6 pairs for a matching round
    if (_gameWords.length > 6) {
      _gameWords = _gameWords.sublist(0, 6);
    }
    
    _leftColumn = List.from(_gameWords)..shuffle(Random());
    _rightColumn = List.from(_gameWords)..shuffle(Random());
    
    _matchedIds.clear();
    _selectedLeft = null;
    _selectedRight = null;
    _score = 0;
    _moves = 0;
  }

  void _handleTap(Vocab word, bool isLeft) {
    if (_matchedIds.contains(word.id)) return;

    setState(() {
      if (isLeft) {
        _selectedLeft = _selectedLeft == word ? null : word;
      } else {
        _selectedRight = _selectedRight == word ? null : word;
      }
    });

    if (_selectedLeft != null && _selectedRight != null) {
      _moves++;
      final isMatch = _selectedLeft!.id == _selectedRight!.id;
      
      if (isMatch) {
        _matchedIds.add(_selectedLeft!.id);
        _score++;
        _selectedLeft = null;
        _selectedRight = null;
        
        if (_matchedIds.length == _gameWords.length) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ResultScreen(
                  score: _score, // Used as basic points here
                  total: _moves, // Show moves instead of total points
                  gameName: 'Matching',
                  onPlayAgain: () => setState(() => _initGame()),
                ),
              ),
            );
          });
        }
      } else {
        // Incorrect match, delay and clear
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          setState(() {
            _selectedLeft = null;
            _selectedRight = null;
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_gameWords.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matching'),
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
          child: Row(
            children: [
              // Left Column (English)
              Expanded(
                child: Column(
                  children: _leftColumn.map((word) {
                    final isMatched = _matchedIds.contains(word.id);
                    final isSelected = _selectedLeft == word;
                    
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: Material(
                            color: isMatched 
                                ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)
                                : isSelected 
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            elevation: isMatched ? 0 : isSelected ? 4 : 1,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: isMatched ? null : () => _handleTap(word, true),
                              child: Center(
                                child: Text(
                                  word.english,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isMatched ? theme.colorScheme.outline : theme.colorScheme.onSurface,
                                    decoration: isMatched ? TextDecoration.lineThrough : null,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 16),
              // Right Column (Uzbek)
              Expanded(
                child: Column(
                  children: _rightColumn.map((word) {
                    final isMatched = _matchedIds.contains(word.id);
                    final isSelected = _selectedRight == word;
                    
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: Material(
                            color: isMatched 
                                ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)
                                : isSelected 
                                    ? theme.colorScheme.tertiaryContainer
                                    : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            elevation: isMatched ? 0 : isSelected ? 4 : 1,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: isMatched ? null : () => _handleTap(word, false),
                              child: Center(
                                child: Text(
                                  word.uzbek,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isMatched ? theme.colorScheme.outline : theme.colorScheme.onSurface,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
