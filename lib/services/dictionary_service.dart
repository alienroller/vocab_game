import 'dart:convert';
import 'package:flutter/foundation.dart';
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



class DictionaryService {
  static final DictionaryService _instance = DictionaryService._internal();
  factory DictionaryService() => _instance;
  DictionaryService._internal();

  LazyBox<String>? _wordCache;
  
  final Map<String, WordEntry> _bundled = {};
  bool _bundleLoaded = false;
  
  static const _wordCacheName = 'word_cache';

  Future<void> init() async {
    await _initDb();
    await loadBundle();
  }

  Future<void> _initDb() async {
    if (_wordCache != null) return;
    
    // Fallback initializing for safety, although main.dart usually already calls this
    try {
      await Hive.initFlutter();
    } catch (_) {}

    if (Hive.isBoxOpen(_wordCacheName)) {
      _wordCache = Hive.lazyBox<String>(_wordCacheName);
    } else {
      _wordCache = await Hive.openLazyBox<String>(_wordCacheName);
    }
  }

  Future<void> loadBundle() async {
    if (_bundleLoaded) return;
    try {
      final jsonString = await rootBundle.loadString('assets/top5000_bundle.json');
      final List<dynamic> data = jsonDecode(jsonString);
      
      final tempMap = <String, List<WordEntry>>{};
      for (final item in data) {
        final entry = WordEntry.fromJson(item as Map<String, dynamic>);
        final key = entry.english.toLowerCase();
        tempMap.putIfAbsent(key, () => []).add(entry);
      }
      
      for (final entryList in tempMap.values) {
        final merged = _mergeEntries(entryList);
        _bundled[merged.english.toLowerCase()] = merged;
      }
      _bundleLoaded = true;
      debugPrint('✅ Bundled dictionary: ${_bundled.length} words');
    } catch (e) {
      debugPrint('⚠️ Could not load bundled dictionary: $e');
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
          .ilike('english', key);

      if (data.isNotEmpty) {
        final entries = data.map((item) => WordEntry.fromJson(item as Map<String, dynamic>)).toList();
        _cacheWords(entries).ignore();
        return _mergeEntries(entries);
      }
    } catch (e) {
      debugPrint('Supabase lookup failed: $e');
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
      debugPrint('Network validation failed: $e');
      throw Exception('Network validation error: $e');
    }
    
    try {
      final url = Uri.parse('https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=uz&dt=t&q=${Uri.encodeComponent(key)}');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data.isNotEmpty && data[0] != null && data[0].isNotEmpty) {
           final translatedText = data[0][0][0] as String;
           final newEntry = WordEntry(
             english: key,
             uzbek: translatedText.toLowerCase(),
             partOfSpeech: 'Unknown',
             definition: 'Auto-translated via Google', 
             frequencyRank: 999999,
           );
           // Cache it locally so we never need the API for this word again
           _cacheWords([newEntry]).ignore();
           return newEntry;
        }
      }
    } catch (e) {
      debugPrint('Google Translate API fallback failed: $e');
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
      
      final combinedMap = <String, List<WordEntry>>{};
      for (final e in results) {
         final k = e.english.toLowerCase();
         combinedMap.putIfAbsent(k, () => []).add(e);
      }
      return combinedMap.values.map((list) => _mergeEntries(list)).toList();
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
      
      final combinedMap = <String, List<WordEntry>>{};
      for (final e in results) {
         final k = e.english.toLowerCase();
         combinedMap.putIfAbsent(k, () => []).add(e);
      }
      final finalResults = combinedMap.values.map((list) => _mergeEntries(list)).toList();
      return finalResults;
    }
  }

  Future<void> _cacheWords(List<WordEntry> words) async {
    if (words.isEmpty) return;
    await _initDb();
    
    // Group words by key to handle duplicates in the incoming list
    final groupByEng = <String, List<WordEntry>>{};
    for (final w in words) {
       groupByEng.putIfAbsent(w.english.toLowerCase().trim(), () => []).add(w);
    }

    final map = <String, String>{};
    for (final entry in groupByEng.entries) {
      final key = entry.key;
      final newWordsForThisKey = entry.value;

      WordEntry? existing;
      final cached = await _wordCache!.get(key);
      if (cached != null) {
         existing = WordEntry.fromJson(jsonDecode(cached));
      }
      
      final allToMerge = <WordEntry>[];
      if (existing != null) allToMerge.add(existing);
      allToMerge.addAll(newWordsForThisKey);

      final merged = _mergeEntries(allToMerge);
      map[key] = jsonEncode(merged.toJson());
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

  int getBundledWordCount() => _bundled.length;

  Future<int> getCachedWordCount() async {
    await _initDb();
    return _wordCache!.length;
  }



  WordEntry _mergeEntries(List<WordEntry> entries) {
    if (entries.isEmpty) throw ArgumentError('Cannot merge empty list');
    if (entries.length == 1) return entries.first;
    
    final uzbekSet = <String>{};
    final posSet = <String>{};
    final definitions = <String>[];
    final examples = <String>[];
    int minRank = 999999;
    String? bestCefr;
    
    for (final e in entries) {
       final parts = e.uzbek.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
       uzbekSet.addAll(parts);
       
       if (e.partOfSpeech != null && e.partOfSpeech != 'Unknown' && e.partOfSpeech!.trim().isNotEmpty) {
          final posParts = e.partOfSpeech!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
          posSet.addAll(posParts);
       }
       
       if (e.definition != null && e.definition!.trim().isNotEmpty) {
          final defParts = e.definition!.split('\n');
          for (var p in defParts) {
             p = p.trim();
             if (p.startsWith('• ')) p = p.substring(2).trim();
             if (p.isNotEmpty && !definitions.contains(p)) {
                 definitions.add(p);
             }
          }
       }
       
       if (e.example != null && e.example!.trim().isNotEmpty) {
          final exParts = e.example!.split('\n');
          for (var p in exParts) {
             p = p.trim();
             if (p.startsWith('• ')) p = p.substring(2).trim();
             if (p.isNotEmpty && !examples.contains(p)) {
                 examples.add(p);
             }
          }
       }
       
       if (e.frequencyRank < minRank) minRank = e.frequencyRank;
       if (bestCefr == null && e.cefrLevel != null && e.cefrLevel!.trim().isNotEmpty) {
           bestCefr = e.cefrLevel;
       }
    }
    
    String? combinedPos = posSet.isNotEmpty ? posSet.join(', ') : null;
    String? combinedDef;
    if (definitions.isNotEmpty) {
        combinedDef = definitions.length == 1 ? definitions.single : definitions.asMap().entries.map((e) => '• ${e.value}').join('\n');
    }
    String? combinedExample;
    if (examples.isNotEmpty) {
        combinedExample = examples.length == 1 ? examples.single : examples.asMap().entries.map((e) => '• ${e.value}').join('\n');
    }
    
    return WordEntry(
       english: entries.first.english,
       uzbek: uzbekSet.join(', '),
       partOfSpeech: combinedPos,
       definition: combinedDef,
       example: combinedExample,
       frequencyRank: minRank,
       cefrLevel: bestCefr,
    );
  }
}

// Global instance for simple usage without ref wrapper
final dictionaryService = DictionaryService();
