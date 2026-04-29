import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/teacher_message.dart';

class TeacherMessageService {
  static final _supabase = Supabase.instance.client;

  /// Posts or updates the teacher's pinned message for their class.
  ///
  /// Implemented as delete-then-insert rather than upsert because some older
  /// databases were created before the `class_code` UNIQUE constraint was
  /// added to the migration, and PostgREST's `onConflict` requires that
  /// constraint to exist. Delete-then-insert works regardless.
  static Future<void> setMessage({
    required String classCode,
    required String teacherId,
    required String message,
  }) =>
      setMessageForClasses(
        classCodes: [classCode],
        teacherId: teacherId,
        message: message,
      );

  /// Sets the same message on multiple classes. Used when a teacher picks
  /// "Pin to all my classes". BUG P3 — old code did a serial DELETE+INSERT
  /// per class (10 round-trips for 5 classes). Now we do one upsert with
  /// onConflict, which the migration 012 unique constraint supports.
  /// Falls back to the delete-then-insert path if upsert errors (older
  /// databases that pre-date the unique constraint).
  static Future<void> setMessageForClasses({
    required List<String> classCodes,
    required String teacherId,
    required String message,
  }) async {
    if (classCodes.isEmpty) return;
    final trimmed = message.trim();
    final now = DateTime.now().toIso8601String();
    final rows = classCodes
        .map((code) => {
              'class_code': code,
              'teacher_id': teacherId,
              'message': trimmed,
              'updated_at': now,
            })
        .toList();
    try {
      await _supabase
          .from('teacher_messages')
          .upsert(rows, onConflict: 'class_code');
      return;
    } catch (_) {
      // Fallback: pre-012 schemas don't have the unique constraint, so
      // upsert won't work. Delete-then-insert per class.
      for (final code in classCodes) {
        await _supabase
            .from('teacher_messages')
            .delete()
            .eq('class_code', code);
      }
      await _supabase.from('teacher_messages').insert(rows);
    }
  }

  /// Removes the teacher's message (students will see no message card).
  static Future<void> deleteMessage(String classCode) async {
    await _supabase
        .from('teacher_messages')
        .delete()
        .eq('class_code', classCode);
  }

  /// Fetches the current message for a class. Returns null if none exists.
  /// Called on student home screen load and teacher dashboard load.
  static Future<TeacherMessage?> getMessage(String classCode) async {
    final data = await _supabase
        .from('teacher_messages')
        .select()
        .eq('class_code', classCode)
        .maybeSingle();
    if (data == null) return null;
    return TeacherMessage.fromMap(data);
  }
}
