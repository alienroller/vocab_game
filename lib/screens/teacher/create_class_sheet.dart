import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/class_students_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/teacher_classes_provider.dart';
import '../../services/class_service.dart';
import '../../theme/app_theme.dart';

/// Opens a bottom sheet that lets a teacher create a new class after
/// onboarding. Keeps the existing onboarding flow untouched.
///
/// Returns the newly-created class code, or null if cancelled.
Future<String?> showCreateClassSheet(BuildContext context) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _CreateClassSheet(),
  );
}

class _CreateClassSheet extends ConsumerStatefulWidget {
  const _CreateClassSheet();

  @override
  ConsumerState<_CreateClassSheet> createState() => _CreateClassSheetState();
}

class _CreateClassSheetState extends ConsumerState<_CreateClassSheet> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _creating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = ref.read(profileProvider);
    if (profile == null) return;

    setState(() => _creating = true);
    try {
      final className = _controller.text.trim();
      final code = await ClassService.createClass(
        teacherId: profile.id,
        teacherUsername: profile.username,
        className: className,
      );

      // Switch the active class to the new one — dashboard/analytics/etc.
      // will react to profile.classCode changing.
      await ref.read(profileProvider.notifier).setClassCode(code);

      // Refresh the classes list and the students for the new active class.
      await ref.read(teacherClassesProvider.notifier).load(profile.id);
      await ref.read(classStudentsProvider.notifier).load(
        classCode: code,
        teacherId: profile.id,
      );

      if (!mounted) return;
      Navigator.of(context).pop(code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Class "$className" created — code $code')),
      );
    } on ClassLimitReachedException catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You can own at most ${e.limit} classes.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create class: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text(
                'Create New Class',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              maxLength: 50,
              enabled: !_creating,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'e.g. Class 7B — English',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: AppTheme.borderRadiusMd,
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 3) {
                  return 'Please enter at least 3 characters.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _creating ? null : _submit(),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _creating ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _creating ? null : _submit,
                  child: _creating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
