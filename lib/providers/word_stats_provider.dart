import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word_stat.dart';
import '../services/analytics_service.dart';

class WordStatsState {
  final List<WordStat> stats;
  final bool isLoading;
  final String? error;

  const WordStatsState({
    this.stats = const [],
    this.isLoading = false,
    this.error,
  });
}

class WordStatsNotifier extends StateNotifier<WordStatsState> {
  WordStatsNotifier() : super(const WordStatsState());

  Future<void> load(String classCode) async {
    state = const WordStatsState(isLoading: true);
    try {
      final stats = await AnalyticsService.getClassWordStats(classCode: classCode);
      state = WordStatsState(stats: stats, isLoading: false);
    } catch (e) {
      state = WordStatsState(isLoading: false, error: e.toString());
    }
  }

  /// Aggregates word stats across every class in [classCodes]. Used by the
  /// multi-class teacher analytics toggle.
  Future<void> loadForTeacher(List<String> classCodes) async {
    state = const WordStatsState(isLoading: true);
    try {
      final stats =
          await AnalyticsService.getTeacherWordStats(classCodes: classCodes);
      state = WordStatsState(stats: stats, isLoading: false);
    } catch (e) {
      state = WordStatsState(isLoading: false, error: e.toString());
    }
  }
}

final wordStatsProvider =
    StateNotifierProvider<WordStatsNotifier, WordStatsState>((ref) {
  return WordStatsNotifier();
});
