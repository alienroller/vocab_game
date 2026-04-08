import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class WordEntry {
  final String english;
  final String uzbek;
  final String? partOfSpeech;
  final String? definition;
  final String? example;
  final int frequencyRank;
  final String? cefrLevel;

  WordEntry({
    required this.english,
    required this.uzbek,
    this.partOfSpeech,
    this.definition,
    this.example,
    this.frequencyRank = 999999,
    this.cefrLevel,
  });

  factory WordEntry.fromJson(Map<String, dynamic> json) {
    return WordEntry(
      english: json['english'] as String,
      uzbek: json['uzbek'] as String,
      partOfSpeech: json['part_of_speech'] as String?,
      definition: json['definition'] as String?,
      example: json['example'] as String?,
      frequencyRank: json['frequency_rank'] as int? ?? 999999,
      cefrLevel: json['cefr_level'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'english': english,
      'uzbek': uzbek,
      'part_of_speech': partOfSpeech,
      'definition': definition,
      'example': example,
      'frequency_rank': frequencyRank,
      'cefr_level': cefrLevel,
    };
  }
}

enum DownloadPack { common }

class DictionaryService {
  static final DictionaryService _instance = DictionaryService._internal();
  factory DictionaryService() => _instance;
  DictionaryService._internal();

  LazyBox<String>? _wordCache;
  Box<dynamic>? _packsBox;
  
  final Map<String, WordEntry> _bundled = {};
  bool _bundleLoaded = false;
  
  static const _wordCacheName = 'word_cache';
  static const _packsBoxName = 'downloaded_packs';
  
  static const Map<DownloadPack, int> _packLimits = {
    DownloadPack.common: 999999,
  };

  Future<void> init() async {
    await _initDb();
    await loadBundle();
  }

  Future<void> _initDb() async {
    if (_wordCache != null && _packsBox != null) return;
    
    // Fallback initializing for safety, although main.dart usually already calls this
    try {
      await Hive.initFlutter();
    } catch (_) {}

    if (Hive.isBoxOpen(_wordCacheName)) {
      _wordCache = Hive.lazyBox<String>(_wordCacheName);
    } else {
      _wordCache = await Hive.openLazyBox<String>(_wordCacheName);
    }

    if (Hive.isBoxOpen(_packsBoxName)) {
      _packsBox = Hive.box<dynamic>(_packsBoxName);
    } else {
      _packsBox = await Hive.openBox<dynamic>(_packsBoxName);
    }
  }

  Future<void> loadBundle() async {
    if (_bundleLoaded) return;
    try {
      final jsonString = await rootBundle.loadString('assets/top5000_bundle.json');
      final List<dynamic> data = jsonDecode(jsonString);
      for (final item in data) {
        final entry = WordEntry.fromJson(item as Map<String, dynamic>);
        _bundled[entry.english.toLowerCase()] = entry;
      }
      _bundleLoaded = true;
      print('✅ Bundled dictionary: ${_bundled.length} words');
    } catch (e) {
      print('⚠️ Could not load bundled dictionary: $e');
    }
  }

  Future<WordEntry?> lookup(String word, {bool allowFallback = true}) async {
    final key = word.toLowerCase().trim();
    if (key.isEmpty) return null;

    // Tier 1: Bundled
    if (!_bundleLoaded) await loadBundle();
    if (_bundled.containsKey(key)) {
      return _bundled[key];
    }

    // Tier 2: Hive Local Cache
    await _initDb();
    final cachedJson = await _wordCache!.get(key);
    if (cachedJson != null) {
      return WordEntry.fromJson(jsonDecode(cachedJson));
    }

    // Tier 3: Supabase
    try {
      final List<dynamic> data = await Supabase.instance.client
          .from('dictionary_words')
          .select()
          .eq('english', key);

      if (data.isNotEmpty) {
        final entries = data.map((item) => WordEntry.fromJson(item as Map<String, dynamic>)).toList();
        await _cacheWords(entries);
        
        final cachedJson = await _wordCache!.get(key);
        if (cachedJson != null) {
          return WordEntry.fromJson(jsonDecode(cachedJson));
        }
      }
    } catch (e) {
      print('Supabase lookup failed: $e');
    }

    // Tier 4: Google Translate Self-Healing Fallback
    if (!allowFallback) return null;

    // Strict Validation: Guarantee it's a real English word before translating
    try {
      final validationUrl = Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(key)}');
      final validationRes = await http.get(validationUrl).timeout(const Duration(seconds: 4));
      // The API returns 404 for typos, partial strings, and non-existent words.
      if (validationRes.statusCode != 200) {
        return null; // Reject immediately!
      }
    } catch (e) {
      print('Network validation failed: $e');
      return null;
    }
    
    try {
      final url = Uri.parse('https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=uz&dt=t&q=${Uri.encodeComponent(key)}');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data.isNotEmpty && data[0] != null && data[0].isNotEmpty) {
           final translatedText = data[0][0][0] as String;
           if (translatedText.toLowerCase() != key.toLowerCase()) {
              final newEntry = WordEntry(
                english: key,
                uzbek: translatedText.toLowerCase(),
                partOfSpeech: 'Unknown',
                definition: 'Auto-translated via Google', 
                frequencyRank: 999999,
              );
              // Cache it locally so we never need the API for this word again
              await _cacheWords([newEntry]);
              return newEntry;
           }
        }
      }
    } catch (e) {
      print('Google Translate API fallback failed: $e');
    }

    return null;
  }

  Future<List<WordEntry>> search(String query, {int limit = 10}) async {
    final key = query.toLowerCase().trim();
    if (key.isEmpty) return [];

    try {
      // First try Supabase if online
      final data = await Supabase.instance.client
          .from('dictionary_words')
          .select()
          .ilike('english', '$key%')
          .order('frequency_rank', ascending: true)
          .limit(limit);

      final results = (data as List<dynamic>)
          .map((item) => WordEntry.fromJson(item as Map<String, dynamic>))
          .toList();
          
      // Cache results in background to improve offline tier later
      _cacheWords(results).ignore();
      return results;
    } catch (_) {
      // Fallback: Local bundle + logic
      if (!_bundleLoaded) await loadBundle();
      final results = <WordEntry>[];
      for (final eng in _bundled.keys) {
        if (eng.startsWith(key)) {
          results.add(_bundled[eng]!);
          if (results.length >= limit) break;
        }
      }
      
      // Expand to Hive offline cache if not enough from bundle
      if (results.length < limit) {
         await _initDb();
         final matchingKeys = _wordCache!.keys.where((k) => k.toString().startsWith(key));
         
         for(final matchKey in matchingKeys) {
            if (results.length >= limit) break;
            if(!results.any((e) => e.english == matchKey)){
               final val = await _wordCache!.get(matchKey);
               if (val != null) {
                 results.add(WordEntry.fromJson(jsonDecode(val)));
               }
            }
         }
      }
      
      results.sort((a,b) => a.frequencyRank.compareTo(b.frequencyRank));
      return results;
    }
  }

  Future<void> _cacheWords(List<WordEntry> words) async {
    if (words.isEmpty) return;
    await _initDb();
    
    final map = <String, String>{};
    for (final word in words) {
      final key = word.english.toLowerCase().trim();
      
      WordEntry? existing;
      if (map.containsKey(key)) {
        existing = WordEntry.fromJson(jsonDecode(map[key]!));
      } else {
        final cached = await _wordCache!.get(key);
        if (cached != null) {
          existing = WordEntry.fromJson(jsonDecode(cached));
        }
      }

      if (existing != null) {
         final existingUzbeks = existing.uzbek.split(',').map((e) => e.trim()).toList();
         if (!existingUzbeks.contains(word.uzbek.trim())) {
            final newEntry = WordEntry(
                english: word.english,
                uzbek: '${existing.uzbek}, ${word.uzbek}',
                partOfSpeech: (existing.partOfSpeech == null || existing.partOfSpeech == 'Unknown' || existing.partOfSpeech!.trim().isEmpty) ? word.partOfSpeech : existing.partOfSpeech,
                definition: (existing.definition == null || existing.definition!.trim().isEmpty) ? word.definition : existing.definition,
                example: (existing.example == null || existing.example!.trim().isEmpty) ? word.example : existing.example,
                frequencyRank: existing.frequencyRank < word.frequencyRank ? existing.frequencyRank : word.frequencyRank,
                cefrLevel: (existing.cefrLevel == null || existing.cefrLevel!.trim().isEmpty) ? word.cefrLevel : existing.cefrLevel,
            );
            map[key] = jsonEncode(newEntry.toJson());
         } else {
            if (!map.containsKey(key)) {
              map[key] = jsonEncode(existing.toJson());
            }
         }
      } else {
         map[key] = jsonEncode(word.toJson());
      }
    }
    
    // Save in batches of 500 to ensure Web IndexedDB stability
    final entries = map.entries.toList();
    final batchSize = 500;
    for (int i = 0; i < entries.length; i += batchSize) {
       final end = (i + batchSize < entries.length) ? i + batchSize : entries.length;
       final batchMap = Map.fromEntries(entries.sublist(i, end));
       await _wordCache!.putAll(batchMap);
    }
  }

  Future<bool> downloadPack(
    DownloadPack pack, {
    Function(double)? onProgress,
  }) async {
    final limit = _packLimits[pack]!;
    final batchSize = 1000;
    final allWords = <WordEntry>[];

    onProgress?.call(0);

    int from = 0;
    while (allWords.length < limit) {
      final to = (from + batchSize - 1) < (limit - 1) 
                 ? (from + batchSize - 1) 
                 : (limit - 1);
                 
      try {
        final data = await Supabase.instance.client
            .from('dictionary_words')
            .select()
            .order('frequency_rank', ascending: true)
            .range(from, to);

        if (data.isEmpty) break;

        for (final row in data) {
          allWords.add(WordEntry.fromJson(row));
        }
        from += batchSize;

        final pct = (allWords.length / limit) * 100;
        onProgress?.call(pct > 99 ? 99 : pct);
      } catch (e) {
        print('Pack download interrupted: $e');
        return false;
      }
    }

    await _cacheWords(allWords);
    await _markPackDownloaded(pack, allWords.length);

    onProgress?.call(100);
    print('✅ Downloaded ${pack.name} pack: ${allWords.length} words');
    return true;
  }

  Future<void> _markPackDownloaded(DownloadPack pack, int count) async {
    await _initDb();
    await _packsBox!.put(pack.name, {
      'word_count': count,
      'downloaded_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<DownloadPack, bool>> getDownloadedPacks() async {
    await _initDb();
    final downloaded = {
      DownloadPack.common: false,
    };
    
    for (final packName in _packsBox!.keys) {
      try {
         final pack = DownloadPack.values.firstWhere((p) => p.name == packName);
         downloaded[pack] = true;
      } catch(_) {}
    }
    return downloaded;
  }

  Future<int> getCachedWordCount() async {
    await _initDb();
    return _wordCache!.length;
  }
}

// Global instance for simple usage without ref wrapper
final dictionaryService = DictionaryService();
