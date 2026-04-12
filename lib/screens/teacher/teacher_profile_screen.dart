import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/profile_provider.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';

class TeacherProfileScreen extends ConsumerWidget {
  const TeacherProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isDark = Theme.of(context).brightness == Brightness.dark;

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

            // 2. Class info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D3A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  const Text('Class Code', style: TextStyle(color: AppTheme.textSecondaryLight)),
                  const SizedBox(height: 8),
                  Text(
                    profile.classCode ?? 'No Class',
                    style: const TextStyle(fontSize: 32, letterSpacing: 4, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy'),
                        onPressed: () {
                          if (profile.classCode != null) {
                            Clipboard.setData(ClipboardData(text: profile.classCode!));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Share'),
                        onPressed: () {
                          if (profile.classCode != null) {
                            Share.share('Join my class on VocabGame! Code: ${profile.classCode}');
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 3. Account section
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.violet),
              title: const Text('Change Username'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showChangeUsernameDialog(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.password, color: AppTheme.violet),
              title: const Text('Recovery PIN'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/onboarding/pin', extra: true),
            ),
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
