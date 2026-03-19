import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/vocab_provider.dart';
import '../games/flashcard_game.dart';
import '../games/quiz_game.dart';
import '../games/matching_game.dart';
import '../games/memory_game.dart';
import '../games/fill_blank_game.dart';

class GameSelectionScreen extends ConsumerWidget {
  const GameSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabList = ref.watch(vocabProvider);
    final theme = Theme.of(context);

    if (vocabList.length < 4) {
      return Scaffold(
        appBar: AppBar(title: const Text('Games')),
        body: const Center(
          child: Text('Need at least 4 words to play.'),
        ),
      );
    }

    final games = [
      {
        'title': 'Flashcards',
        'icon': Icons.style,
        'color': Colors.blue,
        'description': 'Flip cards to memorize vocabulary',
        'route': const FlashcardGame(),
      },
      {
        'title': 'Quiz',
        'icon': Icons.quiz,
        'color': Colors.green,
        'description': 'Test your knowledge with multiple choice',
        'route': const QuizGame(),
      },
      {
        'title': 'Matching',
        'icon': Icons.join_inner,
        'color': Colors.orange,
        'description': 'Match English and Uzbek words pairs',
        'route': const MatchingGame(),
      },
      {
        'title': 'Memory',
        'icon': Icons.grid_view,
        'color': Colors.purple,
        'description': 'Find matching pairs in a grid',
        'route': const MemoryGame(),
      },
      {
        'title': 'Fill in the Blank',
        'icon': Icons.keyboard,
        'color': Colors.red,
        'description': 'Type the missing translated letters',
        'route': const FillBlankGame(),
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a Game', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: games.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final game = games[index];
          return Card(
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => game['route'] as Widget),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Hero(
                      tag: 'game_icon_$index',
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (game['color'] as Color).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          game['icon'] as IconData,
                          size: 32,
                          color: game['color'] as Color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            game['title'] as String,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            game['description'] as String,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
