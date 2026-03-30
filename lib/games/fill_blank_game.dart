import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vocab.dart';
import '../providers/vocab_provider.dart';
import '../screens/result_screen.dart';

class FillBlankGame extends ConsumerStatefulWidget {
  const FillBlankGame({super.key});

  @override
  ConsumerState<FillBlankGame> createState() => _FillBlankGameState();
}

class _FillBlankGameState extends ConsumerState<FillBlankGame> {
  late List<Vocab> _gameVocab;
  int _currentIndex = 0;
  int _score = 0;
  
  late String _targetWord;
  late List<String> _displayChars;
  late List<bool> _isBlanked;
  
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  bool _answered = false;
  bool _isCorrect = false;

  @override
  void initState() {
    super.initState();
    final allVocab = ref.read(vocabProvider);
    _gameVocab = List.from(allVocab)..shuffle(Random());
    if (_gameVocab.length > 10) {
      _gameVocab = _gameVocab.sublist(0, 10);
    }
    _setupQuestion();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setupQuestion() {
    final currentVocab = _gameVocab[_currentIndex];
    _targetWord = currentVocab.uzbek.toLowerCase();
    
    _displayChars = _targetWord.split('');
    _isBlanked = List.generate(_displayChars.length, (index) => false);
    
    // Blank out ~50% of characters (but at least 1, and don't blank spaces)
    final random = Random();
    int lettersToBlank = max(1, (_displayChars.length / 2).ceil());
    int blanked = 0;
    
    // Don't blank out spaces or punctuation
    final validIndices = [];
    for (int i = 0; i < _displayChars.length; i++) {
      if (RegExp(r'[a-z]').hasMatch(_displayChars[i])) {
        validIndices.add(i);
      }
    }
    
    validIndices.shuffle(random);
    
    for (int i = 0; i < validIndices.length && blanked < lettersToBlank; i++) {
      _isBlanked[validIndices[i]] = true;
      blanked++;
    }
    
    _controller.clear();
    _answered = false;
    _isCorrect = false;
    
    // Auto-focus after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _checkAnswer() {
    if (_answered || _controller.text.trim().isEmpty) return;
    
    final guess = _controller.text.trim().toLowerCase();
    
    setState(() {
      _answered = true;
      _isCorrect = guess == _targetWord;
      
      if (_isCorrect) {
        _score++;
      }
    });
    
    _focusNode.unfocus();

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      
      if (_currentIndex < _gameVocab.length - 1) {
        setState(() {
          _currentIndex++;
          _setupQuestion();
        });
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              score: _score,
              total: _gameVocab.length,
              gameName: 'Fill in the Blank',
              onPlayAgain: () {
                setState(() {
                  _currentIndex = 0;
                  _score = 0;
                  _gameVocab.shuffle(Random());
                  _setupQuestion();
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
    if (_gameVocab.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final theme = Theme.of(context);
    final currentWord = _gameVocab[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fill in the Blank'),
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
            value: (_currentIndex + 1) / _gameVocab.length,
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
                'Word ${_currentIndex + 1} of ${_gameVocab.length}',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // English Prompt
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Text(
                      'Translate:',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
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
              
              // Clue Display
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 16,
                children: List.generate(_displayChars.length, (index) {
                  final char = _displayChars[index];
                  final isBlank = _isBlanked[index];
                  
                  // Don't draw boxes for spaces
                  if (char == ' ') {
                    return const SizedBox(width: 16, height: 48);
                  }
                  
                  return Container(
                    width: 40,
                    height: 48,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isBlank ? theme.colorScheme.primary : theme.colorScheme.outline,
                          width: 3,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isBlank ? (
                        _answered ? (_isCorrect ? char : char) : '_'
                      ) : char,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _answered && isBlank 
                            ? (_isCorrect ? Colors.green : Colors.red)
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 48),
              
              // Input Field
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  labelText: 'Type the full word',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _checkAnswer,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _checkAnswer(),
                enabled: !_answered,
                autocorrect: false,
              ),
              
              const SizedBox(height: 16),
              
              // Feedback
              if (_answered)
                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (_isCorrect ? Colors.green : Colors.red).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isCorrect ? Icons.check_circle : Icons.cancel,
                          color: _isCorrect ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isCorrect 
                              ? 'Correct!' 
                              : 'Incorrect. The word was $_targetWord',
                          style: TextStyle(
                            color: _isCorrect ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
