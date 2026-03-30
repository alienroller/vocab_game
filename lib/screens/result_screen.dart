import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';

class ResultScreen extends StatelessWidget {
  final int score;
  final int total;
  final String gameName;
  final VoidCallback onPlayAgain;

  const ResultScreen({
    super.key,
    required this.score,
    required this.total,
    required this.gameName,
    required this.onPlayAgain,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSuccess = (score / total) >= 0.7;

    return Scaffold(
      appBar: AppBar(
        title: Text('$gameName Results'),
        automaticallyImplyLeading: false, // Force use of explicit buttons
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'game_icon',
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: (isSuccess ? Colors.green : Colors.orange).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSuccess ? Icons.emoji_events : Icons.thumb_up,
                    size: 64,
                    color: isSuccess ? Colors.green : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                isSuccess ? 'Great Job!' : 'Good Effort!',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'You scored:',
                style: theme.textTheme.titleMedium,
              ),
              Text(
                '$score / $total',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 48),
              CustomButton(
                text: 'Play Again',
                icon: Icons.replay,
                isFullWidth: true,
                onPressed: () {
                  Navigator.pop(context); // Pop result screen
                  onPlayAgain(); // Start game over
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Pop result screen
                  Navigator.pop(context); // Pop game screen
                },
                icon: const Icon(Icons.list),
                label: const Text('Back to Games'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
