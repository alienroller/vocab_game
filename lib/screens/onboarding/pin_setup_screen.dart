import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../services/account_recovery_service.dart';
import '../home_screen.dart';

/// PIN setup screen — shown during onboarding after username selection.
///
/// The user chooses a 6-digit PIN for account recovery.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
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

    final profileId = Hive.box('userProfile').get('id') as String;
    final success = await AccountRecoveryService.savePin(
      profileId: profileId,
      pin: _pinController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      // Mark onboarding as complete
      await Hive.box('userProfile').put('hasOnboarded', true);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save PIN. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Recovery PIN'),
      ),
      body: SafeArea(
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
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
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
                  child: FilledButton(
                    onPressed: _saving ? null : _savePin,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
