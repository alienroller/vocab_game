import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/profile_provider.dart';
import '../../providers/theme_mode_provider.dart';
import '../../services/sync_service.dart';
import '../../services/version_service.dart';
import '../../theme/app_theme.dart';

class TeacherProfileScreen extends ConsumerWidget {
  const TeacherProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Teacher identity card
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 48,
              backgroundColor: AppTheme.violet.withValues(alpha: 0.2),
              child: Text(
                profile.username.isNotEmpty ? profile.username[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.violet),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              profile.username,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.violet.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text('Teacher', style: TextStyle(color: AppTheme.violet, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 32),

            // 2. Account section
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.violet),
              title: const Text('Change Username'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showChangeUsernameDialog(context, ref),
            ),
            if (profile.classCode != null)
              ListTile(
                leading: const Icon(Icons.qr_code_2, color: AppTheme.violet),
                title: const Text('Share class code'),
                subtitle: Text(
                  profile.classCode!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy code',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: profile.classCode!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied!')),
                    );
                  },
                ),
                onTap: () => Share.share(
                  'Join my class on VocabGame! Code: ${profile.classCode}',
                ),
              ),

            const Divider(),

            // 3. App preferences
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'APP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            _ThemeTile(),
            ListTile(
              leading: const Icon(Icons.help_outline, color: AppTheme.violet),
              title: const Text('How students join'),
              subtitle: const Text(
                'Share your class code; students enter it on the welcome screen.',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('How students join'),
                  content: const Text(
                    '1. Share your class code with students.\n\n'
                    '2. On the welcome screen they tap "I have a class code" '
                    'and type it in.\n\n'
                    '3. Once joined, they see your pinned message, your '
                    'assignments, and the leaderboard for the class.\n\n'
                    'Students who lose access can rejoin any time with the '
                    'same code.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.grey),
              title: const Text('Version'),
              subtitle: Text(
                _versionLabel(),
                style: const TextStyle(fontSize: 12),
              ),
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.orange),
              title: const Text('Logout', style: TextStyle(color: Colors.orange)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to log out?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(profileProvider.notifier).logout();
                  if (context.mounted) context.go('/welcome');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: AppTheme.error),
              title: const Text('Delete Account', style: TextStyle(color: AppTheme.error)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Account'),
                    content: const Text('This action cannot be undone. All your data will be permanently deleted.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  final profile = ref.read(profileProvider);
                  if (profile == null) return;

                  // Step 1: Clean up class-related data in Supabase
                  if (profile.classCode != null) {
                    try {
                      // Deactivate all assignments for this class
                      await Supabase.instance.client
                          .from('assignments')
                          .update({'is_active': false})
                          .eq('class_code', profile.classCode!);

                      // Delete the class row
                      await Supabase.instance.client
                          .from('classes')
                          .delete()
                          .eq('code', profile.classCode!);

                      // Orphan students (set their class_code to null)
                      await Supabase.instance.client
                          .from('profiles')
                          .update({'class_code': null})
                          .eq('class_code', profile.classCode!)
                          .eq('is_teacher', false);
                    } catch (e) {
                      debugPrint('Teacher class cleanup error: $e');
                    }
                  }

                  // Step 2: Delete profile from Supabase (handles online/offline)
                  await SyncService.deleteProfile(profile.id);

                  // Step 3: Navigate away
                  if (context.mounted) context.go('/welcome');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _versionLabel() {
    final v = AppVersionInfo.instance.version;
    final b = AppVersionInfo.instance.buildNumber;
    if (v.isEmpty) return '—';
    return b.isEmpty ? v : '$v ($b)';
  }

  void _showChangeUsernameDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Username'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'New username'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.length < 3) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Username must be at least 3 characters.')),
                );
                return;
              }
              try {
                await ref.read(profileProvider.notifier).updateUsername(newName);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Username updated!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// ListTile that surfaces the persisted ThemeMode and lets the teacher
/// switch between system / light / dark. Stored via [themeModeProvider].
class _ThemeTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    String label;
    IconData icon;
    switch (mode) {
      case ThemeMode.light:
        label = 'Light';
        icon = Icons.light_mode_outlined;
        break;
      case ThemeMode.dark:
        label = 'Dark';
        icon = Icons.dark_mode_outlined;
        break;
      case ThemeMode.system:
        label = 'System default';
        icon = Icons.brightness_auto_outlined;
        break;
    }

    return ListTile(
      leading: Icon(icon, color: AppTheme.violet),
      title: const Text('Theme'),
      subtitle: Text(label, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final picked = await showModalBottomSheet<ThemeMode>(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (sheetCtx) => SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Theme',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                for (final option in const [
                  (ThemeMode.system, 'System default',
                      Icons.brightness_auto_outlined),
                  (ThemeMode.light, 'Light', Icons.light_mode_outlined),
                  (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
                ])
                  RadioListTile<ThemeMode>(
                    value: option.$1,
                    groupValue: mode,
                    onChanged: (v) => Navigator.pop(sheetCtx, v),
                    title: Row(
                      children: [
                        Icon(option.$3, size: 18),
                        const SizedBox(width: 10),
                        Text(option.$2),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
        if (picked != null) {
          await ref.read(themeModeProvider.notifier).setMode(picked);
        }
      },
    );
  }
}
