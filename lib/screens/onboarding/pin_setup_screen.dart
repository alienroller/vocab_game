import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../providers/profile_provider.dart';
import '../../services/notification_service.dart';
import '../../services/account_recovery_service.dart';
import '../../theme/app_theme.dart';

/// PIN setup screen — shown during onboarding after username selection.
///
/// The user chooses a 6-digit PIN for account recovery. Creates profile in Supabase and Hive.
class PinSetupScreen extends ConsumerStatefulWidget {
  final bool isTeacher;
  final String username;
  const PinSetupScreen({super.key, this.isTeacher = false, this.username = ''});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _obscurePin = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _savePin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final userId = const Uuid().v4();

      // Ensure profile doesn't already exist (someone else could have taken it in the meantime)
      // Attempt Supabase insert FIRST (authoritative uniqueness check)
      try {
        await Supabase.instance.client.from('profiles').insert({
          'id': userId,
          'username': widget.username,
          'xp': 0,
          'level': 1,
          'streak_days': 0,
          'is_teacher': widget.isTeacher,
          'week_xp': 0,
          'total_words_answered': 0,
          'total_correct': 0,
        });
      } on PostgrestException catch (e) {
        if (e.code == '23505') {
          if (mounted) {
            setState(() => _saving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Username was just taken by someone else. Please go back and choose another.'),
              ),
            );
          }
          return;
        }
        rethrow;
      }

      final success = await AccountRecoveryService.savePin(
        profileId: userId,
        pin: _pinController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        // Only create local profile AFTER Supabase confirms success
        await ref
            .read(profileProvider.notifier)
            .createProfile(id: userId, username: widget.username, isTeacher: widget.isTeacher);

        // Request notification permission (iOS + Android 13+)
        // await NotificationService.requestPermission(); TODO

        if (!mounted) return;

        if (widget.isTeacher) {
          context.push('/onboarding/teacher-class-setup');
        } else {
          context.push('/onboarding/join-class');
        }
      } else {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save PIN. Please try again.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating profile: $e')),
        );
        setState(() => _saving = false);
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
        title: const Text('Set Recovery PIN'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Explanation
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.amber.withValues(alpha: isDark ? 0.1 : 0.06),
                    borderRadius: AppTheme.borderRadiusSm,
                    border: Border.all(
                      color: AppTheme.amber.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.amber, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This PIN lets you recover your account if you reinstall the app. Write it down or remember it!',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // PIN field
                Text('Choose a 6-digit PIN',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: _obscurePin,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '••••••',
                    counterText: '',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePin
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscurePin = !_obscurePin),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length != 6) {
                      return 'PIN must be exactly 6 digits';
                    }
                    if (v == '000000' || v == '123456' || v == '111111') {
                      return 'Please choose a stronger PIN';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Confirm PIN field
                Text('Confirm PIN',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: _obscureConfirm,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '••••••',
                    counterText: '',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v != _pinController.text) {
                      return 'PINs do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Container(
                    decoration: !_saving
                        ? BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: AppTheme.borderRadiusMd,
                            boxShadow: AppTheme.shadowGlow(AppTheme.violet),
                          )
                        : null,
                    child: FilledButton(
                      onPressed: _saving ? null : _savePin,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            !_saving ? Colors.transparent : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.borderRadiusMd,
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save & Continue',
                              style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
