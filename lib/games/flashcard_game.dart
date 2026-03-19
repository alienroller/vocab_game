import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vocab.dart';
import '../providers/vocab_provider.dart';

class FlashcardGame extends ConsumerStatefulWidget {
  const FlashcardGame({super.key});

  @override
  ConsumerState<FlashcardGame> createState() => _FlashcardGameState();
}

class _FlashcardGameState extends ConsumerState<FlashcardGame> {
  late PageController _pageController;
  late List<Vocab> _shuffledVocab;
  int _currentIndex = 0;
  bool _showUzbek = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Getting state in initState of ConsumerStatefulWidget
    final vocabList = ref.read(vocabProvider);
    _shuffledVocab = List.from(vocabList)..shuffle(Random());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _flipCard() {
    setState(() {
      _showUzbek = !_showUzbek;
    });
  }

  void _nextCard() {
    if (_currentIndex < _shuffledVocab.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevCard() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shuffledVocab.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final theme = Theme.of(context);
    final currentWord = _shuffledVocab[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / _shuffledVocab.length,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Card ${_currentIndex + 1} of ${_shuffledVocab.length}',
              style: theme.textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _showUzbek = false; // Reset flip state for new card
                });
              },
              itemCount: _shuffledVocab.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: _flipCard,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                    decoration: BoxDecoration(
                      color: _showUzbek ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        final rotateAnim = Tween(begin: 3.14, end: 0.0).animate(animation);
                        return AnimatedBuilder(
                          animation: rotateAnim,
                          child: child,
                          builder: (context, widget) {
                            final isUnder = (ValueKey(_showUzbek) != widget?.key);
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
                      child: Padding(
                        key: ValueKey(_showUzbek),
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _showUzbek ? 'Uzbek' : 'English',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: _showUzbek 
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.primary,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _showUzbek ? currentWord.uzbek : currentWord.english,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _showUzbek 
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Icon(
                              Icons.touch_app,
                              color: (_showUzbek ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface).withOpacity(0.5),
                            ),
                            Text(
                              'Tap to flip',
                              style: TextStyle(
                                color: (_showUzbek ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface).withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.filledTonal(
                  onPressed: _currentIndex > 0 ? _prevCard : null,
                  icon: const Icon(Icons.arrow_back),
                  iconSize: 32,
                  padding: const EdgeInsets.all(16),
                ),
                IconButton.filledTonal(
                  onPressed: _currentIndex < _shuffledVocab.length - 1 ? _nextCard : null,
                  icon: const Icon(Icons.arrow_forward),
                  iconSize: 32,
                  padding: const EdgeInsets.all(16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
