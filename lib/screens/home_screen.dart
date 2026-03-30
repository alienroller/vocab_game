import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../providers/profile_provider.dart';
import '../widgets/xp_bar_widget.dart';
import '../widgets/streak_widget.dart';
import '../models/vocab.dart';
import '../providers/vocab_provider.dart';
import '../widgets/vocab_tile.dart';
import 'game_selection_screen.dart';
import 'leaderboard_screen.dart';
import 'library/library_screen.dart';
import 'hall_of_fame_screen.dart';
import 'profile_screen.dart';

/// Home screen with XP bar, streak counter, vocabulary list, and navigation
/// to the competitive features (Library, Leaderboard, Hall of Fame, Profile).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _englishController = TextEditingController();
  final _uzbekController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _englishController.dispose();
    _uzbekController.dispose();
    super.dispose();
  }

  void _addWord() {
    if (_formKey.currentState!.validate()) {
      ref.read(vocabProvider.notifier).addVocab(
            _englishController.text,
            _uzbekController.text,
          );
      _englishController.clear();
      _uzbekController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  void _showEditDialog(Vocab vocab) {
    final engCtrl = TextEditingController(text: vocab.english);
    final uzCtrl = TextEditingController(text: vocab.uzbek);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Word'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: engCtrl,
              decoration: const InputDecoration(labelText: 'English'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: uzCtrl,
              decoration: const InputDecoration(labelText: 'Uzbek'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(vocabProvider.notifier).updateVocab(
                    vocab.id,
                    engCtrl.text,
                    uzCtrl.text,
                  );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vocabList = ref.watch(vocabProvider);
    final profile = ref.watch(profileProvider);
    final theme = Theme.of(context);
    final canPlay = vocabList.length >= 4;

    // Read profile data from Hive if provider hasn't loaded yet
    final profileBox = Hive.box('userProfile');
    final xp = profile?.xp ?? profileBox.get('xp', defaultValue: 0) as int;
    final streakDays =
        profile?.streakDays ?? profileBox.get('streakDays', defaultValue: 0) as int;
    final username =
        profile?.username ?? profileBox.get('username', defaultValue: '') as String;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VocabGame',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Profile button
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Stats Bar (XP + Streak) ─────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
            ),
            child: Column(
              children: [
                // Username + Streak row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (username.isNotEmpty)
                      Text(
                        'Hi, $username! 👋',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    StreakWidget(streakDays: streakDays),
                  ],
                ),
                const SizedBox(height: 10),
                // XP Bar
                XpBarWidget(totalXp: xp),
              ],
            ),
          ),

          // ─── Quick Actions (Library, Leaderboard, Hall) ──────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _QuickAction(
                  icon: Icons.library_books,
                  label: 'Library',
                  color: Colors.indigo,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LibraryScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                _QuickAction(
                  icon: Icons.leaderboard,
                  label: 'Ranks',
                  color: Colors.amber.shade700,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LeaderboardScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                _QuickAction(
                  icon: Icons.emoji_events,
                  label: 'Fame',
                  color: Colors.orange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const HallOfFameScreen()),
                  ),
                ),
              ],
            ),
          ),

          // ─── Add Word Form ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Form(
              key: _formKey,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _englishController,
                          decoration: InputDecoration(
                            hintText: 'English word',
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _uzbekController,
                          decoration: InputDecoration(
                            hintText: 'Uzbek translation',
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                          onFieldSubmitted: (_) => _addWord(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _addWord,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 104,
                      width: 64,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.add,
                        color: theme.colorScheme.onPrimary,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── List Title ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16.0).copyWith(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Vocabulary',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${vocabList.length} words',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // ─── Vocab List ─────────────────────────────────────
          Expanded(
            child: vocabList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          size: 64,
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        const SizedBox(height: 16),
                        Text('No vocabulary yet.',
                            style: theme.textTheme.titleMedium),
                        Text(
                          'Add words to start playing games!',
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: vocabList.length,
                    itemBuilder: (context, index) {
                      final vocab = vocabList[index];
                      return VocabTile(
                        key: ValueKey(vocab.id),
                        vocab: vocab,
                        onDelete: () {
                          ref
                              .read(vocabProvider.notifier)
                              .deleteVocab(vocab.id);
                        },
                        onEdit: () => _showEditDialog(vocab),
                      );
                    },
                  ),
          ),

          // ─── Progress bar (< 4 words) ──────────────────────
          if (!canPlay)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: vocabList.length / 4,
                    borderRadius: BorderRadius.circular(8),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add ${4 - vocabList.length} more words to play games',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: canPlay
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const GameSelectionScreen()),
                );
              },
              icon: const Icon(Icons.gamepad),
              label: const Text('Start Games',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ─── Quick Action Button ──────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
