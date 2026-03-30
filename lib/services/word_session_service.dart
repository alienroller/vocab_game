import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Intelligent word selection for game sessions using spaced repetition.
///
/// When a student hits Play on a unit, this service selects the words
/// they need most based on their mastery history — not just random words.
class WordSessionService {
  static final _supabase = Supabase.instance.client;

  /// Selects the best [count] words for a session from a unit.
  ///
  /// Priority order:
  ///   1. Words never seen before (highest — always show new words first)
  ///   2. Words seen but not yet mastered (lowest correct_days first,
  ///      then oldest last_seen_date first)
  ///   3. Mastered words (only as filler if fewer unmastered words remain)
  static Future<List<Map<String, dynamic>>> selectSessionWords({
    required String unitId,
    int count = 10,
  }) async {
    final profileBox = Hive.box('userProfile');
    final userId = profileBox.get('id') as String?;
    if (userId == null) return [];

    try {
      // Fetch all words in this unit
      final allWords = await _supabase
          .from('words')
          .select(
              'id, word, translation, example_sentence, word_type, difficulty')
          .eq('unit_id', unitId)
          .order('word_number');

      if ((allWords as List).isEmpty) return [];

      final wordIds = allWords.map((w) => w['id'] as String).toList();

      // Fetch this user's mastery records for these words
      final masteryRecords = await _supabase
          .from('word_mastery')
          .select(
              'word_id, seen_count, correct_count, correct_days, last_seen_date, is_mastered')
          .eq('profile_id', userId)
          .inFilter('word_id', wordIds);

      // Build lookup map: wordId → mastery record
      final masteryMap = <String, Map<String, dynamic>>{};
      for (final m in (masteryRecords as List)) {
        masteryMap[m['word_id'] as String] = Map<String, dynamic>.from(m);
      }

      // Categorize words
      final neverSeen = <Map<String, dynamic>>[];
      final inProgress = <Map<String, dynamic>>[];
      final mastered = <Map<String, dynamic>>[];

      for (final word in allWords) {
        final wordId = word['id'] as String;
        final mastery = masteryMap[wordId];

        if (mastery == null || (mastery['seen_count'] as int) == 0) {
          neverSeen.add(Map<String, dynamic>.from(word));
        } else if (mastery['is_mastered'] == true) {
          mastered.add(Map<String, dynamic>.from(word));
        } else {
          inProgress.add({...word, '_mastery': mastery});
        }
      }

      // Sort in-progress: lowest correct_days first, then oldest last_seen
      inProgress.sort((a, b) {
        final aM = a['_mastery'] as Map<String, dynamic>;
        final bM = b['_mastery'] as Map<String, dynamic>;
        final daysDiff =
            (aM['correct_days'] as int).compareTo(bM['correct_days'] as int);
        if (daysDiff != 0) return daysDiff;
        final aDate = aM['last_seen_date'] as String? ?? '2000-01-01';
        final bDate = bM['last_seen_date'] as String? ?? '2000-01-01';
        return aDate.compareTo(bDate);
      });

      // Build final selection: neverSeen → inProgress → mastered (filler)
      final selected = <Map<String, dynamic>>[];
      selected.addAll(neverSeen.take(count));
      if (selected.length < count) {
        selected.addAll(inProgress.take(count - selected.length));
      }
      if (selected.length < count) {
        selected.addAll(mastered.take(count - selected.length));
      }

      // Remove internal _mastery field before returning
      return selected.take(count).map((w) {
        final clean = Map<String, dynamic>.from(w);
        clean.remove('_mastery');
        return clean;
      }).toList();
    } catch (e) {
      debugPrint('Word selection failed: $e');
      return [];
    }
  }

  /// Records a single question answer to update word mastery.
  ///
  /// A word is marked mastered when answered correctly on 3 separate
  /// calendar days. This forces natural spaced repetition.
  static Future<void> recordAnswer({
    required String wordId,
    required bool isCorrect,
  }) async {
    final profileBox = Hive.box('userProfile');
    final userId = profileBox.get('id') as String?;
    if (userId == null) return;

    final today = DateTime.now().toIso8601String().substring(0, 10);

    try {
      final existing = await _supabase
          .from('word_mastery')
          .select()
          .eq('profile_id', userId)
          .eq('word_id', wordId)
          .maybeSingle();

      if (existing == null) {
        // First time seeing this word — create record
        await _supabase.from('word_mastery').insert({
          'profile_id': userId,
          'word_id': wordId,
          'seen_count': 1,
          'correct_count': isCorrect ? 1 : 0,
          'correct_days': isCorrect ? 1 : 0,
          'last_seen_date': today,
          'last_correct_date': isCorrect ? today : null,
          'is_mastered': false,
        });
      } else {
        final seenCount = (existing['seen_count'] as int) + 1;
        final correctCount =
            (existing['correct_count'] as int) + (isCorrect ? 1 : 0);

        int correctDays = existing['correct_days'] as int;
        String? lastCorrectDate = existing['last_correct_date'] as String?;
        if (isCorrect && lastCorrectDate != today) {
          correctDays += 1;
          lastCorrectDate = today;
        }

        final isMastered = correctDays >= 3;

        await _supabase
            .from('word_mastery')
            .update({
              'seen_count': seenCount,
              'correct_count': correctCount,
              'correct_days': correctDays,
              'last_seen_date': today,
              'last_correct_date': lastCorrectDate,
              'is_mastered': isMastered,
            })
            .eq('profile_id', userId)
            .eq('word_id', wordId);
      }
    } catch (e) {
      // Mastery tracking must never crash the game
      debugPrint('Mastery update failed: $e');
    }
  }
}
