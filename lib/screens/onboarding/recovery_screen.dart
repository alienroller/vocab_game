import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/account_recovery_service.dart';
import '../home_screen.dart';

/// Account recovery screen — enter username + 6-digit PIN to restore account.
///
/// Rate limited: 3 wrong attempts → 60 second cooldown.
class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _errorMessage;
  Timer? _lockoutTimer;
  int _lockoutSeconds = 0;
  bool _obscurePin = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _pinController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _startLockoutTimer() {
    _lockoutSeconds = AccountRecoveryService.lockoutSecondsRemaining;
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _lockoutSeconds = AccountRecoveryService.lockoutSecondsRemaining;
          if (_lockoutSeconds <= 0) {
            timer.cancel();
            _errorMessage = null;
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _attemptRecovery() async {
    if (!_formKey.currentState!.validate()) return;

    // Check lockout
    if (AccountRecoveryService.isLockedOut) {
      _startLockoutTimer();
      setState(() {
        _errorMessage =
            'Too many attempts. Wait $_lockoutSeconds seconds.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final result = await AccountRecoveryService.recoverAccount(
      username: _usernameController.text.trim(),
      pin: _pinController.text.trim(),
    );

    if (!mounted) return;

    if (result != null) {
      // Success — go to home
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      setState(() {
        _loading = false;
        if (AccountRecoveryService.isLockedOut) {
          _startLockoutTimer();
          _errorMessage =
              'Too many wrong attempts. Please wait $_lockoutSeconds seconds.';
        } else {
          _errorMessage = 'Wrong username or PIN. Please try again.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLocked = _lockoutSeconds > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recover Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.restore,
                      size: 40,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Center(
                  child: Text(
                    'Welcome back!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Enter your username and 6-digit PIN\nto restore your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Username field
                Text('Username',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'Enter your username',
                    prefixIcon: const Icon(Icons.person_outline),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter your username' : null,
                ),
                const SizedBox(height: 20),

                // PIN field
                Text('Recovery PIN',
                    style: theme.textTheme.titleSmall?.copyWith(
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
                      return 'PIN must be 6 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Error message
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Recover button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: (_loading || isLocked) ? null : _attemptRecovery,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            isLocked
                                ? 'Wait $_lockoutSeconds seconds...'
                                : 'Restore My Account',
                            style: const TextStyle(fontSize: 18),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Help text
                Center(
                  child: Text(
                    'Forgot your PIN? Ask your teacher to reset it.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
