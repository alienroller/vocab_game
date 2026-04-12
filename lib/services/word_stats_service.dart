import 'package:supabase_flutter/supabase_flutter.dart';

class WordStatsService {
  static final _supabase = Supabase.instance.client;

  /// Records the result of answering a single vocabulary word.
  /// Call this for EVERY word answered in ANY game mode (personal or assignment).
  ///
  /// Parameters:
  /// - studentId: the student's UUID
  /// - classCode: the student's class_code (null if student has no class — skip upload)
  /// - wordEnglish: the English side of the word
  /// - wordUzbek: the Uzbek side of the word
  /// - wasCorrect: whether the student answered correctly
  static Future<void> recordWordAnswer({
    required String studentId,
    required String? classCode,
    required String wordEnglish,
    required String wordUzbek,
    required bool wasCorrect,
  }) async {
    // Only sync to Supabase if the student is in a class.
    // No class = no teacher = no analytics needed.
    if (classCode == null || classCode.isEmpty) return;

    // Upsert: if row exists, increment. If not, create.
    // We cannot use a single SQL increment upsert easily from client SDK,
    // so we use a fetch-then-update pattern with conflict handling.
    try {
      final existing = await _supabase
          .from('word_stats')
          .select('id, times_shown, times_correct')
          .eq('student_id', studentId)
          .eq('word_english', wordEnglish)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('word_stats').insert({
          'student_id': studentId,
          'class_code': classCode,
          'word_english': wordEnglish,
          'word_uzbek': wordUzbek,
          'times_shown': 1,
          'times_correct': wasCorrect ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        await _supabase
            .from('word_stats')
            .update({
              'times_shown': (existing['times_shown'] as int) + 1,
              'times_correct': (existing['times_correct'] as int) + (wasCorrect ? 1 : 0),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id'] as String);
      }
    } catch (_) {
      // Silently fail — word stat tracking is non-critical.
      // Main game flow must not be blocked by analytics failures.
    }
  }
}
