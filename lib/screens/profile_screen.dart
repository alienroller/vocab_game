import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/profile_provider.dart';
import '../providers/streak_provider.dart';
import '../services/class_service.dart';
import '../services/sync_service.dart';
import '../services/xp_service.dart';
import '../services/dictionary_service.dart';
import '../theme/app_theme.dart';
import '../widgets/xp_bar_widget.dart';
import '../widgets/streak_widget.dart';

/// User profile screen showing stats, XP details, streak, class info,
/// and account management (edit, join/create class, logout, delete).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final profileBox = Hive.box('userProfile');
    final theme = Theme.of(context);

    final username =
        profile?.username ?? profileBox.get('username', defaultValue: '') as String;
    final xp = profile?.xp ?? profileBox.get('xp', defaultValue: 0) as int;
    final level =
        profile?.level ?? profileBox.get('level', defaultValue: 1) as int;
    final streak = ref.watch(streakProvider);
    final classCode = profile?.classCode ?? profileBox.get('classCode') as String?;
    final totalAnswered = profile?.totalWordsAnswered ??
        profileBox.get('totalWordsAnswered', defaultValue: 0) as int;
    final totalCorrect = profile?.totalCorrect ??
        profileBox.get('totalCorrect', defaultValue: 0) as int;
    final accuracy =
        totalAnswered > 0 ? (totalCorrect / totalAnswered * 100).round() : 0;

    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Profile',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, kToolbarHeight + MediaQuery.of(context).padding.top + 16, 24, 24),
        child: Column(
          children: [
            // ─── Avatar & Username ──────────────────────────────
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
                boxShadow: AppTheme.shadowGlow(AppTheme.violet),
              ),
              alignment: Alignment.center,
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    username,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.edit_rounded, size: 20,
                      color: AppTheme.violet),
                  tooltip: 'Edit username',
                  onPressed: () => _showEditUsernameDialog(context, ref, username),
                ),
              ],
            ),
            if (classCode != null && classCode.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.violet.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Class: $classCode',
                  style: const TextStyle(
                    color: AppTheme.violet,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // ─── XP Bar ─────────────────────────────────────────
            XpBarWidget(totalXp: xp),
            const SizedBox(height: 24),

            // ─── Streak ─────────────────────────────────────────
            StreakWidget(snapshot: streak),
            if (streak.longest > streak.displayCount) ...[
              const SizedBox(height: 8),
              Text(
                'Personal best: ${streak.longest} days',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // ─── Stats Cards ────────────────────────────────────
            Row(
              children: [
                _StatCard(
                  icon: Icons.star,
                  label: 'Level',
                  value: '$level',
                  color: Colors.amber,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.bolt,
                  label: 'Total XP',
                  value: '$xp',
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatCard(
                  icon: Icons.check_circle,
                  label: 'Accuracy',
                  value: '$accuracy%',
                  color: Colors.green,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.quiz,
                  label: 'Answered',
                  value: '$totalAnswered',
                  color: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ─── XP Level Progress Details ──────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.glassCard(isDark: isDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level Progress',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                      'Current: Level $level (${XpService.xpRequiredForLevel(level)} XP)'),
                  Text(
                      'Next: Level ${level + 1} (${XpService.xpRequiredForLevel(level + 1)} XP)'),
                  Text(
                      'Remaining: ${XpService.xpNeededForNextLevel(xp) - XpService.xpProgressInLevel(xp)} XP'),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ─── Class Management ───────────────────────────────
            _SectionHeader(title: 'Class'),
            const SizedBox(height: 8),
            _ClassManagementSection(
              profile: profile,
              hasClass: classCode != null && classCode.isNotEmpty,
              classCode: classCode,
            ),
            const SizedBox(height: 32),

            // ─── Offline Dictionary ─────────────────────────────
            _SectionHeader(title: 'Offline Dictionary'),
            const SizedBox(height: 8),
            const _OfflineDictionarySection(),
            const SizedBox(height: 32),

            // ─── Account Management ─────────────────────────────
            _SectionHeader(title: 'Account'),
            const SizedBox(height: 8),
            // BUG O5 — symmetric "switch to teacher" path so a student
            // who picked the wrong role on day 1 isn't stuck.
            _ActionTile(
              icon: Icons.school_outlined,
              label: 'Become a teacher',
              subtitle: 'Get access to classes, assignments, and exams',
              onTap: () => _showSwitchToTeacherDialog(context, ref),
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.logout,
              label: 'Logout',
              subtitle: 'Sign out without deleting your data',
              onTap: () => _showLogoutDialog(context, ref),
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.delete_forever,
              label: 'Delete Account',
              subtitle: 'Permanently remove all your data',
              isDestructive: true,
              onTap: () => _showDeleteDialog(context, ref),
            ),
            const SizedBox(height: 48),
          ],
        ),
        ),
      ),
    );
  }

  // ─── Edit Username Dialog ─────────────────────────────────────────

  void _showEditUsernameDialog(
      BuildContext context, WidgetRef ref, String currentUsername) {
    showDialog(
      context: context,
      builder: (context) => _EditUsernameDialog(
        currentUsername: currentUsername,
        onSave: (newUsername) async {
          try {
            await ref.read(profileProvider.notifier).updateUsername(newUsername);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Username updated!')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update: $e')),
              );
            }
          }
        },
      ),
    );
  }

  // ─── Switch to teacher (BUG O5) ─────────────────────────────────

  void _showSwitchToTeacherDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Become a teacher?'),
        content: const Text(
          'You\'ll be able to create classes, post assignments, and run '
          'exams. We\'ll set up your first class right after.\n\n'
          'You\'ll keep your XP and streak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final p = ref.read(profileProvider);
              if (p == null) return;
              try {
                await Supabase.instance.client
                    .from('profiles')
                    .update({'is_teacher': true})
                    .eq('id', p.id);
                await Hive.box('userProfile').put('isTeacher', true);
                // If they had joined a class as a student, drop the
                // class_code so they don't appear in their own teacher
                // roster (would be confusing).
                await Hive.box('userProfile').delete('classCode');
                await Supabase.instance.client
                    .from('profiles')
                    .update({'class_code': null})
                    .eq('id', p.id);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (context.mounted) {
                  context.go('/onboarding/teacher-class-setup');
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('Could not switch: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Become a teacher'),
          ),
        ],
      ),
    );
  }

  // ─── Logout Dialog ────────────────────────────────────────────────

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'You will be signed out. Your data is saved — you can recover your account with your username and PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(profileProvider.notifier).logout();
              if (context.mounted) {
                context.go('/welcome');
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // ─── Delete Account Dialog ────────────────────────────────────────

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool deleting = false;
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Delete Account'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This will permanently delete all your data including XP, streaks, and duel history. This cannot be undone.',
                          style: TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Type DELETE to confirm:'),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'DELETE',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: deleting
                    ? null
                    : () async {
                        if (confirmController.text.trim() != 'DELETE') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Please type DELETE to confirm')),
                          );
                          return;
                        }

                        setDialogState(() => deleting = true);

                        final profile = ref.read(profileProvider);
                        if (profile != null) {
                          final success =
                              await SyncService.deleteProfile(profile.id);
                          if (success) {
                            await ref.read(profileProvider.notifier).logout();
                            if (context.mounted) {
                              context.go('/welcome');
                            }
                          } else {
                            setDialogState(() => deleting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Delete failed. Check your connection.')),
                              );
                            }
                          }
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: deleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Delete Forever'),
              ),
            ],
          );
        });
      },
    );
  }
}

