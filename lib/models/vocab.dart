class Vocab {
  final String id;
  final String english;
  final String uzbek;

  Vocab({
    required this.id,
    required this.english,
    required this.uzbek,
  });

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
