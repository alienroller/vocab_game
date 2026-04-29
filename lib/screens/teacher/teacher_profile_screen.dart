import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/profile_provider.dart';
import '../../models/teacher_class.dart';
import '../../providers/teacher_classes_provider.dart';
import '../../providers/theme_mode_provider.dart';
import '../../services/sync_service.dart';
import '../../services/version_service.dart';
import '../../theme/app_theme.dart';

class TeacherProfileScreen extends ConsumerStatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  ConsumerState<TeacherProfileScreen> createState() =>
      _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends ConsumerState<TeacherProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = ref.read(profileProvider);
      if (p != null) ref.read(teacherClassesProvider.notifier).load(p.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final teacherClasses = ref.watch(teacherClassesProvider).classes;

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
            // BUG TP1 — multi-class teachers used to only see their *active*
            // class code. Now we list every class they own with a Copy + a
            // Share for each.
            if (teacherClasses.isEmpty && profile.classCode != null)
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
              )
            else
              for (final c in teacherClasses)
                ListTile(
                  leading: const Icon(Icons.qr_code_2, color: AppTheme.violet),
                  title: Text(c.className.isEmpty ? c.code : c.className),
                  subtitle: Text(
                    c.code,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Copy code',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: c.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Copied ${c.code}')),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.share, size: 18),
                        tooltip: 'Share invite',
                        onPressed: () => Share.share(
                          'Join my class "${c.className.isEmpty ? c.code : c.className}" '
                          'on VocabGame! Code: ${c.code}',
                        ),
                      ),
                    ],
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
            // BUG E4 — pick the grade-color band used in exam results.
            const _GradeBandTile(),
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
            // BUG O7 — let the teacher preview the student-side app
            // without uninstalling or using a second device.
            ListTile(
              leading: const Icon(Icons.visibility_outlined,
                  color: AppTheme.violet),
              title: const Text('Preview as student'),
              subtitle: const Text(
                'See what your students see. Tap "Exit preview" on the '
                'home banner to come back.',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Hive.box('userProfile').put('previewAsStudent', true);
                if (context.mounted) context.go('/home');
              },
            ),
            // BUG O5 — irreversible role flip kept teachers stuck if they
            // toggled by accident. Now safely allow becoming a student
            // (only when no classes are owned).
            _SwitchRoleTile(teacherClasses: teacherClasses),
            // BUG TP4 — surface a short FAQ so teachers can self-serve
            // common questions without contacting support.
            ListTile(
              leading: const Icon(Icons.menu_book_outlined,
                  color: AppTheme.violet),
              title: const Text('Teacher FAQ'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showFaq(context),
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
                  final p = ref.read(profileProvider);
                  if (p == null) return;

                  // BUG TP2 / TP3 — old code only cleaned up the *active*
                  // class and bypassed ClassService.deleteClass's safety
                  // checks. Multi-class teachers left 4 of 5 classes
                  // orphaned; class deletion bypassed
                  // ClassHasStudentsException entirely. Now we iterate
                  // over EVERY owned class and run a consistent cleanup.
                  final supa = Supabase.instance.client;
                  try {
                    final ownedRows = await supa
                        .from('classes')
                        .select('code')
                        .eq('teacher_id', p.id);
                    final codes = (ownedRows as List)
                        .map((r) => r['code'] as String)
                        .toList();
                    for (final code in codes) {
                      // Children first (no FK; mirror ClassService.deleteClass).
                      await supa
                          .from('teacher_messages')
                          .delete()
                          .eq('class_code', code);
                      await supa
                          .from('assignment_progress')
                          .delete()
                          .eq('class_code', code);
                      await supa
                          .from('assignments')
                          .delete()
                          .eq('class_code', code);
                      await supa
                          .from('word_stats')
                          .delete()
                          .eq('class_code', code);
                      await supa
                          .from('exam_sessions')
                          .delete()
                          .eq('class_code', code);
                      // Orphan students explicitly (account-deletion is the
                      // only path where this is OK — the teacher is exiting
                      // entirely; students keep their XP and streak).
                      await supa
                          .from('profiles')
                          .update({'class_code': null})
                          .eq('class_code', code)
                          .eq('is_teacher', false);
                      await supa
                          .from('classes')
                          .delete()
                          .eq('code', code)
                          .eq('teacher_id', p.id);
                    }
                  } catch (e) {
                    debugPrint('Teacher class cleanup error: $e');
                  }

                  await SyncService.deleteProfile(p.id);
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

/// Lets the teacher pick how strict the green/amber/red bands on exam
/// results render. Stored in the userProfile Hive box and read by
/// [AppTheme.gradeColor]. Default is 'lenient' (vocab-learning).
class _GradeBandTile extends StatefulWidget {
  const _GradeBandTile();

  @override
  State<_GradeBandTile> createState() => _GradeBandTileState();
}

class _GradeBandTileState extends State<_GradeBandTile> {
  String _band = 'lenient';

  @override
  void initState() {
    super.initState();
    final raw = Hive.box('userProfile').get('teacher_grade_band') as String?;
    _band = raw == 'strict' ? 'strict' : 'lenient';
  }

  @override
  Widget build(BuildContext context) {
    final label = _band == 'strict'
        ? 'Strict (US bands: 90 / 70 / 60)'
        : 'Lenient (vocab-learning: 70 / 55 / 40)';
    return ListTile(
      leading: const Icon(Icons.tune, color: AppTheme.violet),
      title: const Text('Grade colors'),
      subtitle: Text(label, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
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
                  'Grade color bands',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                RadioListTile<String>(
                  value: 'lenient',
                  groupValue: _band,
                  onChanged: (v) => Navigator.pop(sheetCtx, v),
                  title: const Text('Lenient (default)'),
                  subtitle: const Text(
                    '70 % green · 55 % amber · 40 % orange · below red.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                RadioListTile<String>(
                  value: 'strict',
                  groupValue: _band,
                  onChanged: (v) => Navigator.pop(sheetCtx, v),
                  title: const Text('Strict (US-style)'),
                  subtitle: const Text(
                    '90 % green · 70 % amber · 60 % orange · below red.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
        if (picked != null && picked != _band) {
          await Hive.box('userProfile').put('teacher_grade_band', picked);
          if (mounted) setState(() => _band = picked);
        }
      },
    );
  }
}

/// One-way "become a student" switch (BUG O5). Disabled until the
/// teacher owns zero classes — otherwise we'd orphan their classes
/// silently. Multi-class teachers see a hint to clean up first.
class _SwitchRoleTile extends ConsumerWidget {
  final List<TeacherClass> teacherClasses;
  const _SwitchRoleTile({required this.teacherClasses});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSwitch = teacherClasses.isEmpty;
    return ListTile(
      leading: Icon(
        Icons.swap_horiz,
        color: canSwitch ? AppTheme.violet : Colors.grey,
      ),
      title: Text(
        'Switch to student account',
        style: TextStyle(color: canSwitch ? null : Colors.grey),
      ),
      subtitle: Text(
        canSwitch
            ? 'You\'ll keep your XP and streak.'
            : 'Delete your ${teacherClasses.length} class'
                '${teacherClasses.length == 1 ? '' : 'es'} from My Classes first.',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: canSwitch ? const Icon(Icons.chevron_right) : null,
      enabled: canSwitch,
      onTap: !canSwitch
          ? null
          : () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Switch to student?'),
                  content: const Text(
                    'You\'ll lose access to all teacher features. '
                    'You can switch back later from the student profile.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Switch'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              final p = ref.read(profileProvider);
              if (p == null) return;
              try {
                await Supabase.instance.client
                    .from('profiles')
                    .update({'is_teacher': false})
                    .eq('id', p.id);
                await Hive.box('userProfile').put('isTeacher', false);
                await Hive.box('userProfile').delete('previewAsStudent');
                if (context.mounted) context.go('/home');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not switch: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
    );
  }
}

/// Short FAQ surfaced from the Profile screen (BUG TP4). Each row
/// expands inline to keep the list scannable.
void _showFaq(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Teacher FAQ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              ExpansionTile(
                title: Text('What does "at risk" mean?'),
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      'A student is at-risk if they\'ve never played and '
                      'their account is more than a day old, OR if their '
                      'last practice session was 3+ days ago. Brand-new '
                      'students get a one-day grace period so the dashboard '
                      'doesn\'t panic right after onboarding.',
                    ),
                  ),
                ],
              ),
              ExpansionTile(
                title: Text('How do students join my class?'),
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      '1. Share your class code from this screen.\n\n'
                      '2. Students tap "I have a class code" on the welcome '
                      'screen and type it in.\n\n'
                      '3. Once joined, they see your pinned message, your '
                      'assignments, and the leaderboard for the class.',
                    ),
                  ),
                ],
              ),
              ExpansionTile(
                title: Text('Can I delete a class with students enrolled?'),
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      'No — to protect student progress, you must remove '
                      'students from a class before deleting it. Each '
                      'student keeps their XP, streak, and word stats and '
                      'can rejoin a different class with that class\'s code.',
                    ),
                  ),
                ],
              ),
              ExpansionTile(
                title: Text('Can I post one exam to multiple classes?'),
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      'Yes — when creating an exam, tick every class you '
                      'want it posted to. Each class gets its own session '
                      'so scores don\'t mix.',
                    ),
                  ),
                ],
              ),
              ExpansionTile(
                title: Text('What if I forget my recovery PIN?'),
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      'Without the PIN, a reinstall will create a new '
                      'account. Your existing classes remain in the system '
                      'with codes intact, but you won\'t be able to manage '
                      'them. Write your PIN somewhere safe.',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
