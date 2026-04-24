import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/class_student.dart';
import '../models/class_health_score.dart';
import '../models/word_stat.dart';

class AnalyticsService {
  static final _supabase = Supabase.instance.client;

  /// Returns all students in a class (excluding the teacher).
  /// teacher_id is used to exclude the teacher from the list.
  /// This replaces ClassService.getClassStudents() with a typed result.
  static Future<List<ClassStudent>> getClassStudents({
    required String classCode,
    required String teacherId,
  }) async {
    final data = await _supabase
        .from('profiles')
        .select('id, username, xp, level, streak_days, total_words_answered, total_correct, last_played_date')
        .eq('class_code', classCode)
        .eq('is_teacher', false)   // exclude teacher rows
        .neq('id', teacherId)      // belt-and-suspenders: also exclude by id
        .order('xp', ascending: false);
    return (data as List).map((e) => ClassStudent.fromMap(e)).toList();
  }

  /// Computes the ClassHealthScore from student data.
  /// Call this after getClassStudents() — pass the result directly.
  /// Does not make a Supabase call — pure computation.
  static ClassHealthScore computeHealthScore(List<ClassStudent> students) {
    if (students.isEmpty) {
      return ClassHealthScore(
        score: 0,
        avgAccuracy: 0,
        engagementRate: 0,
        totalStudents: 0,
        activeStudentsThisWeek: 0,
        atRiskCount: 0,
      );
    }

    // Average accuracy across all students with at least one answer
    final studentsWithAnswers = students.where((s) => s.totalWordsAnswered > 0);
    final avgAccuracy = studentsWithAnswers.isEmpty
        ? 0.0
        : studentsWithAnswers.map((s) => s.accuracy).reduce((a, b) => a + b) /
            studentsWithAnswers.length;

    // Engagement rate: fraction of students active in last 7 days
    // A student is "active this week" if lastPlayedDate is within the last 7 days
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final activeThisWeek = students.where((s) {
      if (s.lastPlayedDate == null) return false;
      final last = DateTime.parse(s.lastPlayedDate!);
      return last.isAfter(sevenDaysAgo);
    }).length;
    final engagementRate = activeThisWeek / students.length;

    // At-risk count: students who haven't played in 3+ days
    final atRisk = students.where((s) => s.isAtRisk).length;

    // Class health score formula:
    // (avgAccuracy × 0.5 + engagementRate × 0.5) × 100
    // This means: equally weights "are they accurate?" and "are they active?"
    final score = (avgAccuracy * 0.5 + engagementRate * 0.5) * 100;

    return ClassHealthScore(
      score: score,
      avgAccuracy: avgAccuracy,
      engagementRate: engagementRate,
      totalStudents: students.length,
      activeStudentsThisWeek: activeThisWeek,
      atRiskCount: atRisk,
    );
  }

  /// Counts students flagged as "at-risk" (never played OR last played ≥ 3
  /// days ago) across every class in [classCodes]. Mirrors the client-side
  /// [ClassStudent.isAtRisk] rule so numbers agree with the per-class view.
  /// Excludes the teacher row itself via both [is_teacher] and [teacherId].
  static Future<int> getTeacherAtRiskCount({
    required List<String> classCodes,
    required String teacherId,
  }) async {
    if (classCodes.isEmpty) return 0;
    final data = await _supabase
        .from('profiles')
        .select('last_played_date')
        .inFilter('class_code', classCodes)
        .eq('is_teacher', false)
        .neq('id', teacherId);

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    int atRisk = 0;
    for (final row in data as List) {
      final lastPlayed = row['last_played_date'] as String?;
      if (lastPlayed == null) {
        atRisk++;
        continue;
      }
      final last = DateTime.parse(lastPlayed);
      final lastOnly = DateTime(last.year, last.month, last.day);
      if (todayOnly.difference(lastOnly).inDays >= 3) atRisk++;
    }
    return atRisk;
  }

  /// Fetches word stats aggregated across all students in the class.
  /// Groups by word, sums times_shown and times_correct.
  /// Used for the word difficulty heatmap.
  /// Returns list sorted by accuracy ascending (hardest first).
  static Future<List<WordStat>> getClassWordStats({
    required String classCode,
  }) async {
    return _aggregateWordStats(
      await _supabase
          .from('word_stats')
          .select('word_english, word_uzbek, times_shown, times_correct')
          .eq('class_code', classCode),
    );
  }

  /// Same as [getClassWordStats] but aggregates across every class in
  /// [classCodes] — used by the multi-class analytics toggle so the teacher
  /// can see which words are hardest across all their students at once.
  static Future<List<WordStat>> getTeacherWordStats({
    required List<String> classCodes,
  }) async {
    if (classCodes.isEmpty) return const [];
    return _aggregateWordStats(
      await _supabase
          .from('word_stats')
          .select('word_english, word_uzbek, times_shown, times_correct')
          .inFilter('class_code', classCodes),
    );
  }

  /// Groups rows by word_english, sums counts, sorts hardest first.
  static List<WordStat> _aggregateWordStats(dynamic rawRows) {
    final rows = rawRows as List;
    if (rows.isEmpty) return const [];

    final Map<String, Map<String, dynamic>> aggregated = {};
    for (final row in rows) {
      final word = row['word_english'] as String;
      if (!aggregated.containsKey(word)) {
        aggregated[word] = {
          'word_english': word,
          'word_uzbek': row['word_uzbek'],
          'times_shown': 0,
          'times_correct': 0,
        };
      }
      aggregated[word]!['times_shown'] =
          (aggregated[word]!['times_shown'] as int) + (row['times_shown'] as int);
      aggregated[word]!['times_correct'] =
          (aggregated[word]!['times_correct'] as int) +
              (row['times_correct'] as int);
    }

    final stats = aggregated.values.map((e) => WordStat.fromMap(e)).toList();
    stats.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    return stats;
  }
}
