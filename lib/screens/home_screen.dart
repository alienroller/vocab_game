import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/profile_provider.dart';
import '../providers/vocab_provider.dart';
import '../models/vocab.dart';
import '../theme/app_theme.dart';
import '../widgets/xp_bar_widget.dart';
import '../widgets/streak_widget.dart';
import '../widgets/vocab_tile.dart';

/// Home screen with premium gradient design, hero header, vocabulary list,
/// and floating add-word bottom sheet.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  String? _rivalName;
  int _rivalXp = 0; // store rival's actual XP, calculate gap live in build()

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchRival();
    _checkStreakMilestone();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchRival(); // re-fetch rival when returning from a game
    }
  }

  void _checkStreakMilestone() {
    final profileBox = Hive.box('userProfile');
    final streakDays = profileBox.get('streakDays', defaultValue: 0) as int;
    final lastMilestone =
        profileBox.get('lastStreakMilestone', defaultValue: 0) as int;

    const milestones = [30, 14, 7, 3];
    for (final milestone in milestones) {
      if (streakDays >= milestone && lastMilestone < milestone) {
        profileBox.put('lastStreakMilestone', milestone);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => _StreakMilestoneDialog(
                milestone: milestone,
                currentStreak: streakDays,
              ),
            );
          }
        });
        break;
      }
    }
  }

  void _fetchRival() async {
    final profileBox = Hive.box('userProfile');
    final classCode = profileBox.get('classCode') as String?;
    final myUsername = profileBox.get('username') as String?;
    if (classCode == null || classCode.isEmpty || myUsername == null) return;

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('username, xp')
          .eq('class_code', classCode)
          .order('xp', ascending: false)
          .limit(50);

      final list = List<Map<String, dynamic>>.from(data);

      // Remove self from the list
      final others = list.where((e) => e['username'] != myUsername).toList();
      if (others.isEmpty) return;

      // Use local XP to determine who the closest rival above us is
      final myXp = profileBox.get('xp', defaultValue: 0) as int;

      // Find the person directly above us (closest rival with higher XP)
      Map<String, dynamic>? rivalAbove;
      for (final person in others.reversed) {
        final theirXp = person['xp'] as int? ?? 0;
        if (theirXp > myXp) {
          rivalAbove = person;
          break;
        }
      }

      if (rivalAbove != null && mounted) {
        setState(() {
          _rivalName = rivalAbove!['username'] as String?;
          _rivalXp = rivalAbove['xp'] as int? ?? 0;
        });
      } else if (mounted) {
        // User is #1 — show the person just below as "chasing you"
        final closestBelow = others.firstWhere(
          (e) => (e['xp'] as int? ?? 0) <= myXp,
          orElse: () => others.first,
        );
        setState(() {
          _rivalName = closestBelow['username'] as String?;
          _rivalXp = closestBelow['xp'] as int? ?? 0;
        });
      }
    } catch (_) {}
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
              decoration: const InputDecoration(hintText: 'English'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: uzCtrl,
              decoration: const InputDecoration(hintText: 'Uzbek'),
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
    final isDark = theme.brightness == Brightness.dark;
    final canPlay = vocabList.length >= 4;

    final profileBox = Hive.box('userProfile');
    final xp = profile?.xp ?? profileBox.get('xp', defaultValue: 0) as int;

    // The rival gap is computed LIVE below using _rivalXp - xp,
    // so it updates instantly when profile XP changes via ref.watch.

    final streakDays = profile?.streakDays ??
        profileBox.get('streakDays', defaultValue: 0) as int;
    final username = profile?.username ??
        profileBox.get('username', defaultValue: '') as String;
    final lastPlayed =
        profile?.lastPlayedDate ?? profileBox.get('lastPlayedDate') as String?;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final needsToPlayToday = streakDays > 0 && lastPlayed != today;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('🧠', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 10),
            Text('VocabGame',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                )),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ─── Hero Header ────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.glassCard(isDark: isDark),
                child: Column(
                  children: [
                    // Username + Streak row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (username.isNotEmpty)
                          Row(
                            children: [
                              // Avatar
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppTheme.primaryGradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.violet
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  username[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Hi, $username! 👋',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        StreakWidget(streakDays: streakDays),
                      ],
                    ),
                    const SizedBox(height: 14),
                    XpBarWidget(totalXp: xp),
                  ],
                ),
              ),

              // ─── Play Today Banner ──────────────────────────────
              if (needsToPlayToday)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.fire.withValues(alpha: isDark ? 0.15 : 0.1),
                        AppTheme.amber.withValues(alpha: isDark ? 0.1 : 0.06),
                      ],
                    ),
                    borderRadius: AppTheme.borderRadiusMd,
                    border: Border.all(
                      color: AppTheme.fire.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Play today to keep your $streakDays-day streak alive!',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.fire,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ─── Rival Card ─────────────────────────────────────
              if (_rivalName != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.error.withValues(alpha: isDark ? 0.12 : 0.08),
                        AppTheme.violet.withValues(alpha: isDark ? 0.08 : 0.04),
                      ],
                    ),
                    borderRadius: AppTheme.borderRadiusMd,
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('⚔️', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: 'Your rival: ',
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.textSecondaryDark
                                    : AppTheme.textSecondaryLight,
                                fontSize: 13,
                              ),
                            ),
                            TextSpan(
                              text: _rivalName,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.error,
                                fontSize: 13,
                              ),
                            ),
                            TextSpan(
                              text: () {
                                final gap = _rivalXp - xp;
                                if (gap > 0) return ' — $gap XP ahead';
                                if (gap == 0) return ' — tied!';
                                return ' — you lead by ${gap.abs()} XP 🔥';
                              }(),
                              style: TextStyle(
                                color: (_rivalXp - xp) > 0
                                    ? (isDark
                                        ? AppTheme.textSecondaryDark
                                        : AppTheme.textSecondaryLight)
                                    : AppTheme.success,
                                fontWeight:
                                    (_rivalXp - xp) <= 0 ? FontWeight.w600 : null,
                                fontSize: 13,
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),

              // ─── Quick Links Row ────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _QuickChip(
                      label: '🏆 Leaderboard',
                      onTap: () => context.push('/home/leaderboard'),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _QuickChip(
                      label: '📜 History',
                      onTap: () => context.push('/duels/history'),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _QuickChip(
                      label: '🏅 Hall of Fame',
                      onTap: () => context.push('/home/hall-of-fame'),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              // ─── Vocab List Header ──────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Vocabulary',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${vocabList.length} words',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.violet,
                            ),
                          ),
                        ),
                        if (canPlay) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => context.push('/home/games'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.violet.withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_arrow_rounded,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Practice',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
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
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.violet
                                    .withValues(alpha: isDark ? 0.1 : 0.06),
                              ),
                              child: Icon(
                                Icons.menu_book_rounded,
                                size: 56,
                                color: AppTheme.violet
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text('No vocabulary yet',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                )),
                            const SizedBox(height: 6),
                            Text(
                              'Tap the Search tab to add your first words!',
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.textSecondaryDark
                                    : AppTheme.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 8.0),
                  child: Column(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: vocabList.length / 4,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: AppTheme.primaryGradient,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add ${4 - vocabList.length} more words to play games',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.violet,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/search'),
        backgroundColor: AppTheme.violet,
        foregroundColor: Colors.white,
        elevation: 8,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}

