import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages class creation (teacher) and joining (student).
class ClassService {
  static final _supabase = Supabase.instance.client;

  /// Teacher calls this to create a class.
  /// Returns the unique 6-character class code.
  static Future<String> createClass({
    required String teacherId,
    required String teacherUsername,
    required String className,
  }) async {
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

  /// Gets the class info for a given code.
  static Future<Map<String, dynamic>?> getClassInfo(String code) async {
    return await _supabase
        .from('classes')
        .select()
        .eq('code', code.toUpperCase())
        .maybeSingle();
  }


}
