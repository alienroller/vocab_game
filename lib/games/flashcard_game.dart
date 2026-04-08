import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vocab.dart';
import '../providers/vocab_provider.dart';
import '../theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'game_streak_mixin.dart';

class FlashcardGame extends ConsumerStatefulWidget {
  const FlashcardGame({super.key});

  @override
  ConsumerState<FlashcardGame> createState() => _FlashcardGameState();
}

class _FlashcardGameState extends ConsumerState<FlashcardGame>
    with GameStreakMixin {
  late PageController _pageController;
  late List<Vocab> _shuffledVocab;
  int _currentIndex = 0;
  bool _showUzbek = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    final vocabList = ref.read(vocabProvider);
    _shuffledVocab = List.from(vocabList)..shuffle(Random());
    checkAndShowStreak();
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
    final isDark = theme.brightness == Brightness.dark;
    final currentWord = _shuffledVocab[_currentIndex];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await showExitConfirmation(context);
        if (shouldPop == true && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Flashcards'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 8),
          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_shuffledVocab.length, (i) {
              return Container(
                width: i == _currentIndex ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: i == _currentIndex ? AppTheme.primaryGradient : null,
                  color: i == _currentIndex
                      ? null
                      : (i < _currentIndex
                          ? AppTheme.violet.withValues(alpha: 0.4)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.08))),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _showUzbek = false;
                });
              },
              itemCount: _shuffledVocab.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: _flipCard,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                    decoration: BoxDecoration(
                      gradient: _showUzbek
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFFFB74D), Color(0xFFE65100)],
                            )
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
                            ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: (_showUzbek ? const Color(0xFFE65100) : const Color(0xFF0288D1))
                              .withValues(alpha: 0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
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
                              _showUzbek ? '🇺🇿 Uzbek' : '🇬🇧 English',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.8),
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _showUzbek ? currentWord.uzbek : currentWord.english,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 36,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Icon(
                              Icons.touch_app,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            Text(
                              'Tap to flip',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
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
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _currentIndex > 0 ? _prevCard : null,
                    icon: const Icon(Icons.arrow_back_rounded),
                    iconSize: 28,
                    padding: const EdgeInsets.all(14),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _currentIndex < _shuffledVocab.length - 1 ? _nextCard : null,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    iconSize: 28,
                    padding: const EdgeInsets.all(14),
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
      ),
    );
  }
}
