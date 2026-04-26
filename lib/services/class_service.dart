import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/teacher_class.dart';

/// Error thrown when a teacher tries to create more classes than allowed.
class ClassLimitReachedException implements Exception {
  final int limit;
  const ClassLimitReachedException(this.limit);
  @override
  String toString() =>
      'ClassLimitReachedException: teachers can own at most $limit classes.';
}

/// Error thrown when a teacher tries to delete a class that still has
/// students enrolled. Callers should ask the teacher to remove students
/// first or pick a different class.
class ClassHasStudentsException implements Exception {
  const ClassHasStudentsException();
  @override
  String toString() =>
      'ClassHasStudentsException: cannot delete a class that has students.';
}

/// Manages class creation (teacher) and joining (student).
class ClassService {
  /// Maximum number of classes a single teacher can own.
  static const int maxClassesPerTeacher = 5;

  static final _supabase = Supabase.instance.client;

  /// Teacher calls this to create a class.
  /// Returns the unique 6-character class code.
  ///
  /// Throws [ClassLimitReachedException] if the teacher already owns the
  /// maximum number of classes.
  static Future<String> createClass({
    required String teacherId,
    required String teacherUsername,
    required String className,
  }) async {
    final existing = await _supabase
        .from('classes')
        .select('code')
        .eq('teacher_id', teacherId);
    if (existing.length >= maxClassesPerTeacher) {
      throw const ClassLimitReachedException(maxClassesPerTeacher);
    }

    final code = _generateCode();

    await _supabase.from('classes').insert({
      'code': code,
      'teacher_id': teacherId,
      'teacher_username': teacherUsername,
      'class_name': className,
    });

    return code;
  }

  /// Generates a 6-character uppercase code (no ambiguous chars).
  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Student calls this to join a class by code.
  /// Returns class data if successful, null if code is invalid.
  static Future<Map<String, dynamic>?> joinClass({
    required String profileId,
    required String code,
  }) async {
    final upperCode = code.toUpperCase();

    // Verify the code exists
    final classData = await _supabase
        .from('classes')
        .select()
        .eq('code', upperCode)
        .maybeSingle();

    if (classData == null) return null;

    // Update the student's profile
    await _supabase
        .from('profiles')
        .update({'class_code': upperCode}).eq('id', profileId);

    return classData;
  }

  /// Removes a student from a class by clearing their `class_code`. Called
  /// from the teacher's student detail screen. Does not delete the student's
  /// profile or progress — they keep their XP, streak and word stats and can
  /// rejoin (this class or another) later.
  static Future<void> removeStudentFromClass({
    required String studentId,
    required String classCode,
  }) async {
    await _supabase
        .from('profiles')
        .update({'class_code': null})
        .eq('id', studentId)
        .eq('class_code', classCode)
        .eq('is_teacher', false);
  }

  /// Gets the class info for a given code.
  static Future<Map<String, dynamic>?> getClassInfo(String code) async {
    return await _supabase
        .from('classes')
        .select()
        .eq('code', code.toUpperCase())
        .maybeSingle();
  }

  /// Deletes a class owned by [teacherId]. Fails if the class still has any
  /// students enrolled. Cascades cleanup of class-scoped data that is not
  /// linked by a real foreign key (teacher_messages, assignments, word_stats,
  /// exam_sessions) so no orphan rows remain.
  ///
  /// Throws [ClassHasStudentsException] if students are enrolled.
  static Future<void> deleteClass({
    required String code,
    required String teacherId,
  }) async {
    final upperCode = code.toUpperCase();

    // Defence in depth: re-check that the class is empty server-side.
    final enrolled = await _supabase
        .from('profiles')
        .select('id')
        .eq('class_code', upperCode)
        .limit(1);
    if (List<Map<String, dynamic>>.from(enrolled).isNotEmpty) {
      throw const ClassHasStudentsException();
    }

    // Cascade clean-up — class_code columns are plain TEXT with no FK, so
    // delete children manually before the parent.
    await _supabase.from('teacher_messages').delete().eq('class_code', upperCode);
    await _supabase.from('assignment_progress').delete().eq('class_code', upperCode);
    await _supabase.from('assignments').delete().eq('class_code', upperCode);
    await _supabase.from('word_stats').delete().eq('class_code', upperCode);
    // exam_sessions has ON DELETE CASCADE to exam_questions / exam_participants
    // / exam_answers, so those children are handled for us.
    await _supabase.from('exam_sessions').delete().eq('class_code', upperCode);

    // Finally the class row itself — match on teacher_id too as a safety net.
    await _supabase
        .from('classes')
        .delete()
        .eq('code', upperCode)
        .eq('teacher_id', teacherId);
  }

  /// Fetches all classes owned by a teacher, enriched with student counts.
  /// Returns classes ordered by creation date (oldest first, so the first
  /// class the teacher created stays at the top).
  static Future<List<TeacherClass>> getTeacherClasses(String teacherId) async {
    final rows = await _supabase
        .from('classes')
        .select()
        .eq('teacher_id', teacherId)
        .order('created_at', ascending: true);

    final list = List<Map<String, dynamic>>.from(rows);
    if (list.isEmpty) return const [];

    final codes = list.map((c) => c['code'] as String).toList();

    // Single query fetches all students across all the teacher's classes.
    final students = await _supabase
        .from('profiles')
        .select('class_code')
        .inFilter('class_code', codes);

    final counts = <String, int>{};
    for (final s in List<Map<String, dynamic>>.from(students)) {
      final c = s['class_code'] as String?;
      if (c == null) continue;
      counts[c] = (counts[c] ?? 0) + 1;
    }

    return list
        .map((row) => TeacherClass.fromMap(row, studentCount: counts[row['code']] ?? 0))
        .toList();
  }
}
