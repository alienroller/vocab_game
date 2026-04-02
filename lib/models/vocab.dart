import 'package:hive/hive.dart';

part 'vocab.g.dart';

@HiveType(typeId: 0)
class Vocab extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String english;

  @HiveField(2)
  final String uzbek;

  Vocab({
    required this.id,
    required this.english,
    required this.uzbek,
  });

  /// Legacy support: create a Vocab from the old Map-based storage format.
  factory Vocab.fromMap(Map<dynamic, dynamic> map) {
    return Vocab(
      id: map['id'] as String,
      english: map['english'] as String,
      uzbek: map['uzbek'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'english': english,
      'uzbek': uzbek,
    };
  }

  Vocab copyWith({
    String? id,
    String? english,
    String? uzbek,
  }) {
    return Vocab(
      id: id ?? this.id,
      english: english ?? this.english,
      uzbek: uzbek ?? this.uzbek,
    );
  }
}
