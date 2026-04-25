import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'game_constants.dart';
import 'storage_service.dart';

/// Handles account recovery via username + 6-digit PIN.
///
/// The PIN is salted with the user's profile ID and hashed (SHA-256)
/// before storage — never stored as plain text.
///
/// Rate limiting (S7 hardening):
///   • Failure counters are persisted in the encrypted `secureBox` so
///     killing the app no longer resets the counter.
///   • Lockout duration escalates exponentially:
///     3 fails → 60s, 6 fails → 2m, 9 fails → 4m, … capped at 24h.
///
/// Backward compatibility: existing unsalted (v1) hashes are accepted
/// during recovery and PIN change, then silently upgraded to salted (v2).
class AccountRecoveryService {
  static final _supabase = Supabase.instance.client;

  // ─── Persisted rate-limit keys ──────────────────────────────────
  static const _attemptsKey = 'pin_failed_attempts';
  static const _lockoutUntilKey = 'pin_lockout_until_iso';
  static const _escalationLevelKey = 'pin_lockout_level';

  static Box? _secureBoxOrNull() {
    if (!Hive.isBoxOpen(StorageService.securityBoxName)) return null;
    return Hive.box(StorageService.securityBoxName);
  }

  static int _readAttempts() =>
      (_secureBoxOrNull()?.get(_attemptsKey, defaultValue: 0) as int?) ?? 0;

  static DateTime? _readLockoutUntil() {
    final iso = _secureBoxOrNull()?.get(_lockoutUntilKey) as String?;
    if (iso == null) return null;
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }

  static int _readEscalationLevel() =>
      (_secureBoxOrNull()?.get(_escalationLevelKey, defaultValue: 0) as int?) ??
          0;

  static Future<void> _writeAttempts(int value) async {
    await _secureBoxOrNull()?.put(_attemptsKey, value);
  }

  static Future<void> _writeLockoutUntil(DateTime? value) async {
    final box = _secureBoxOrNull();
    if (box == null) return;
    if (value == null) {
      await box.delete(_lockoutUntilKey);
    } else {
      await box.put(_lockoutUntilKey, value.toIso8601String());
    }
  }

  static Future<void> _writeEscalationLevel(int value) async {
    await _secureBoxOrNull()?.put(_escalationLevelKey, value);
  }

  /// Checks if recovery attempts are currently locked out.
  static bool get isLockedOut {
    final until = _readLockoutUntil();
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      // Lockout expired — clear attempt counter but KEEP escalation level so
      // a second lockout in the same burst is longer (defeats kill-and-retry).
      _writeAttempts(0);
      _writeLockoutUntil(null);
      return false;
    }
    return true;
  }

  /// Returns seconds remaining in lockout, or 0 if not locked.
  static int get lockoutSecondsRemaining {
    final until = _readLockoutUntil();
    if (until == null) return 0;
    final remaining = until.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// Returns the lockout duration for the given escalation level.
  /// 0 = 60s, 1 = 120s, 2 = 240s, ... capped at 24h.
  static Duration _lockoutDurationFor(int level) {
    final seconds = GameConstants.initialPinLockout.inSeconds * (1 << level);
    final capped =
        seconds > GameConstants.maxPinLockout.inSeconds
            ? GameConstants.maxPinLockout.inSeconds
            : seconds;
    return Duration(seconds: capped);
  }

  // ─── PIN Hashing ────────────────────────────────────────────────

  static String _hashSalted(String pin, String profileId) {
    final bytes = utf8.encode('$profileId:${pin.trim()}');
    return sha256.convert(bytes).toString();
  }

  static String _hashLegacy(String pin) {
    final bytes = utf8.encode(pin.trim());
    return sha256.convert(bytes).toString();
  }

  static bool _verifyPin(String pin, String profileId, String storedHash) {
    if (_hashSalted(pin, profileId) == storedHash) return true;
    if (_hashLegacy(pin) == storedHash) return true;
    return false;
  }

  static Future<void> _upgradeHashIfNeeded(
    String pin,
    String profileId,
    String storedHash,
  ) async {
    final saltedHash = _hashSalted(pin, profileId);
    if (storedHash == saltedHash) return;

    try {
      await _supabase
          .from('profiles')
          .update({'pin_hash': saltedHash}).eq('id', profileId);
      Hive.box('userProfile').put('pinHash', saltedHash);
      _secureBoxOrNull()?.put('pinHash', saltedHash);
      debugPrint('PIN hash upgraded to salted format for profile $profileId');
    } catch (e) {
      debugPrint('PIN hash upgrade failed (non-critical): $e');
    }
  }

  // ─── Registration ───────────────────────────────────────────────

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
      _secureBoxOrNull()?.put('pinHash', hash);
      return true;
    } catch (e) {
      debugPrint('Save PIN failed: $e');
      return false;
    }
  }

  // ─── Recovery ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> recoverAccount({
    required String username,
    required String pin,
  }) async {
    if (isLockedOut) return null;

    try {
      // Step 1: Look up profile by username (case-insensitive)
      final result = await _supabase
          .from('profiles')
          .select()
          .ilike('username', username.trim())
          .maybeSingle();

      if (result == null) {
        await _recordFailedAttempt();
        return null;
      }

      // Step 2: Verify PIN hash (supports both v1 and v2)
      final profileId = result['id'] as String;
      final storedHash = result['pin_hash'] as String?;

      if (storedHash == null || !_verifyPin(pin, profileId, storedHash)) {
        await _recordFailedAttempt();
        return null;
      }

      // Success — reset rate limiter (both counters AND escalation level)
      await _writeAttempts(0);
      await _writeLockoutUntil(null);
      await _writeEscalationLevel(0);

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

  /// Records a failed recovery attempt and triggers lockout at [maxPinAttempts].
  /// Escalation level survives app restarts, preventing kill-and-retry brute force.
  static Future<void> _recordFailedAttempt() async {
    final attempts = _readAttempts() + 1;
    await _writeAttempts(attempts);

    if (attempts >= GameConstants.maxPinAttempts) {
      final level = _readEscalationLevel();
      final duration = _lockoutDurationFor(level);
      await _writeLockoutUntil(DateTime.now().add(duration));
      await _writeEscalationLevel(level + 1);
      debugPrint(
          'PIN lockout triggered (level $level → ${duration.inSeconds}s)');
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
    await box.put('longestStreak', profile['longest_streak'] ?? 0);
    await box.put('lastPlayedDate', profile['last_played_date']);
    await box.put('classCode', profile['class_code']);
    await box.put('weekXp', profile['week_xp'] ?? 0);
    await box.put('totalWordsAnswered', profile['total_words_answered'] ?? 0);
    await box.put('totalCorrect', profile['total_correct'] ?? 0);
    await box.put('isTeacher', profile['is_teacher'] ?? false);
    await box.put('pinHash', profile['pin_hash']);
    await box.put('hasOnboarded', true);

    // Mirror the PIN hash into the encrypted security box as well.
    _secureBoxOrNull()?.put('pinHash', profile['pin_hash']);
  }

  // ─── PIN Change ─────────────────────────────────────────────────

  static Future<bool> changePin({
    required String profileId,
    required String oldPin,
    required String newPin,
  }) async {
    try {
      // Prefer the encrypted copy if it's present.
      final storedHash =
          (_secureBoxOrNull()?.get('pinHash') as String?) ??
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
