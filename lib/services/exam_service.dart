import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/exam_participant.dart';
import '../models/exam_session.dart';

/// Thin wrapper around the exam-related Supabase tables + Edge Functions.
///
/// The Edge Functions accept `userId` (the client-generated profile UUID from
/// Hive) in the request body. No Supabase Auth is needed — this matches the
/// rest of the app's trust-the-client architecture.
class ExamService {
  ExamService._();
  static final SupabaseClient _supa = Supabase.instance.client;

  /// Returns the current user's profile ID from Hive.
  static String get _userId {
    final id = Hive.box('userProfile').get('id') as String?;
    if (id == null) throw Exception('No profile ID — user not onboarded');
    return id;
  }

  // ─── Teacher flows ────────────────────────────────────────────────────────

  /// Fetches every word in the given units from the Supabase `words` table.
  /// Returns `[{id, english, uzbek}, ...]` ready to be shipped to the
  /// `create-exam` Edge Function.
  static Future<List<Map<String, String>>> fetchWordsForUnits(
    List<String> unitIds,
  ) async {
    if (unitIds.isEmpty) return <Map<String, String>>[];
    final rows = await _supa
        .from('words')
        .select('id, word, translation')
        .inFilter('unit_id', unitIds);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => <String, String>{
              'id': r['id'].toString(),
              'english': (r['word'] ?? '').toString(),
              'uzbek': (r['translation'] ?? '').toString(),
            })
        .where((w) => w['english']!.isNotEmpty && w['uzbek']!.isNotEmpty)
        .toList();
  }

  /// Invokes the `create-exam` Edge Function. Returns the new session id.
  static Future<String> createExam({
    required String classCode,
    required String title,
    required List<String> bookIds,
    required List<String> unitIds,
    required int questionCount,
    required int perQuestionSeconds,
    required int totalSeconds,
    required List<Map<String, String>> words,
  }) async {
    final resp = await _invoke(
      'create-exam',
      <String, dynamic>{
        'userId': _userId,
        'classCode': classCode,
        'title': title,
        'bookIds': bookIds,
        'unitIds': unitIds,
        'questionCount': questionCount,
        'perQuestionSeconds': perQuestionSeconds,
        'totalSeconds': totalSeconds,
        'words': words,
      },
    );
    final data = resp.data as Map<String, dynamic>;
    return data['sessionId'] as String;
  }

  /// Wraps `functions.invoke` so gateway-level errors (e.g. 401 from JWT
  /// verification when the anon key can't be verified) surface as a clean,
  /// user-readable message instead of the raw `FunctionException` toString.
  static Future<FunctionResponse> _invoke(
    String name,
    Map<String, dynamic> body,
  ) async {
    try {
      final resp = await _supa.functions.invoke(name, body: body);
      if (resp.status != 200) {
        throw Exception('$name failed (${resp.status}): ${resp.data}');
      }
      return resp;
    } on FunctionException catch (e) {
      if (e.status == 401 || e.status == 403) {
        throw Exception(
          "Couldn't reach the exam service — please check your connection "
          'and try again. (If this keeps happening, the server may need a '
          'redeploy.)',
        );
      }
      throw Exception('$name failed (${e.status}): ${e.details}');
    }
  }

  /// Lists this teacher's sessions, most recent first.
  static Future<List<ExamSession>> fetchTeacherSessions(String teacherId) async {
    final rows = await _supa
        .from('exam_sessions')
        .select()
        .eq('teacher_id', teacherId)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(ExamSession.fromMap)
        .toList();
  }

  /// Fetches a single session by id.
  static Future<ExamSession?> fetchSession(String sessionId) async {
    final row = await _supa
        .from('exam_sessions')
        .select()
        .eq('id', sessionId)
        .maybeSingle();
    if (row == null) return null;
    return ExamSession.fromMap(row);
  }

  /// Fetches the participant list for a session, joined with profile usernames.
  /// Teachers get all rows (via the `exam_participants_teacher_read` RLS);
  /// students only ever see their own row.
  static Future<List<ExamParticipant>> fetchParticipants(String sessionId) async {
    // Two-step — keeps the query simple and avoids nesting RLS surprises.
    final partRows = await _supa
        .from('exam_participants')
        .select()
        .eq('session_id', sessionId);
    final parts = (partRows as List).cast<Map<String, dynamic>>();
    if (parts.isEmpty) return <ExamParticipant>[];

    final ids = parts.map((p) => p['student_id'] as String).toSet().toList();
    final profileRows = await _supa
        .from('profiles')
        .select('id, username')
        .inFilter('id', ids);
    final nameById = <String, String>{
      for (final p in (profileRows as List).cast<Map<String, dynamic>>())
        p['id'].toString(): (p['username'] ?? '') as String,
    };

    return parts
        .map((p) => ExamParticipant.fromMap(p, username: nameById[p['student_id']]))
        .toList();
  }

  /// Invokes the `start-exam` Edge Function. Flips session to in_progress,
  /// marks joiners as in_progress, marks non-joiners as absent.
  static Future<void> startSession(String sessionId) async {
    await _invoke(
      'start-exam',
      <String, dynamic>{'userId': _userId, 'sessionId': sessionId},
    );
  }

  /// Cancels a still-in-lobby session. No-op if already started.
  static Future<void> cancelSession(String sessionId) async {
    await _supa.from('exam_sessions').update(<String, dynamic>{
      'status': 'cancelled',
      'ended_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', sessionId).eq('status', 'lobby');
  }

  /// Forces a session to `completed` AND marks every still-active
  /// participant as `timed_out` (with their per-student correct/total
  /// counts snapshotted from exam_answers). Wraps the [force_end_exam]
  /// RPC so the flip is atomic — fixes BUG E6 where the End-Now button
  /// promised "students will be marked timed out" but only flipped the
  /// session row, leaving participants stuck in 'in_progress'.
  static Future<void> endSession(String sessionId) async {
    await _supa.rpc(
      'force_end_exam',
      params: <String, dynamic>{'p_session': sessionId},
    );
  }

  // ─── Student flow ─────────────────────────────────────────────────────────

  /// Invokes the `join-exam` Edge Function.
  static Future<Map<String, dynamic>> joinExam(String sessionId) async {
    final resp = await _invoke(
      'join-exam',
      <String, dynamic>{'userId': _userId, 'sessionId': sessionId},
    );
    return Map<String, dynamic>.from(resp.data as Map);
  }

  /// Lists exams the current student has been invited to for their class.
  /// Filters to active sessions (lobby / in_progress). Sorted newest-first.
  static Future<List<ExamSession>> fetchStudentActiveExams(
    String classCode,
  ) async {
    final rows = await _supa
        .from('exam_sessions')
        .select()
        .eq('class_code', classCode)
        .inFilter('status', <String>['lobby', 'in_progress'])
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(ExamSession.fromMap)
        .toList();
  }

  // ─── Realtime ─────────────────────────────────────────────────────────────

  /// Subscribes to participant changes for a session. Every change (insert,
  /// update) triggers a full re-fetch of the participant list to keep
  /// server-side usernames joined correctly.
  static RealtimeChannel subscribeToParticipants(
    String sessionId,
    void Function() onChange,
  ) {
    final channel = _supa
        .channel('exam-participants-$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'exam_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe((status, [error]) {
      if (error != null) {
        debugPrint('exam-participants subscribe error: $error');
      }
    });
    return channel;
  }

  /// Subscribes to the single `exam_sessions` row so teacher / student see
  /// status transitions (lobby → in_progress → completed) live.
  static RealtimeChannel subscribeToSession(
    String sessionId,
    void Function(ExamSession updated) onChange,
  ) {
    final channel = _supa
        .channel('exam-session-$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'exam_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: sessionId,
          ),
          callback: (payload) {
            try {
              onChange(ExamSession.fromMap(payload.newRecord));
            } catch (e, s) {
              debugPrint('exam-session decode failed: $e\n$s');
            }
          },
        )
        .subscribe((status, [error]) {
      if (error != null) {
        debugPrint('exam-session subscribe error: $error');
      }
    });
    return channel;
  }

  // ─── Exam runner (student in-progress) ──────────────────────────────

  /// Student path: returns the safe column subset (id, order_index, prompt,
  /// options) for the exam runner. Calls the SECURITY DEFINER RPC introduced
  /// in migration 015; that RPC verifies the caller is a participant. The
  /// `correct_answer` field is intentionally NOT returned to students —
  /// grading happens via the `submit-answer` Edge Function (BUG C3 fix).
  static Future<List<Map<String, dynamic>>> fetchStudentQuestions(
    String sessionId,
  ) async {
    final result = await _supa.rpc(
      'get_student_exam_questions',
      params: <String, dynamic>{
        'p_session': sessionId,
        'p_student': _userId,
      },
    );
    return (result as List).cast<Map<String, dynamic>>();
  }

  /// Teacher path: returns ALL columns (including correct_answer) for the
  /// teacher's results screen, where the answer key is needed to render
  /// "the correct answer was X". Calls a SECURITY DEFINER RPC that checks
  /// the caller is flagged is_teacher AND owns the session. Direct
  /// SELECT on exam_questions is now revoked from anon, authenticated
  /// (BUG C3 fix).
  static Future<List<Map<String, dynamic>>> fetchTeacherQuestions(
    String sessionId,
  ) async {
    final result = await _supa.rpc(
      'get_teacher_exam_questions',
      params: <String, dynamic>{
        'p_session': sessionId,
        'p_teacher': _userId,
      },
    );
    return (result as List).cast<Map<String, dynamic>>();
  }

  /// Backwards-compatible alias — kept so any third-party integration
  /// continues to work, but new code MUST use [fetchStudentQuestions] or
  /// [fetchTeacherQuestions] explicitly.
  @Deprecated('Use fetchStudentQuestions / fetchTeacherQuestions')
  static Future<List<Map<String, dynamic>>> fetchQuestions(
    String sessionId,
  ) =>
      fetchTeacherQuestions(sessionId);

  /// Post-exam review for a student: returns prompt + correct_answer +
  /// my_answer + is_correct for every question this student submitted.
  /// Calls the SECURITY DEFINER RPC introduced in migration 015 — the
  /// function only returns rows from `exam_answers` belonging to the
  /// caller, so a student can only see the answer key for their own
  /// attempts (BUG C3).
  static Future<List<Map<String, dynamic>>> fetchStudentReview(
    String sessionId,
  ) async {
    final result = await _supa.rpc(
      'get_student_exam_review',
      params: <String, dynamic>{
        'p_session': sessionId,
        'p_student': _userId,
      },
    );
    return (result as List).cast<Map<String, dynamic>>();
  }

  /// Fetches already-submitted answers for this student in a session.
  /// Used on reconnect to resume from the last unanswered question.
  static Future<List<Map<String, dynamic>>> fetchMyAnswers(
    String sessionId,
  ) async {
    final rows = await _supa
        .from('exam_answers')
        .select('question_id, order_index, answer, is_correct')
        .eq('session_id', sessionId)
        .eq('student_id', _userId)
        .order('order_index');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Fetches the participant row for this student in a session.
  static Future<Map<String, dynamic>?> fetchMyParticipation(
    String sessionId,
  ) async {
    final row = await _supa
        .from('exam_participants')
        .select()
        .eq('session_id', sessionId)
        .eq('student_id', _userId)
        .maybeSingle();
    return row;
  }

  /// Submits an answer via the `submit-answer` Edge Function.
  /// Returns the server's grading response.
  static Future<Map<String, dynamic>> submitAnswer({
    required String sessionId,
    required String questionId,
    required String answer,
    required int secondsTaken,
  }) async {
    final resp = await _invoke(
      'submit-answer',
      <String, dynamic>{
        'userId': _userId,
        'sessionId': sessionId,
        'questionId': questionId,
        'answer': answer,
        'secondsTaken': secondsTaken,
      },
    );
    return Map<String, dynamic>.from(resp.data as Map);
  }

  /// Fetches ALL answers for a session (teacher-only via RLS).
  /// Used by the live progress grid to show per-student answer counts.
  static Future<List<Map<String, dynamic>>> fetchAllAnswers(
    String sessionId,
  ) async {
    final rows = await _supa
        .from('exam_answers')
        .select('student_id, question_id, is_correct, order_index')
        .eq('session_id', sessionId)
        .order('order_index');
    return (rows as List).cast<Map<String, dynamic>>();
  }
}