// ─── Class Management Section ────────────────────────

/// Implements the correct button logic based on student state:
///   State A: student, no class → [Join a Class]
///   State B: student, has class → [Change Class], [Exit Class]
class _ClassManagementSection extends ConsumerStatefulWidget {
  final dynamic profile;
  final bool hasClass;
  final String? classCode;

  const _ClassManagementSection({
    required this.profile,
    required this.hasClass,
    this.classCode,
  });

  @override
  ConsumerState<_ClassManagementSection> createState() =>
      _ClassManagementSectionState();
}

class _ClassManagementSectionState
    extends ConsumerState<_ClassManagementSection> {
  bool _isLoading = false;
  final _classNameController = TextEditingController();

  @override
  void dispose() {
    _classNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;

    if (widget.hasClass) {
      // STATE B: Active student in a class
      return Column(
        children: [
          _ActionTile(
            icon: Icons.swap_horiz,
            label: 'Change Class',
            subtitle: 'Currently in: ${widget.classCode}',
            onTap: _isLoading
                ? () {}
                : () => _showChangeClassDialog(profile),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.exit_to_app,
            label: 'Exit Class',
            subtitle: 'Leave your current class',
            isDestructive: true,
            onTap: _isLoading ? () {} : () => _showExitClassDialog(profile),
          ),
        ],
      );
    }

    // STATE A: Student with no class
    return Column(
      children: [
        _ActionTile(
          icon: Icons.group_add,
          label: 'Join a Class',
          subtitle: 'Enter your teacher\'s code',
          onTap: _isLoading ? () {} : () => _showJoinClassDialog(profile),
        ),
      ],
    );
  }

  void _showJoinClassDialog(dynamic profile) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool joining = false;
        String? error;
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Join a Class'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter the 6-character code from your teacher.'),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ENG7B',
                    counterText: '',
                    errorText: error,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: joining
                    ? null
                    : () async {
                        final code = controller.text.trim().toUpperCase();
                        if (code.length != 6) {
                          setDialogState(
                              () => error = 'Code must be 6 characters');
                          return;
                        }
                        setDialogState(() {
                          joining = true;
                          error = null;
                        });
                        final classData = await ClassService.joinClass(
                          profileId: profile.id,
                          code: code,
                        );
                        if (classData != null) {
                          await ref
                              .read(profileProvider.notifier)
                              .setClassCode(code);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Joined ${classData['class_name']}! 🎉')),
                              );
                            }
                          }
                        } else {
                          setDialogState(() {
                            joining = false;
                            error = 'Invalid class code.';
                          });
                        }
                      },
                child: joining
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Join'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showChangeClassDialog(dynamic profile) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Class'),
        content: const Text(
          'You will leave your current class and join a new one.\n\n'
          'Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(profileProvider.notifier).setClassCode(null);
              if (context.mounted) {
                _showJoinClassDialog(profile);
              }
            },
            child: const Text('Change Class'),
          ),
        ],
      ),
    );
  }

  void _showExitClassDialog(dynamic profile) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit Class?'),
        content: const Text(
          'Are you sure you want to leave this class?\n\n'
          'You can rejoin later with the same code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(profileProvider.notifier).setClassCode(null);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Left the class.')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Exit Class'),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ─────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

