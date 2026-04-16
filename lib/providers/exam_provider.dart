import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/exam_participant.dart';
import '../models/exam_session.dart';
import '../services/exam_service.dart';
import 'profile_provider.dart';

/// List of the current teacher's exam sessions (newest first).
/// Re-fetches when invalidated.
final teacherExamSessionsProvider =
    FutureProvider.autoDispose<List<ExamSession>>((ref) async {
  final profile = ref.watch(profileProvider);
  if (profile == null || !profile.isTeacher) return <ExamSession>[];
  return ExamService.fetchTeacherSessions(profile.id);
});

/// Per-student answer summary used by the live progress grid.
class StudentProgress {
  final String studentId;
  final String username;
  final int answered;
  final int correct;
  final String status; // from exam_participants

  const StudentProgress({
    required this.studentId,
    required this.username,
    required this.answered,
    required this.correct,
    required this.status,
  });
}

/// Bundle of session + participants + live answer progress.
class ExamLobbyState {
  final ExamSession? session;
  final List<ExamParticipant> participants;
  final List<StudentProgress> progress;
  final bool loading;
  final String? error;

  const ExamLobbyState({
    this.session,
    this.participants = const <ExamParticipant>[],
    this.progress = const <StudentProgress>[],
    this.loading = false,
    this.error,
  });

  ExamLobbyState copyWith({
    ExamSession? session,
    List<ExamParticipant>? participants,
    List<StudentProgress>? progress,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      ExamLobbyState(
        session: session ?? this.session,
        participants: participants ?? this.participants,
        progress: progress ?? this.progress,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );

  int get joinedCount =>
      participants.where((p) => p.hasJoined || p.isFinished).length;
  int get totalInvited => participants.length;
  int get completedCount =>
      participants.where((p) => p.isFinished).length;
}

class ExamLobbyNotifier extends StateNotifier<ExamLobbyState> {
  ExamLobbyNotifier(this._sessionId)
      : super(const ExamLobbyState(loading: true)) {
    _init();
  }

  final String _sessionId;
  RealtimeChannel? _partChannel;
  RealtimeChannel? _sessChannel;
  RealtimeChannel? _answersChannel;

  Future<void> _init() async {
    try {
      final session = await ExamService.fetchSession(_sessionId);
      final participants = await ExamService.fetchParticipants(_sessionId);
      if (!mounted) return;
      state = state.copyWith(
        session: session,
        participants: participants,
        loading: false,
        clearError: true,
      );
      // Build initial progress from participant data.
      await _rebuildProgress(participants);
    } catch (e, s) {
      debugPrint('ExamLobby init failed: $e\n$s');
      if (!mounted) return;
      state = state.copyWith(loading: false, error: e.toString());
    }

    _partChannel =
        ExamService.subscribeToParticipants(_sessionId, _refetchParticipants);
    _sessChannel =
        ExamService.subscribeToSession(_sessionId, _onSessionUpdate);
    _answersChannel = _subscribeToAnswers();
  }

  Future<void> _refetchParticipants() async {
    try {
      final participants = await ExamService.fetchParticipants(_sessionId);
      if (!mounted) return;
      state = state.copyWith(participants: participants);
      await _rebuildProgress(participants);
    } catch (e, s) {
      debugPrint('ExamLobby participants refetch failed: $e\n$s');
    }
  }

  void _onSessionUpdate(ExamSession updated) {
    if (!mounted) return;
    state = state.copyWith(session: updated);
  }

  /// Rebuilds the progress list from participant data.
  /// During in_progress, we also fetch per-student answer counts.
  Future<void> _rebuildProgress(List<ExamParticipant> participants) async {
    if (state.session == null) return;

    // For lobby/cancelled, just show join status.
    if (state.session!.status == 'lobby' ||
        state.session!.status == 'cancelled') {
      state = state.copyWith(
        progress: participants
            .map((p) => StudentProgress(
                  studentId: p.studentId,
                  username: p.username ?? p.studentId,
                  answered: 0,
                  correct: 0,
                  status: p.status,
                ))
            .toList(),
      );
      return;
    }

    // For in_progress / completed, fetch answer counts per student.
    try {
      final answers = await ExamService.fetchAllAnswers(_sessionId);
      if (!mounted) return;

      // Group answers by student.
      final byStudent = <String, _AnswerTally>{};
      for (final a in answers) {
        final sid = a['student_id'].toString();
        final tally = byStudent.putIfAbsent(sid, _AnswerTally.new);
        tally.total++;
        if (a['is_correct'] == true) tally.correct++;
      }

      final progressList = participants.map((p) {
        final tally = byStudent[p.studentId];
        return StudentProgress(
          studentId: p.studentId,
          username: p.username ?? p.studentId,
          answered: tally?.total ?? p.correctCount ?? 0,
          correct: tally?.correct ?? 0,
          status: p.status,
        );
      }).toList();

      state = state.copyWith(progress: progressList);
    } catch (e, s) {
      debugPrint('Progress rebuild failed: $e\n$s');
    }
  }

  /// Subscribes to exam_answers inserts so the progress grid updates live.
  RealtimeChannel _subscribeToAnswers() {
    return Supabase.instance.client
        .channel('exam-answers-$_sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'exam_answers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: _sessionId,
          ),
          callback: (_) {
            // Re-fetch participants + answers to rebuild progress.
            _refetchParticipants();
          },
        )
        .subscribe((status, [error]) {
      if (error != null) {
        debugPrint('exam-answers subscribe error: $error');
      }
    });
  }

  Future<void> startExam() async {
    await ExamService.startSession(_sessionId);
  }

  Future<void> cancelExam() async {
    await ExamService.cancelSession(_sessionId);
  }

  Future<void> endExam() async {
    await ExamService.endSession(_sessionId);
  }

  @override
  void dispose() {
    try {
      _partChannel?.unsubscribe();
    } catch (_) {}
    try {
      _sessChannel?.unsubscribe();
    } catch (_) {}
    try {
      _answersChannel?.unsubscribe();
    } catch (_) {}
    super.dispose();
  }
}

class _AnswerTally {
  int total = 0;
  int correct = 0;
}

final examLobbyProvider = StateNotifierProvider.autoDispose
    .family<ExamLobbyNotifier, ExamLobbyState, String>((ref, sessionId) {
  return ExamLobbyNotifier(sessionId);
});
