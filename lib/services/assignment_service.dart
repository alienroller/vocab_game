import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/assignment.dart';
import '../models/assignment_progress.dart';

class AssignmentService {
  static final _supabase = Supabase.instance.client;

  // ─── TEACHER METHODS ───────────────────────────────────────────────────────

  /// Creates a new assignment for a class.
  /// Returns the created Assignment with its Supabase-generated id.
  /// Throws PostgrestException on failure.
  static Future<Assignment> createAssignment({
    required String classCode,
    required String teacherId,
    required String bookId,
    required String bookTitle,
    required String unitId,
    required String unitTitle,
    required int wordCount,
    String? dueDate, // 'YYYY-MM-DD' or null
  }) async {
    final data = await _supabase
        .from('assignments')
        .insert({
          'class_code': classCode,
          'teacher_id': teacherId,
          'book_id': bookId,
          'book_title': bookTitle,
          'unit_id': unitId,
          'unit_title': unitTitle,
          'word_count': wordCount,
          'due_date': dueDate,
          'is_active': true,
        })
        .select()
        .single();
    return Assignment.fromMap(data);
  }

  /// Deactivates an assignment (soft delete — students no longer see it).
  /// Only the teacher who created it should call this (verified by RLS).
  static Future<void> deactivateAssignment(String assignmentId) async {
    await _supabase
        .from('assignments')
        .update({'is_active': false})
        .eq('id', assignmentId);
  }

  /// Gets all active assignments created by this teacher for their class.
  /// Returns newest first.
  static Future<List<Assignment>> getTeacherAssignments({
    required String classCode,
    required String teacherId,
  }) async {
    final data = await _supabase
        .from('assignments')
        .select()
        .eq('class_code', classCode)
        .eq('teacher_id', teacherId)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Assignment.fromMap(e)).toList();
  }

  /// Gets the assignment completion summary for a given assignment.
  /// Returns: how many students have completed it, total students in class.
  /// Used by teacher analytics to show "11/18 students completed Unit 3".
  static Future<Map<String, int>> getAssignmentCompletionSummary({
    required String assignmentId,
    required String classCode,
  }) async {
    // Count total students in class (excluding teacher)
    final totalData = await _supabase
        .from('profiles')
        .select('id')
        .eq('class_code', classCode)
        .eq('is_teacher', false);
    final totalStudents = (totalData as List).length;

    // Count completed progress rows for this assignment
    final completedData = await _supabase
        .from('assignment_progress')
        .select('id')
        .eq('assignment_id', assignmentId)
        .eq('is_completed', true);
    final completedCount = (completedData as List).length;

    return {
      'completed': completedCount,
      'total': totalStudents,
    };
  }

  /// Gets per-student progress for a specific assignment.
  /// Returns list of maps: {student_id, username, words_mastered, total_words, is_completed}
  /// Used for individual assignment analytics.
  static Future<List<Map<String, dynamic>>> getAssignmentStudentProgress({
    required String assignmentId,
  }) async {
    // Join assignment_progress with profiles to get username
    final data = await _supabase
        .from('assignment_progress')
        .select('student_id, words_mastered, total_words, is_completed, last_practiced_at, profiles(username)')
        .eq('assignment_id', assignmentId);
    return List<Map<String, dynamic>>.from(data as List);
  }

  // ─── STUDENT METHODS ───────────────────────────────────────────────────────

  /// Gets all active assignments for the student's class.
  /// Called on student home screen load.
  static Future<List<Assignment>> getStudentAssignments({
    required String classCode,
  }) async {
    final data = await _supabase
        .from('assignments')
        .select()
        .eq('class_code', classCode)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Assignment.fromMap(e)).toList();
  }

  /// Gets this student's progress on all assignments in their class.
  /// Returns a map of assignmentId -> AssignmentProgress.
  /// If no progress row exists for an assignment, that assignment is not in the map.
  static Future<Map<String, AssignmentProgress>> getStudentProgressMap({
    required String studentId,
  }) async {
    final data = await _supabase
        .from('assignment_progress')
        .select()
        .eq('student_id', studentId);
    final list = (data as List).map((e) => AssignmentProgress.fromMap(e));
    return {for (var p in list) p.assignmentId: p};
  }

  /// Creates or updates a student's progress row for an assignment.
  /// Called from AssignmentModeGame when a session ends.
  ///
  /// Parameters:
  /// - assignmentId: the UUID of the assignment
  /// - studentId: the student's profile UUID
  /// - classCode: the student's class_code (denormalized for analytics)
  /// - wordsMasteredDelta: how many additional words were mastered this session
  /// - totalWords: total words in the assignment (needed if creating new row)
  static Future<void> updateAssignmentProgress({
    required String assignmentId,
    required String studentId,
    required String classCode,
    required int wordsMasteredDelta,
  }) async {
    // Fetch true total words dynamically from assignments table
    final assignmentData = await _supabase
        .from('assignments')
        .select('word_count')
        .eq('id', assignmentId)
        .single();
    final realTotalWords = assignmentData['word_count'] as int;

    // Check if a progress row already exists
    final existing = await _supabase
        .from('assignment_progress')
        .select()
        .eq('assignment_id', assignmentId)
        .eq('student_id', studentId)
        .maybeSingle();

    if (existing == null) {
      // First time this student practices this assignment — create row
      final newMastered = wordsMasteredDelta.clamp(0, realTotalWords);
      await _supabase.from('assignment_progress').insert({
        'assignment_id': assignmentId,
        'student_id': studentId,
        'class_code': classCode,
        'words_mastered': newMastered,
        'total_words': realTotalWords,
        'is_completed': newMastered >= realTotalWords,
        'last_practiced_at': DateTime.now().toIso8601String(),
      });
    } else {
      // Row exists — increment words_mastered, cap at total_words
      final currentMastered = existing['words_mastered'] as int;
      final newMastered = (currentMastered + wordsMasteredDelta).clamp(0, realTotalWords);
      await _supabase
          .from('assignment_progress')
          .update({
            'words_mastered': newMastered,
            'is_completed': newMastered >= realTotalWords,
            'last_practiced_at': DateTime.now().toIso8601String(),
          })
          .eq('id', existing['id'] as String);
    }
  }
}
