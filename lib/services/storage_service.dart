import 'package:hive_flutter/hive_flutter.dart';
import '../models/vocab.dart';

class StorageService {
  static const String boxName = 'vocabBox';
  static late Box _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(boxName);
  }

  static List<Vocab> getAllVocab() {
    final List<Vocab> vocabList = [];
    for (var i = 0; i < _box.length; i++) {
      final dynamic item = _box.getAt(i);
      if (item is Map) {
         vocabList.add(Vocab.fromMap(item));
      }
    }
    return vocabList;
  }

  static Future<void> saveAllVocab(List<Vocab> vocabList) async {
    final List<Map<String, dynamic>> mappedList = vocabList.map((v) => v.toMap()).toList();
    await _box.clear();
    await _box.addAll(mappedList);
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
