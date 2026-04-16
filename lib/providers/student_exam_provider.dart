import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exam_session.dart';
import '../services/exam_service.dart';
import 'profile_provider.dart';

/// Active exam invitations for the current student's class.
/// Auto-refreshes every 15 seconds so new exams appear without manual pull.
final studentActiveExamsProvider =
    FutureProvider.autoDispose<List<ExamSession>>((ref) async {
  final profile = ref.watch(profileProvider);
  if (profile == null || profile.classCode == null || profile.isTeacher) {
    return <ExamSession>[];
  }
  // Re-poll every 15s so exams surface quickly without realtime.
  final timer = Timer(const Duration(seconds: 15), () {
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);

  return ExamService.fetchStudentActiveExams(profile.classCode!);
});

/// Tracks a single exam's lobby state from the student's perspective.
class StudentExamLobbyState {
  final ExamSession? session;
  final bool joined;
  final bool loading;
  final String? error;

  const StudentExamLobbyState({
    this.session,
    this.joined = false,
    this.loading = false,
    this.error,
  });

  StudentExamLobbyState copyWith({
    ExamSession? session,
    bool? joined,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      StudentExamLobbyState(
        session: session ?? this.session,
        joined: joined ?? this.joined,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

class StudentExamLobbyNotifier extends StateNotifier<StudentExamLobbyState> {
  StudentExamLobbyNotifier(this._sessionId)
      : super(const StudentExamLobbyState(loading: true)) {
    _init();
  }

  final String _sessionId;
  dynamic _sessChannel;

  Future<void> _init() async {
    try {
      final session = await ExamService.fetchSession(_sessionId);
      if (!mounted) return;
      state = state.copyWith(session: session, loading: false, clearError: true);
    } catch (e, s) {
      debugPrint('StudentExamLobby init failed: $e\n$s');
      if (!mounted) return;
      state = state.copyWith(loading: false, error: e.toString());
    }

    _sessChannel = ExamService.subscribeToSession(_sessionId, _onSessionUpdate);
  }

  void _onSessionUpdate(ExamSession updated) {
    if (!mounted) return;
    state = state.copyWith(session: updated);
  }

  Future<void> joinExam() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await ExamService.joinExam(_sessionId);
      if (!mounted) return;
      state = state.copyWith(joined: true, loading: false);
    } catch (e, s) {
      debugPrint('join-exam failed: $e\n$s');
      if (!mounted) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  @override
  void dispose() {
    try {
      _sessChannel?.unsubscribe();
    } catch (_) {}
    super.dispose();
  }
}

final studentExamLobbyProvider = StateNotifierProvider.autoDispose
    .family<StudentExamLobbyNotifier, StudentExamLobbyState, String>(
  (ref, sessionId) => StudentExamLobbyNotifier(sessionId),
);
