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

  /// Fetches word stats aggregated across all students in the class.
  /// Groups by word, sums times_shown and times_correct.
  /// Used for the word difficulty heatmap.
  /// Returns list sorted by accuracy ascending (hardest first).
  static Future<List<WordStat>> getClassWordStats({
    required String classCode,
  }) async {
    // Fetch all individual word_stats rows for the class
    final data = await _supabase
        .from('word_stats')
        .select('word_english, word_uzbek, times_shown, times_correct')
        .eq('class_code', classCode);

    final rows = data as List;
    if (rows.isEmpty) return [];

    // Aggregate: group by word_english, sum the counts
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
          (aggregated[word]!['times_correct'] as int) + (row['times_correct'] as int);
    }

    final stats = aggregated.values.map((e) => WordStat.fromMap(e)).toList();

    // Sort hardest first (lowest accuracy first)
    stats.sort((a, b) => a.accuracy.compareTo(b.accuracy));

    return stats;
  }
}
