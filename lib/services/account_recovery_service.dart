import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles account recovery via username + 6-digit PIN.
///
/// The PIN is salted with the user's profile ID and hashed (SHA-256)
/// before storage — never stored as plain text.
/// Rate limits: 3 failed attempts → 60 second cooldown.
///
/// Backward compatibility: existing unsalted (v1) hashes are accepted
/// during recovery and PIN change, then silently upgraded to salted (v2).
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

  /// Hashes a PIN using SHA-256 with the profile ID as a salt (v2).
  ///
  /// Salting ensures the same PIN produces different hashes for different
  /// users, making precomputed rainbow tables useless.
  static String _hashSalted(String pin, String profileId) {
    final bytes = utf8.encode('$profileId:${pin.trim()}');
    return sha256.convert(bytes).toString();
  }

  /// Legacy unsalted hash (v1) — used only for verifying old hashes
  /// during the migration period.
  static String _hashLegacy(String pin) {
    final bytes = utf8.encode(pin.trim());
    return sha256.convert(bytes).toString();
  }

  /// Verifies a PIN against a stored hash, supporting both v1 (unsalted)
  /// and v2 (salted) formats. Returns true if the PIN matches either format.
  static bool _verifyPin(String pin, String profileId, String storedHash) {
    // Try v2 (salted) first — the current format
    if (_hashSalted(pin, profileId) == storedHash) return true;

    // Fall back to v1 (legacy unsalted) for existing users
    if (_hashLegacy(pin) == storedHash) return true;

    return false;
  }

  /// Upgrades a v1 (unsalted) hash to v2 (salted) in both Supabase and Hive.
  /// Called silently after a successful v1 verification.
  static Future<void> _upgradeHashIfNeeded(
    String pin,
    String profileId,
    String storedHash,
  ) async {
    final saltedHash = _hashSalted(pin, profileId);

    // Already v2 — nothing to do
    if (storedHash == saltedHash) return;

    // The stored hash is v1 (legacy) — upgrade it
    try {
      await _supabase
          .from('profiles')
          .update({'pin_hash': saltedHash}).eq('id', profileId);
      Hive.box('userProfile').put('pinHash', saltedHash);
      debugPrint('PIN hash upgraded to salted format for profile $profileId');
    } catch (e) {
      debugPrint('PIN hash upgrade failed (non-critical): $e');
    }
  }

  // ─── Registration ───────────────────────────────────────────────

  /// Saves the PIN hash to Supabase during onboarding.
  /// Call this AFTER the profile has been created in Supabase.
  /// Always stores in v2 (salted) format.
  static Future<bool> savePin({
    required String profileId,
    required String pin,
  }) async {
    try {
      final hash = _hashSalted(pin, profileId);
      await _supabase
          .from('profiles')
          .update({'pin_hash': hash}).eq('id', profileId);

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
  ///
  /// Flow: look up by username first, then verify the salted PIN hash
  /// locally. Supports legacy unsalted hashes and auto-upgrades them.
  static Future<Map<String, dynamic>?> recoverAccount({
    required String username,
    required String pin,
  }) async {
    if (isLockedOut) return null;

    try {
      // Step 1: Look up profile by username only (case-insensitive)
      final result = await _supabase
          .from('profiles')
          .select()
          .ilike('username', username.trim())
          .maybeSingle();

      if (result == null) {
        _recordFailedAttempt();
        return null;
      }

      // Step 2: Verify PIN hash (supports both v1 and v2)
      final profileId = result['id'] as String;
      final storedHash = result['pin_hash'] as String?;

      if (storedHash == null || !_verifyPin(pin, profileId, storedHash)) {
        _recordFailedAttempt();
        return null;
      }

      // Success — reset rate limiter
      _failedAttempts = 0;
      _lockoutUntil = null;

      // Silently upgrade legacy hash to salted format
      await _upgradeHashIfNeeded(pin, profileId, storedHash);

      // Restore profile to Hive
      await _restoreToHive(result);

      return result;
    } catch (e) {
      debugPrint('Account recovery failed: $e');
      return null;
    }
  }

  /// Records a failed recovery attempt and triggers lockout at 3 failures.
  static void _recordFailedAttempt() {
    _failedAttempts++;
    if (_failedAttempts >= 3) {
      _lockoutUntil = DateTime.now().add(const Duration(seconds: 60));
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
    await box.put('isTeacher', profile['is_teacher'] ?? false);
    await box.put('pinHash', profile['pin_hash']);
    await box.put('hasOnboarded', true);
  }

  // ─── PIN Change ─────────────────────────────────────────────────

  /// Changes the PIN for the current user. Requires the old PIN for verification.
  /// Supports verifying against both v1 and v2 hashes, always saves as v2.
  static Future<bool> changePin({
    required String profileId,
    required String oldPin,
    required String newPin,
  }) async {
    try {
      final storedHash =
          Hive.box('userProfile').get('pinHash') as String?;

      if (storedHash == null || !_verifyPin(oldPin, profileId, storedHash)) {
        return false;
      }

      // Always saves in v2 (salted) format
      return await savePin(profileId: profileId, pin: newPin);
    } catch (e) {
      debugPrint('Change PIN failed: $e');
      return false;
    }
  }
}
