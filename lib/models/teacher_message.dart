class TeacherMessage {
  final String classCode;
  final String message;
  final DateTime updatedAt;

  const TeacherMessage({
    required this.classCode,
    required this.message,
    required this.updatedAt,
  });

  factory TeacherMessage.fromMap(Map<String, dynamic> map) {
    return TeacherMessage(
      classCode: map['class_code'] as String,
      message: map['message'] as String,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