// ─── Quick Chip ───────────────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _QuickChip({
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: AppTheme.borderRadiusSm,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Streak Milestone Celebration Dialog ──────────────────────────────

class _StreakMilestoneDialog extends StatefulWidget {
  final int milestone;
  final int currentStreak;
  const _StreakMilestoneDialog({
    required this.milestone,
    required this.currentStreak,
  });

  @override
  State<_StreakMilestoneDialog> createState() => _StreakMilestoneDialogState();
}

class _StreakMilestoneDialogState extends State<_StreakMilestoneDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (emoji, title, message) = switch (widget.milestone) {
      3 => ('🔥', 'You\'re on a roll!', '${widget.currentStreak}-day streak! Keep it up!'),
      7 => ('💪', 'One week strong!', 'You\'re a habit now. Incredible!'),
      14 => ('🏆', 'Two weeks!', 'You\'re in the top players. Amazing!'),
      30 => ('👑', 'One month!', 'You are LEGENDARY. Unstoppable!'),
      _ => ('🔥', 'Streak milestone!', '${widget.currentStreak}-day streak!'),
    };

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AlertDialog(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.violet,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.fire.withValues(alpha: 0.15),
                      AppTheme.amber.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: AppTheme.borderRadiusSm,
                  border: Border.all(
                    color: AppTheme.fire.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  '🔥 ${widget.currentStreak}-day streak',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.fire,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep Going! 💪',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
