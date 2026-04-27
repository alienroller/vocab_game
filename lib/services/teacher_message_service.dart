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
  /// "Pin to all my classes" — one round-trip per class is fine for the
  /// teacher's class limit (5).
  static Future<void> setMessageForClasses({
    required List<String> classCodes,
    required String teacherId,
    required String message,
  }) async {
    if (classCodes.isEmpty) return;
    final trimmed = message.trim();
    final now = DateTime.now().toIso8601String();
    for (final code in classCodes) {
      await _supabase
          .from('teacher_messages')
          .delete()
          .eq('class_code', code);
      await _supabase.from('teacher_messages').insert({
        'class_code': code,
        'teacher_id': teacherId,
        'message': trimmed,
        'updated_at': now,
      });
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
