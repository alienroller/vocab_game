import 'package:hive_flutter/hive_flutter.dart';
import '../models/vocab.dart';

class StorageService {
  static const String boxName = 'vocabBox';
  static const String _typedBoxName = 'vocabTypedBox';
  static late Box<Vocab> _box;

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
          } catch (_) {
            // Skip corrupted entries
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
    } else if (!oldBoxExists && !newBoxExists) {
      // Fresh install — typed box will be created on open
    }
    // If newBoxExists already, migration was already done — skip
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
