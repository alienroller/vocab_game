/// A class owned by a teacher — the row-level view of the `classes` table,
/// enriched with the current student count.
class TeacherClass {
  final String code;
  final String className;
  final String teacherId;
  final String teacherUsername;
  final int studentCount;
  final DateTime createdAt;

  const TeacherClass({
    required this.code,
    required this.className,
    required this.teacherId,
    required this.teacherUsername,
    required this.studentCount,
    required this.createdAt,
  });

  factory TeacherClass.fromMap(Map<String, dynamic> map, {required int studentCount}) {
    return TeacherClass(
      code: map['code'] as String,
      className: (map['class_name'] as String?) ?? '',
      teacherId: (map['teacher_id'] as String?) ?? '',
      teacherUsername: (map['teacher_username'] as String?) ?? '',
      studentCount: studentCount,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ?? DateTime.now(),
    );
  }
}
