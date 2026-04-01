import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../providers/profile_provider.dart';
import '../services/class_service.dart';
import '../services/sync_service.dart';
import '../services/xp_service.dart';
import '../widgets/xp_bar_widget.dart';
import '../widgets/streak_widget.dart';
import 'onboarding/welcome_screen.dart';
import 'teacher_dashboard_screen.dart';

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
    final streakDays =
        profile?.streakDays ?? profileBox.get('streakDays', defaultValue: 0) as int;
    final classCode = profile?.classCode ?? profileBox.get('classCode') as String?;
    final totalAnswered = profile?.totalWordsAnswered ??
        profileBox.get('totalWordsAnswered', defaultValue: 0) as int;
    final totalCorrect = profile?.totalCorrect ??
        profileBox.get('totalCorrect', defaultValue: 0) as int;
    final accuracy =
        totalAnswered > 0 ? (totalCorrect / totalAnswered * 100).round() : 0;
    final isTeacher = profile?.isTeacher ??
        profileBox.get('isTeacher', defaultValue: false) as bool;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ─── Avatar & Username ──────────────────────────────
            CircleAvatar(
              radius: 48,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
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
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.edit, size: 20,
                      color: theme.colorScheme.primary),
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
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Class: $classCode',
                  style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // ─── XP Bar ─────────────────────────────────────────
            XpBarWidget(totalXp: xp),
            const SizedBox(height: 24),

            // ─── Streak ─────────────────────────────────────────
            StreakWidget(streakDays: streakDays),
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
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
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
            _ActionTile(
              icon: Icons.group_add,
              label: classCode != null && classCode.isNotEmpty
                  ? 'Change Class'
                  : 'Join a Class',
              subtitle: classCode != null && classCode.isNotEmpty
                  ? 'Currently in: $classCode'
                  : 'Enter your teacher\'s code',
              onTap: () => _showJoinClassDialog(context, ref),
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.school,
              label: 'Create a Class',
              subtitle: 'For teachers — get a code for your students',
              onTap: () => _showCreateClassDialog(context, ref, username),
            ),
            // Teacher Dashboard link (only visible for teachers with a class)
            if (isTeacher && classCode != null && classCode.isNotEmpty) ...[
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.dashboard,
                label: 'View Dashboard',
                subtitle: 'See student progress and stats',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeacherDashboardScreen(classCode: classCode),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // ─── Account Management ─────────────────────────────
            _SectionHeader(title: 'Account'),
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

  // ─── Join Class Dialog ────────────────────────────────────────────

  void _showJoinClassDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool joining = false;
        String? error;
        return StatefulBuilder(builder: (context, setDialogState) {
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

                        final profile = ref.read(profileProvider);
                        if (profile == null) return;

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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Joined ${classData['class_name']}! 🎉'),
                              ),
                            );
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
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Join'),
              ),
            ],
          );
        });
      },
    );
  }

  // ─── Create Class Dialog ──────────────────────────────────────────

  void _showCreateClassDialog(
      BuildContext context, WidgetRef ref, String teacherUsername) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool creating = false;
        String? generatedCode;
        return StatefulBuilder(builder: (context, setDialogState) {
          if (generatedCode != null) {
            // Show the generated code
            return AlertDialog(
              title: const Text('Class Created! 🎉'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Share this code with your students:'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      generatedCode!,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Students enter this code to join your class.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Done'),
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('Create a Class'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'You\'ll get a 6-character code to share with students.'),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Class name',
                    hintText: 'e.g. Class 7B — English',
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
                onPressed: creating
                    ? null
                    : () async {
                        final className = controller.text.trim();
                        if (className.isEmpty) return;

                        setDialogState(() => creating = true);

                        try {
                          final code = await ClassService.createClass(
                            teacherUsername: teacherUsername,
                            className: className,
                          );

                          // Mark as teacher
                          await ref
                              .read(profileProvider.notifier)
                              .setTeacher(true);

                          // Join own class
                          final profile = ref.read(profileProvider);
                          if (profile != null) {
                            await ClassService.joinClass(
                              profileId: profile.id,
                              code: code,
                            );
                            await ref
                                .read(profileProvider.notifier)
                                .setClassCode(code);
                          }

                          setDialogState(() => generatedCode = code);
                        } catch (e) {
                          setDialogState(() => creating = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                child: creating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Create'),
              ),
            ],
          );
        });
      },
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
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
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
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const WelcomeScreen()),
                                (route) => false,
                              );
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
