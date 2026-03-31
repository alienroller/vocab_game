import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../providers/profile_provider.dart';
import '../../services/notification_service.dart';
import '../../services/sync_service.dart';
import 'join_class_screen.dart';

/// Username selection screen during onboarding.
///
/// Real-time uniqueness check (debounced 600ms). Creates a Supabase profile
/// and local Hive profile on submit.
class UsernameScreen extends ConsumerStatefulWidget {
  const UsernameScreen({super.key});

  @override
  ConsumerState<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends ConsumerState<UsernameScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Timer? _debounce;
  bool _checking = false;
  bool? _isAvailable;
  bool _submitting = false;

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

    try {
      final username = _controller.text.trim();
      final userId = const Uuid().v4();

      // Create profile in Supabase
      await Supabase.instance.client.from('profiles').insert({
        'id': userId,
        'username': username,
        'xp': 0,
        'level': 1,
        'streak_days': 0,
      });

      // Create local profile
      await ref
          .read(profileProvider.notifier)
          .createProfile(id: userId, username: username);

      // Request notification permission (iOS + Android 13+)
      await NotificationService.requestPermission();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const JoinClassScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating profile: $e')),
        );
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final username = _controller.text.trim();
    final isValid = username.length >= 3 && _isAvailable == true;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                Text(
                  'Choose your\nusername',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This is how your classmates will see you on the leaderboard.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.none,
                  decoration: InputDecoration(
                    hintText: 'e.g. Sardor2010',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
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
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500),
                  ),
                if (_isAvailable == false)
                  Text(
                    '❌ Username is already taken',
                    style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500),
                  ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed:
                        isValid && !_submitting ? () => _submit() : null,
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
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Continue'),
                  ),
                ),
                const SizedBox(height: 48),
              ],
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
