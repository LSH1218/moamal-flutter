class Idea {
  final String id;
  final String speaker;
  final String text;
  final String source;

  const Idea({
    required this.id,
    required this.speaker,
    required this.text,
    required this.source,
  });

  factory Idea.fromFirestore(String id, Map<String, dynamic> data) {
    return Idea(
      id: id,
      speaker: data['speaker'] as String? ?? '',
      text: data['text'] as String? ?? '',
      source: data['source'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'speaker': speaker,
        'text': text,
        'source': source,
      };
}
