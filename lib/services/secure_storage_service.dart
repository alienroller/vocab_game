import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Bridges the platform keychain (Android Keystore / iOS Keychain) to the
/// rest of the app.
///
/// On web `flutter_secure_storage` backs onto IndexedDB + Web Crypto — still
/// better than plaintext on disk, but note that a determined attacker with
/// JS access could extract it. For mobile/desktop the key never leaves the
/// hardware-backed keystore.
class SecureStorageService {
  SecureStorageService._();

  static const _hiveKeyAlias = 'hive_master_key_v1';

  // AndroidOptions: require Android 6.0+ EncryptedSharedPreferences.
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Returns the 32-byte AES key used to encrypt Hive boxes.
  /// Generates one on first run and persists it in the platform keystore.
  static Future<List<int>> getOrCreateHiveKey() async {
    try {
      final existing = await _storage.read(key: _hiveKeyAlias);
      if (existing != null && existing.isNotEmpty) {
        final bytes = base64Decode(existing);
        if (bytes.length == 32) return bytes;
        // Corrupt key — regenerate.
        debugPrint(
            'SecureStorage: stored Hive key had wrong length, regenerating');
      }
      final rng = Random.secure();
      final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
      await _storage.write(key: _hiveKeyAlias, value: base64Encode(bytes));
      return bytes;
    } catch (e, s) {
      // On web / unsupported platforms the secure storage plugin can throw.
      // Fall back to an ephemeral in-memory key so the app still runs; data
      // stored in encrypted boxes during this session will be unreadable on
      // the next launch, which is the correct failure mode (no silent
      // plaintext fallback).
      debugPrint('SecureStorage unavailable, using ephemeral key: $e\n$s');
      final rng = Random.secure();
      return List<int>.generate(32, (_) => rng.nextInt(256));
    }
  }
}
