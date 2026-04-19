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

  /// Server-side status of THIS student's participant row. Null until the
  /// first fetch completes. Used by the lobby screen to route a student who
  /// already finished (or was marked absent / timed_out) straight to the
  /// results screen instead of re-entering the exam runner.
  final String? participantStatus;

  /// Score snapshot from the participant row (populated once the student has
  /// any answers recorded). Passed through to the results screen when routing
  /// a re-joining finisher so the score circle can render immediately.
  final int? correctCount;
  final int? totalCount;

  const StudentExamLobbyState({
    this.session,
    this.joined = false,
    this.loading = false,
    this.error,
    this.participantStatus,
    this.correctCount,
    this.totalCount,
  });

  bool get participantIsTerminal =>
      participantStatus == 'completed' ||
      participantStatus == 'absent' ||
      participantStatus == 'timed_out';

  StudentExamLobbyState copyWith({
    ExamSession? session,
    bool? joined,
    bool? loading,
    String? error,
    String? participantStatus,
    int? correctCount,
    int? totalCount,
    bool clearError = false,
  }) =>
      StudentExamLobbyState(
        session: session ?? this.session,
        joined: joined ?? this.joined,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        participantStatus: participantStatus ?? this.participantStatus,
        correctCount: correctCount ?? this.correctCount,
        totalCount: totalCount ?? this.totalCount,
      );
}

class StudentExamLobbyNotifier extends StateNotifier<StudentExamLobbyState> {
  StudentExamLobbyNotifier(this._sessionId)
      : super(const StudentExamLobbyState(loading: true)) {
    _init();
  }

  final String _sessionId;
  dynamic _sessChannel;
  Timer? _pollTimer;

  Future<void> _init() async {
    try {
      // Fetch session AND participation in parallel so we know up-front
      // whether this student has already finished — that dictates whether
      // the lobby should route them to /results instead of /take.
      final sessionFuture = ExamService.fetchSession(_sessionId);
      final partFuture = ExamService.fetchMyParticipation(_sessionId);

      final session = await sessionFuture;
      final participation = await partFuture;

      if (!mounted) return;
      state = state.copyWith(
        session: session,
        loading: false,
        clearError: true,
        participantStatus: participation?['status'] as String?,
        correctCount: (participation?['correct_count'] as num?)?.toInt(),
        totalCount: (participation?['total_count'] as num?)?.toInt(),
      );
    } catch (e, s) {
      debugPrint('StudentExamLobby init failed: $e\n$s');
      if (!mounted) return;
      state = state.copyWith(loading: false, error: e.toString());
    }

    _sessChannel = ExamService.subscribeToSession(_sessionId, _onSessionUpdate);

    // Fallback poll every 3s in case realtime events are delayed/missing —
    // catches status transitions (lobby → in_progress → completed) so the
    // student's UI can navigate even when realtime is unavailable.
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      try {
        final freshSessionFuture = ExamService.fetchSession(_sessionId);
        final freshPartFuture = ExamService.fetchMyParticipation(_sessionId);
        final fresh = await freshSessionFuture;
        final freshPart = await freshPartFuture;
        if (!mounted || fresh == null) return;
        final freshStatus = freshPart?['status'] as String?;
        // Only update if something actually changed (avoid needless rebuilds).
        if (fresh.status != state.session?.status ||
            fresh.startedAt != state.session?.startedAt ||
            freshStatus != state.participantStatus) {
          state = state.copyWith(
            session: fresh,
            participantStatus: freshStatus,
            correctCount: (freshPart?['correct_count'] as num?)?.toInt(),
            totalCount: (freshPart?['total_count'] as num?)?.toInt(),
          );
        }
      } catch (_) {/* swallow — next tick retries */}
    });
  }

  void _onSessionUpdate(ExamSession updated) {
    if (!mounted) return;
    state = state.copyWith(session: updated);
  }

  Future<void> joinExam() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final resp = await ExamService.joinExam(_sessionId);
      if (!mounted) return;
      // If the server recognised this student as already-finished, reflect
      // that in state so the lobby screen routes to results.
      final alreadyFinished = resp['alreadyFinished'] == true;
      state = state.copyWith(
        joined: true,
        loading: false,
        participantStatus: alreadyFinished
            ? (resp['status'] as String?)
            : state.participantStatus,
      );
    } catch (e, s) {
      debugPrint('join-exam failed: $e\n$s');
      if (!mounted) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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