// ─── Offline Dictionary Section ─────────────────────────────────────

class _OfflineDictionarySection extends StatefulWidget {
  const _OfflineDictionarySection();

  @override
  State<_OfflineDictionarySection> createState() => _OfflineDictionarySectionState();
}

class _OfflineDictionarySectionState extends State<_OfflineDictionarySection> {
  int _bundledCount = 0;
  int _cachedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    await dictionaryService.loadBundle();
    final bundled = dictionaryService.getBundledWordCount();
    final cached = await dictionaryService.getCachedWordCount();
    if (mounted) {
      setState(() {
        _bundledCount = bundled;
        _cachedCount = cached;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalOffline = _bundledCount + _cachedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  totalOffline > 0
                      ? '$totalOffline words available offline'
                      : 'Loading dictionary...',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Built-in dictionary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassCard(isDark: theme.brightness == Brightness.dark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.library_books, size: 28, color: AppTheme.violet),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Built-in Dictionary', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        Text(
                          '$_bundledCount words · Oxford CEFR',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Oxford curated dictionary with CEFR levels and definitions. Ships with the app — always available, no download needed.',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
              ),
              if (_cachedCount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.violet.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+ $_cachedCount extra words cached from searches',
                    style: const TextStyle(fontSize: 12, color: AppTheme.violet, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Info box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'All dictionary words are built into the app. Words you search online are also cached for offline use.',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Action Tile ────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive ? Colors.red : theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Card ──────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Edit Username Dialog ───────────────────────────────────────────

class _EditUsernameDialog extends StatefulWidget {
  final String currentUsername;
  final Future<void> Function(String) onSave;

  const _EditUsernameDialog({
    required this.currentUsername,
    required this.onSave,
  });

  @override
  State<_EditUsernameDialog> createState() => _EditUsernameDialogState();
}

class _EditUsernameDialogState extends State<_EditUsernameDialog> {
  late TextEditingController _controller;
  Timer? _debounce;
  bool _checking = false;
  bool? _isAvailable;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentUsername);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {
      _isAvailable = null;
      _checking = false;
    });

    final trimmed = value.trim();
    if (trimmed.length < 3 || trimmed == widget.currentUsername) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      setState(() => _checking = true);
      final taken = await SyncService.isUsernameTaken(trimmed);
      if (mounted) {
        setState(() {
          _isAvailable = !taken;
          _checking = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = _controller.text.trim();
    final unchanged = trimmed == widget.currentUsername;
    final canSave = !unchanged && trimmed.length >= 3 && _isAvailable == true;

    return AlertDialog(
      title: const Text('Edit Username'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            decoration: InputDecoration(
              labelText: 'Username',
              suffixIcon: _checking
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _isAvailable == true
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : _isAvailable == false
                          ? const Icon(Icons.cancel, color: Colors.red)
                          : null,
            ),
          ),
          const SizedBox(height: 8),
          if (_isAvailable == true)
            const Text('✅ Available!',
                style: TextStyle(color: Colors.green, fontSize: 13)),
          if (_isAvailable == false)
            const Text('❌ Already taken',
                style: TextStyle(color: Colors.red, fontSize: 13)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canSave && !_saving
              ? () async {
                  setState(() => _saving = true);
                  await widget.onSave(trimmed);
                  if (context.mounted) Navigator.pop(context);
                }
              : null,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
