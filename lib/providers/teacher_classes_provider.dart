import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/teacher_class.dart';
import '../services/class_service.dart';

class TeacherClassesState {
  final List<TeacherClass> classes;
  final bool isLoading;
  final String? error;

  const TeacherClassesState({
    this.classes = const [],
    this.isLoading = false,
    this.error,
  });

  TeacherClassesState copyWith({
    List<TeacherClass>? classes,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return TeacherClassesState(
      classes: classes ?? this.classes,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  int get count => classes.length;
  bool get atLimit => count >= ClassService.maxClassesPerTeacher;
}

class TeacherClassesNotifier extends StateNotifier<TeacherClassesState> {
  TeacherClassesNotifier() : super(const TeacherClassesState());

  Future<void> load(String teacherId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final classes = await ClassService.getTeacherClasses(teacherId);
      state = state.copyWith(classes: classes, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final teacherClassesProvider =
    StateNotifierProvider<TeacherClassesNotifier, TeacherClassesState>((ref) {
  return TeacherClassesNotifier();
});
