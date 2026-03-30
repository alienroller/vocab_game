import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles account recovery via username + 6-digit PIN.
///
/// The PIN is hashed (SHA-256) before storage — never stored as plain text.
/// Rate limits: 3 failed attempts → 60 second cooldown.
class AccountRecoveryService {
  static final _supabase = Supabase.instance.client;

  // ─── Rate Limiting ──────────────────────────────────────────────
  static int _failedAttempts = 0;
  static DateTime? _lockoutUntil;

  /// Checks if recovery attempts are currently locked out.
  static bool get isLockedOut {
    if (_lockoutUntil == null) return false;
    if (DateTime.now().isAfter(_lockoutUntil!)) {
      _failedAttempts = 0;
      _lockoutUntil = null;
      return false;
    }
    return true;
  }

  /// Returns seconds remaining in lockout, or 0 if not locked.
  static int get lockoutSecondsRemaining {
    if (_lockoutUntil == null) return 0;
    final remaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  // ─── PIN Hashing ────────────────────────────────────────────────

  /// Hashes a 6-digit PIN using SHA-256.
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin.trim());
    return sha256.convert(bytes).toString();
  }

  // ─── Registration ───────────────────────────────────────────────

  /// Saves the PIN hash to Supabase during onboarding.
  /// Call this AFTER the profile has been created in Supabase.
  static Future<bool> savePin({
    required String profileId,
    required String pin,
  }) async {
    try {
      final hash = hashPin(pin);
      await _supabase
          .from('profiles')
          .update({'pin_hash': hash}).eq('id', profileId);

      // Also save locally so we can show "change PIN" later
      Hive.box('userProfile').put('pinHash', hash);
      return true;
    } catch (e) {
      debugPrint('Save PIN failed: $e');
      return false;
    }
  }

  // ─── Recovery ───────────────────────────────────────────────────

  /// Attempts to recover an account by username + PIN.
  ///
  /// Returns the full profile map on success, null on failure.
  /// Enforces rate limiting (3 attempts → 60s lockout).
  static Future<Map<String, dynamic>?> recoverAccount({
    required String username,
    required String pin,
  }) async {
    // Check lockout
    if (isLockedOut) return null;

    try {
      final hash = hashPin(pin);

      // Look up profile by username (case-insensitive)
      final result = await _supabase
          .from('profiles')
          .select()
          .ilike('username', username.trim())
          .eq('pin_hash', hash)
          .maybeSingle();

      if (result == null) {
        // Wrong credentials
        _failedAttempts++;
        if (_failedAttempts >= 3) {
          _lockoutUntil = DateTime.now().add(const Duration(seconds: 60));
        }
        return null;
      }

      // Success — reset rate limiter
      _failedAttempts = 0;
      _lockoutUntil = null;

      // Restore profile to Hive
      await _restoreToHive(result);

      return result;
    } catch (e) {
      debugPrint('Account recovery failed: $e');
      return null;
    }
  }

  /// Restores a Supabase profile into the local Hive box.
  static Future<void> _restoreToHive(Map<String, dynamic> profile) async {
    final box = Hive.box('userProfile');
    await box.put('id', profile['id']);
    await box.put('username', profile['username']);
    await box.put('xp', profile['xp'] ?? 0);
    await box.put('level', profile['level'] ?? 1);
    await box.put('streakDays', profile['streak_days'] ?? 0);
    await box.put('lastPlayedDate', profile['last_played_date']);
    await box.put('classCode', profile['class_code']);
    await box.put('weekXp', profile['week_xp'] ?? 0);
    await box.put('totalWordsAnswered', profile['total_words_answered'] ?? 0);
    await box.put('totalCorrect', profile['total_correct'] ?? 0);
    await box.put('pinHash', profile['pin_hash']);
    await box.put('hasOnboarded', true);
  }

  // ─── PIN Change ─────────────────────────────────────────────────

  /// Changes the PIN for the current user. Requires the old PIN for verification.
  static Future<bool> changePin({
    required String profileId,
    required String oldPin,
    required String newPin,
  }) async {
    try {
      final oldHash = hashPin(oldPin);
      final storedHash =
          Hive.box('userProfile').get('pinHash') as String?;

      if (storedHash != oldHash) return false; // wrong old PIN

      return await savePin(profileId: profileId, pin: newPin);
    } catch (e) {
      debugPrint('Change PIN failed: $e');
      return false;
    }
  }
}
