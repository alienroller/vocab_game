import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/profile_provider.dart';
import 'pin_setup_screen.dart';

/// Optional class join screen during onboarding.
///
/// Student enters a 6-character code from their teacher.
/// Can be skipped — goes directly to the home screen.
class JoinClassScreen extends ConsumerStatefulWidget {
  const JoinClassScreen({super.key});

  @override
  ConsumerState<JoinClassScreen> createState() => _JoinClassScreenState();
}

class _JoinClassScreenState extends ConsumerState<JoinClassScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;
  String? _className;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _joinClass() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Code must be 6 characters');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;

      // Verify the code exists
      final classData = await supabase
          .from('classes')
          .select()
          .eq('code', code)
          .maybeSingle();

      if (classData == null) {
        setState(() {
          _errorMessage = 'Invalid class code. Check with your teacher.';
          _submitting = false;
        });
        return;
      }

      // Update profile with class code
      final profile = ref.read(profileProvider);
      if (profile != null) {
        await supabase
            .from('profiles')
            .update({'class_code': code}).eq('id', profile.id);
        await ref.read(profileProvider.notifier).setClassCode(code);
      }

      setState(() {
        _className = classData['class_name'] as String;
      });

      // Short delay to show success, then navigate
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PinSetupScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Connection error. Try again.';
          _submitting = false;
        });
      }
    }
  }

  void _skip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              Text(
                'Join a class',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Do you have a class code from your teacher?',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 40),
              if (_className != null)
                // Success state
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Welcome to $_className!',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You\'re in. Let\'s go! 🚀',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ENG7B',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.4),
                      letterSpacing: 8,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 24),
                    errorText: _errorMessage,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _submitting ? null : _joinClass,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Join'),
                  ),
                ),
              ],
              const Spacer(),
              if (_className == null)
                Center(
                  child: TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Skip for now',
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
