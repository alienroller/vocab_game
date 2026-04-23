import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';

/// Username selection screen during onboarding.
///
/// Real-time uniqueness check (debounced 600ms). Profile creation
/// is deferred to PinSetupScreen when the PIN is chosen.
class UsernameScreen extends StatefulWidget {
  const UsernameScreen({super.key});

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Timer? _debounce;
  bool _checking = false;
  bool? _isAvailable;
  bool _submitting = false;
  bool _isTeacher = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    setState(() {
      _isAvailable = null;
      _checking = false;
    });

    final trimmed = value.trim();
    if (trimmed.length < 3) return;

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isAvailable != true) return;

    setState(() => _submitting = true);

    final username = _controller.text.trim();

    // Defer actual profile creation to the PIN screen
    if (mounted) {
      context.push('/onboarding/pin', extra: {
        'username': username,
        'isTeacher': _isTeacher,
      });
      // Reset _submitting flag in case the user navigates back
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final username = _controller.text.trim();
    final isValid = username.length >= 3 && _isAvailable == true;

    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
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
                  const SizedBox(height: 60),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: AppTheme.borderRadiusMd,
                    ),
                    child: const Icon(Icons.person_add_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Choose your\nusername',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This is how your classmates will see you on the leaderboard.',
                    style: TextStyle(
                      color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 36),
                  TextFormField(
                    controller: _controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.none,
                    decoration: InputDecoration(
                      hintText: 'e.g. Sardor2010',
                      suffixIcon: _buildSuffixIcon(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 3) {
                        return 'At least 3 characters';
                      }
                      if (v.trim().length > 20) {
                        return 'Max 20 characters';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                        return 'Letters, numbers, and underscores only';
                      }
                      return null;
                    },
                    onChanged: _onUsernameChanged,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  if (_isAvailable == true)
                    Text(
                      '✅ Username is available!',
                      style: TextStyle(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w600),
                    ),
                  if (_isAvailable == false)
                    Text(
                      '❌ Username is already taken',
                      style: TextStyle(
                          color: AppTheme.error,
                          fontWeight: FontWeight.w600),
                    ),
                  const SizedBox(height: 24),
                  // Teacher toggle
                  GestureDetector(
                    onTap: () => setState(() => _isTeacher = !_isTeacher),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _isTeacher
                            ? AppTheme.violet.withValues(alpha: isDark ? 0.15 : 0.08)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.black.withValues(alpha: 0.03)),
                        borderRadius: AppTheme.borderRadiusMd,
                        border: Border.all(
                          color: _isTeacher
                              ? AppTheme.violet.withValues(alpha: 0.4)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text('🎓', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'I am a teacher',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: _isTeacher
                                        ? AppTheme.violet
                                        : (isDark ? Colors.white70 : Colors.black54),
                                  ),
                                ),
                                Text(
                                  'Enable to create classes for your students',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 44,
                            height: 26,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              color: _isTeacher
                                  ? AppTheme.violet
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : Colors.black.withValues(alpha: 0.1)),
                            ),
                            child: AnimatedAlign(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              alignment: _isTeacher
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Container(
                      decoration: isValid && !_submitting
                          ? BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: AppTheme.borderRadiusMd,
                              boxShadow: AppTheme.shadowGlow(AppTheme.violet),
                            )
                          : null,
                      child: FilledButton(
                        onPressed:
                            isValid && !_submitting ? () => _submit() : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: isValid && !_submitting
                              ? Colors.transparent
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppTheme.borderRadiusMd,
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Continue'),
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

  Widget? _buildSuffixIcon() {
    if (_checking) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_isAvailable == true) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    if (_isAvailable == false) {
      return const Icon(Icons.cancel, color: Colors.red);
    }
    return null;
  }
}
