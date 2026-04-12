import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/class_student.dart';
import '../models/class_health_score.dart';
import '../services/analytics_service.dart';

class ClassStudentsState {
  final List<ClassStudent> students;
  final ClassHealthScore? healthScore;
  final bool isLoading;
  final String? error;

  const ClassStudentsState({
    this.students = const [],
    this.healthScore,
    this.isLoading = false,
    this.error,
  });
}

class ClassStudentsNotifier extends StateNotifier<ClassStudentsState> {
  ClassStudentsNotifier() : super(const ClassStudentsState());

  Future<void> load({
    required String classCode,
    required String teacherId,
  }) async {
    state = const ClassStudentsState(isLoading: true);
    try {
      final students = await AnalyticsService.getClassStudents(
        classCode: classCode,
        teacherId: teacherId,
      );
      final healthScore = AnalyticsService.computeHealthScore(students);
      state = ClassStudentsState(
        students: students,
        healthScore: healthScore,
        isLoading: false,
      );
    } catch (e) {
      state = ClassStudentsState(isLoading: false, error: e.toString());
    }
  }
}

final classStudentsProvider =
    StateNotifierProvider<ClassStudentsNotifier, ClassStudentsState>((ref) {
  return ClassStudentsNotifier();
});
