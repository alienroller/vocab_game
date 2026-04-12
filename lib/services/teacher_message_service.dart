import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/teacher_message.dart';

class TeacherMessageService {
  static final _supabase = Supabase.instance.client;

  /// Posts or updates the teacher's pinned message for their class.
  /// Uses upsert on class_code (there is a UNIQUE constraint on class_code).
  static Future<void> setMessage({
    required String classCode,
    required String teacherId,
    required String message,
  }) async {
    await _supabase.from('teacher_messages').upsert(
      {
        'class_code': classCode,
        'teacher_id': teacherId,
        'message': message.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'class_code',
    );
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
