import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/vocab.dart';
import 'secure_storage_service.dart';

class StorageService {
  static const String boxName = 'vocabBox';
  static const String _typedBoxName = 'vocabTypedBox';

  /// Encrypted box for sensitive data (PIN rate-limit state, PIN hash mirror).
  /// Opened from `main.dart` via [openSecurityBox].
  static const String securityBoxName = 'secureBox';

  static late Box<Vocab> _box;
  static bool _securityBoxOpened = false;

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register the typed Vocab adapter
    if (!Hive.isAdapterRegistered(VocabAdapter().typeId)) {
      Hive.registerAdapter(VocabAdapter());
    }

    // Migrate from old untyped box if it exists
    await _migrateFromUntypedBox();

    // Open the typed box
    _box = await Hive.openBox<Vocab>(_typedBoxName);
  }

  /// Opens the AES-encrypted `secureBox`.
  ///
  /// The key is generated once per install and stored in the platform keystore
  /// (Android Keystore / iOS Keychain) via [SecureStorageService].
  /// Safe to call multiple times — subsequent calls are a no-op.
  static Future<void> openSecurityBox() async {
    if (_securityBoxOpened) return;
    try {
      final keyBytes = await SecureStorageService.getOrCreateHiveKey();
      await Hive.openBox(
        securityBoxName,
        encryptionCipher: HiveAesCipher(keyBytes),
      );
      _securityBoxOpened = true;

      // Migrate pinHash from plaintext userProfile box → encrypted security box
      await _migratePinHashIfNeeded();
    } catch (e, s) {
      debugPrint('Failed to open secure box: $e\n$s');
      // Fall back to unencrypted box so the app keeps functioning.
      // A cipher mismatch in future runs will rotate the key (next try).
      if (!Hive.isBoxOpen(securityBoxName)) {
        await Hive.openBox(securityBoxName);
      }
      _securityBoxOpened = true;
    }
  }

  /// Moves the PIN hash from the plaintext `userProfile` box into the
  /// encrypted `secureBox` on first encrypted-build launch.
  /// Idempotent — safe to call on every startup.
  static Future<void> _migratePinHashIfNeeded() async {
    try {
      if (!Hive.isBoxOpen('userProfile')) return;
      final profileBox = Hive.box('userProfile');
      final legacyHash = profileBox.get('pinHash') as String?;
      if (legacyHash == null) return;

      final secureBox = Hive.box(securityBoxName);
      if (secureBox.get('pinHash') == null) {
        await secureBox.put('pinHash', legacyHash);
      }
      // Leave the legacy copy in userProfile for one release so old versions
      // of the app that skip this migration keep working — can remove later.
    } catch (e) {
      debugPrint('pinHash migration skipped: $e');
    }
  }

  /// One-time migration: reads old Map-based data from 'vocabBox',
  /// converts to typed Vocab objects, stores in 'vocabTypedBox',
  /// then deletes the old box.
  static Future<void> _migrateFromUntypedBox() async {
    final bool oldBoxExists = await Hive.boxExists(boxName);
    final bool newBoxExists = await Hive.boxExists(_typedBoxName);

    if (oldBoxExists && !newBoxExists) {
      // Open old box as untyped
      final oldBox = await Hive.openBox(boxName);
      final List<Vocab> migratedVocab = [];

      for (int i = 0; i < oldBox.length; i++) {
        final dynamic item = oldBox.getAt(i);
        if (item is Map) {
          try {
            migratedVocab.add(Vocab.fromMap(item));
          } catch (e) {
            debugPrint('Skipping corrupted vocab entry during migration: $e');
          }
        }
      }

      await oldBox.close();

      // Write migrated data to new typed box
      final newBox = await Hive.openBox<Vocab>(_typedBoxName);
      for (final vocab in migratedVocab) {
        await newBox.put(vocab.id, vocab);
      }
      await newBox.close();

      // Delete old box
      await Hive.deleteBoxFromDisk(boxName);
    }
    // If newBoxExists already, migration was already done — skip.
    // If neither exists, the typed box will be created on open.
  }

  static List<Vocab> getAllVocab() {
    return _box.values.toList();
  }

  static Future<void> saveAllVocab(List<Vocab> vocabList) async {
    await _box.clear();
    for (final vocab in vocabList) {
      await _box.put(vocab.id, vocab);
    }
  }

  static Future<void> addSampleData() async {
    if (_box.isEmpty) {
      final sampleData = [
        Vocab(id: '1', english: 'apple', uzbek: 'olma'),
        Vocab(id: '2', english: 'book', uzbek: 'kitob'),
        Vocab(id: '3', english: 'run', uzbek: 'yugurmoq'),
        Vocab(id: '4', english: 'eat', uzbek: 'yemoq'),
        Vocab(id: '5', english: 'drink', uzbek: 'ichmoq'),
      ];
      await saveAllVocab(sampleData);
    }
  }
}
