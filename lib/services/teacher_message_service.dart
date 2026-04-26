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
  }) async {
    await _supabase
        .from('teacher_messages')
        .delete()
        .eq('class_code', classCode);
    await _supabase.from('teacher_messages').insert({
      'class_code': classCode,
      'teacher_id': teacherId,
      'message': message.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    });
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
