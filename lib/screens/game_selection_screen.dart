import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/vocab_provider.dart';
import '../theme/app_theme.dart';

class GameSelectionScreen extends ConsumerWidget {
  const GameSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabList = ref.watch(vocabProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (vocabList.length < 4) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient:
                isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        AppTheme.violet.withValues(alpha: isDark ? 0.1 : 0.06),
                  ),
                  child: Icon(Icons.lock_rounded,
                      size: 48, color: AppTheme.violet.withValues(alpha: 0.5)),
                ),
                const SizedBox(height: 20),
                Text('Need at least 4 words',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Add more vocabulary from the Home tab!',
                    style: TextStyle(
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight)),
              ],
            ),
          ),
        ),
      );
    }

    final games = [
      _GameData(
        title: 'Flashcards',
        icon: Icons.style_rounded,
        emoji: '🃏',
        description: 'Flip cards to memorize vocabulary',
        route: '/games/flashcard',
        gradient: const [Color(0xFF4FC3F7), Color(0xFF0288D1)],
      ),
      _GameData(
        title: 'Quiz',
        icon: Icons.quiz_rounded,
        emoji: '🧠',
        description: 'Test your knowledge with multiple choice',
        route: '/games/quiz',
        gradient: const [Color(0xFF66BB6A), Color(0xFF2E7D32)],
      ),
      _GameData(
        title: 'Matching',
        icon: Icons.join_inner_rounded,
        emoji: '🔗',
        description: 'Match English and Uzbek word pairs',
        route: '/games/matching',
        gradient: const [Color(0xFFFFB74D), Color(0xFFE65100)],
      ),
      _GameData(
        title: 'Memory',
        icon: Icons.grid_view_rounded,
        emoji: '🧩',
        description: 'Find matching pairs in a grid',
        route: '/games/memory',
        gradient: const [Color(0xFFCE93D8), Color(0xFF7B1FA2)],
      ),
      _GameData(
        title: 'Fill in Blank',
        icon: Icons.keyboard_rounded,
        emoji: '✏️',
        description: 'Type the missing translated letters',
        route: '/games/fill-blank',
        gradient: const [Color(0xFFEF5350), Color(0xFFC62828)],
      ),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Choose a Game',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient:
              isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: games.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final game = games[index];
              return _GameCard(game: game, isDark: isDark, index: index);
            },
          ),
        ),
      ),
    );
  }
}

class _GameData {
  final String title;
  final IconData icon;
  final String emoji;
  final String description;
  final String route;
  final List<Color> gradient;

  const _GameData({
    required this.title,
    required this.icon,
    required this.emoji,
    required this.description,
    required this.route,
    required this.gradient,
  });
}

class _GameCard extends StatefulWidget {
  final _GameData game;
  final bool isDark;
  final int index;

  const _GameCard({
    required this.game,
    required this.isDark,
    required this.index,
  });

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final game = widget.game;

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          context.push(game.route);
        },
        onTapCancel: () => _ctrl.reverse(),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: widget.isDark
                ? AppTheme.darkGlassGradient
                : AppTheme.lightGlassGradient,
            borderRadius: AppTheme.borderRadiusLg,
            border: Border.all(
              color: widget.isDark
                  ? game.gradient.first.withValues(alpha: 0.2)
                  : game.gradient.first.withValues(alpha: 0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: game.gradient.first.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon with gradient background
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: game.gradient,
                  ),
                  borderRadius: AppTheme.borderRadiusMd,
                  boxShadow: [
                    BoxShadow(
                      color: game.gradient.first.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(game.emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      game.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: game.gradient.first.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: game.gradient.first,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
