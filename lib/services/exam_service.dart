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
    final resp = await _supa.functions.invoke(
      'create-exam',
      body: <String, dynamic>{
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
    if (resp.status != 200) {
      throw Exception('create-exam failed (${resp.status}): ${resp.data}');
    }
    final data = resp.data as Map<String, dynamic>;
    return data['sessionId'] as String;
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
    final resp = await _supa.functions.invoke(
      'start-exam',
      body: <String, dynamic>{'userId': _userId, 'sessionId': sessionId},
    );
    if (resp.status != 200) {
      throw Exception('start-exam failed (${resp.status}): ${resp.data}');
    }
  }

  /// Cancels a still-in-lobby session. No-op if already started.
  static Future<void> cancelSession(String sessionId) async {
    await _supa.from('exam_sessions').update(<String, dynamic>{
      'status': 'cancelled',
      'ended_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', sessionId).eq('status', 'lobby');
  }

  /// Forces a session to `completed`. Used by the teacher's End Now button.
  static Future<void> endSession(String sessionId) async {
    await _supa.from('exam_sessions').update(<String, dynamic>{
      'status': 'completed',
      'ended_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', sessionId);
  }

  // ─── Student flow ─────────────────────────────────────────────────────────

  /// Invokes the `join-exam` Edge Function.
  static Future<Map<String, dynamic>> joinExam(String sessionId) async {
    final resp = await _supa.functions.invoke(
      'join-exam',
      body: <String, dynamic>{'userId': _userId, 'sessionId': sessionId},
    );
    if (resp.status != 200) {
      throw Exception('join-exam failed (${resp.status}): ${resp.data}');
    }
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

  /// Fetches all questions for a session, ordered by `order_index`.
  /// The `correct_answer` field is included — the client MUST NOT show it
  /// until after the student submits (or the per-question timer fires).
  /// In a fully hardened setup, correct_answer would be stripped by an
  /// Edge Function; for now, the options array is pre-shuffled server-side.
  static Future<List<Map<String, dynamic>>> fetchQuestions(
    String sessionId,
  ) async {
    final rows = await _supa
        .from('exam_questions')
        .select('id, order_index, prompt, correct_answer, options')
        .eq('session_id', sessionId)
        .order('order_index');
    return (rows as List).cast<Map<String, dynamic>>();
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
    final resp = await _supa.functions.invoke(
      'submit-answer',
      body: <String, dynamic>{
        'userId': _userId,
        'sessionId': sessionId,
        'questionId': questionId,
        'answer': answer,
        'secondsTaken': secondsTaken,
      },
    );
    if (resp.status != 200) {
      throw Exception('submit-answer failed (${resp.status}): ${resp.data}');
    }
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
