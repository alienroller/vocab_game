import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assignment.dart';
import '../models/assignment_progress.dart';
import '../services/assignment_service.dart';

// State: holds both the assignment list and the student's progress map
class AssignmentState {
  final List<Assignment> assignments;
  final Map<String, AssignmentProgress> progressMap; // assignmentId -> progress
  final bool isLoading;
  final String? error;

  const AssignmentState({
    this.assignments = const [],
    this.progressMap = const {},
    this.isLoading = false,
    this.error,
  });

  AssignmentState copyWith({
    List<Assignment>? assignments,
    Map<String, AssignmentProgress>? progressMap,
    bool? isLoading,
    String? error,
  }) {
    return AssignmentState(
      assignments: assignments ?? this.assignments,
      progressMap: progressMap ?? this.progressMap,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AssignmentNotifier extends StateNotifier<AssignmentState> {
  AssignmentNotifier() : super(const AssignmentState());

  /// Loads assignments for a STUDENT.
  /// Call this from the student's HomeScreen initState / ref.listen on profileProvider.
  Future<void> loadStudentAssignments({
    required String classCode,
    required String studentId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final assignments = await AssignmentService.getStudentAssignments(
        classCode: classCode,
      );
      final progressMap = await AssignmentService.getStudentProgressMap(
        studentId: studentId,
      );
      state = state.copyWith(
        assignments: assignments,
        progressMap: progressMap,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Loads assignments created by a TEACHER.
  /// Call this from the teacher's Library screen and Analytics screen.
  Future<void> loadTeacherAssignments({
    required String classCode,
    required String teacherId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final assignments = await AssignmentService.getTeacherAssignments(
        classCode: classCode,
        teacherId: teacherId,
      );
      // Teachers have no progress map — use empty map
      state = state.copyWith(
        assignments: assignments,
        progressMap: const {},
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Called after a student completes an assignment game session.
  /// Updates the progress map locally without a full reload.
  void updateLocalProgress(AssignmentProgress updatedProgress) {
    final newMap = Map<String, AssignmentProgress>.from(state.progressMap);
    newMap[updatedProgress.assignmentId] = updatedProgress;
    state = state.copyWith(progressMap: newMap);
  }

  /// Removes an assignment from the list (after teacher deactivates it).
  void removeAssignment(String assignmentId) {
    state = state.copyWith(
      assignments: state.assignments
          .where((a) => a.id != assignmentId)
          .toList(),
    );
  }
}

final assignmentProvider =
    StateNotifierProvider<AssignmentNotifier, AssignmentState>((ref) {
  return AssignmentNotifier();
});
