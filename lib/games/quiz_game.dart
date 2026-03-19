import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vocab.dart';
import '../providers/vocab_provider.dart';
import '../screens/result_screen.dart';

class QuizGame extends ConsumerStatefulWidget {
  const QuizGame({super.key});

  @override
  ConsumerState<QuizGame> createState() => _QuizGameState();
}

class _QuizGameState extends ConsumerState<QuizGame> {
  late List<Vocab> _allVocab;
  late List<Vocab> _quizVocab;
  int _currentIndex = 0;
  int _score = 0;
  List<String> _currentOptions = [];
  bool _answered = false;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _allVocab = ref.read(vocabProvider);
    _quizVocab = List.from(_allVocab)..shuffle(Random());
    // Limit to max 10 questions for a quick game, or all if less
    if (_quizVocab.length > 10) {
      _quizVocab = _quizVocab.sublist(0, 10);
    }
    _generateOptions();
  }

  void _generateOptions() {
    final currentWord = _quizVocab[_currentIndex];
    final random = Random();
    
    // Get wrong options
    final distractors = _allVocab
        .where((v) => v.id != currentWord.id)
        .toList()
      ..shuffle(random);
      
    final selectedDistractors = distractors.take(3).map((v) => v.uzbek).toList();
    
    _currentOptions = [currentWord.uzbek, ...selectedDistractors];
    _currentOptions.shuffle(random);
    _answered = false;
    _selectedIndex = null;
  }

  void _checkAnswer(int index) {
    if (_answered) return;
    
    final selectedUzbek = _currentOptions[index];
    final isCorrect = selectedUzbek == _quizVocab[_currentIndex].uzbek;
    
    setState(() {
      _answered = true;
      _selectedIndex = index;
      if (isCorrect) _score++;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      
      if (_currentIndex < _quizVocab.length - 1) {
        setState(() {
          _currentIndex++;
          _generateOptions();
        });
      } else {
        // Game Over
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              score: _score,
              total: _quizVocab.length,
              gameName: 'Quiz',
              onPlayAgain: () {
                setState(() {
                  _currentIndex = 0;
                  _score = 0;
                  _quizVocab.shuffle(Random());
                  _generateOptions();
                });
              },
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_quizVocab.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final theme = Theme.of(context);
    final currentWord = _quizVocab[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                'Score: $_score',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / _quizVocab.length,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Question ${_currentIndex + 1} of ${_quizVocab.length}',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // English Word Card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Text(
                      'Translate this word:',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      currentWord.english,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              // Options List
              Expanded(
                child: ListView.separated(
                  itemCount: _currentOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final option = _currentOptions[index];
                    final isCorrectOption = option == currentWord.uzbek;
                    final isSelected = _selectedIndex == index;
                    
                    Color getButtonColor() {
                      if (!_answered) return theme.colorScheme.surface;
                      if (isCorrectOption) return Colors.green.shade100;
                      if (isSelected && !isCorrectOption) return Colors.red.shade100;
                      return theme.colorScheme.surface;
                    }

                    Color getBorderColor() {
                      if (!_answered) return theme.colorScheme.outline;
                      if (isCorrectOption) return Colors.green;
                      if (isSelected && !isCorrectOption) return Colors.red;
                      return theme.colorScheme.outline.withOpacity(0.5);
                    }

                    return InkWell(
                      onTap: () => _checkAnswer(index),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: getButtonColor(),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: getBorderColor(), width: 2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.primary.withOpacity(0.1),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                ['A', 'B', 'C', 'D'][index],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                option,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (_answered && isCorrectOption)
                              const Icon(Icons.check_circle, color: Colors.green)
                            else if (_answered && isSelected && !isCorrectOption)
                              const Icon(Icons.cancel, color: Colors.red)
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
    );
  }
}
