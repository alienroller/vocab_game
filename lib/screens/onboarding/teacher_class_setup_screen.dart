import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../providers/profile_provider.dart';
import '../../services/class_service.dart';
import '../../theme/app_theme.dart';

class TeacherClassSetupScreen extends ConsumerStatefulWidget {
  const TeacherClassSetupScreen({super.key});

  @override
  ConsumerState<TeacherClassSetupScreen> createState() =>
      _TeacherClassSetupScreenState();
}

class _TeacherClassSetupScreenState
    extends ConsumerState<TeacherClassSetupScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _creating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _createClass() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _creating = true);

    try {
      final profile = ref.read(profileProvider);
      if (profile == null) throw Exception('Profile not found.');

      final className = _controller.text.trim();

      final classCode = await ClassService.createClass(
        teacherUsername: profile.username,
        className: className,
        teacherId: profile.id,
      );

      // Update profile
      await ref.read(profileProvider.notifier).setClassCode(classCode);
      
      // Mark as onboarded
      await Hive.box('userProfile').put('hasOnboarded', true);

      if (mounted) {
        context.push('/onboarding/class-code-reveal', extra: {
          'classCode': classCode,
          'className': className,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create class: $e')),
        );
        setState(() => _creating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Setup'),
        leading: const SizedBox.shrink(), // No back button
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Progress indicator 4 of 4
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDot(true),
                      _buildDot(true),
                      _buildDot(true),
                      _buildDot(true), // This is step 4
                    ],
                  ),
                  const SizedBox(height: 48),
                  const Center(
                    child: Text('🏫', style: TextStyle(fontSize: 80)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Set up your class',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Give your class a name. Students will see this when they join.',
                    style: TextStyle(
                      color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 50,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Class 7B — English',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(20),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 3) {
                        return 'Please enter at least 3 characters.';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _createClass(),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Container(
                      decoration: !_creating
                          ? BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: AppTheme.borderRadiusMd,
                              boxShadow: AppTheme.shadowGlow(AppTheme.violet),
                            )
                          : null,
                      child: FilledButton(
                        onPressed: _creating ? null : _createClass,
                        style: FilledButton.styleFrom(
                          backgroundColor: !_creating ? Colors.transparent : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppTheme.borderRadiusMd,
                          ),
                        ),
                        child: _creating
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Create My Class →',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDot(bool active) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppTheme.violet : Colors.grey.withValues(alpha: 0.3),
      ),
    );
  }
}
