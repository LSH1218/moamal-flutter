class Idea {
  final String id;
  final String speaker;
  final String text;
  final String source;

  /// 작성자 UID. 규칙 검증용으로만 기록되던 필드를 리포트의 학생별 발언
  /// 귀속에 재사용한다 (§8 리포트 기능, 2026-09-04). `Common-Rules-01` 이전
  /// 문서는 없을 수 있다.
  final String? authorUid;

  const Idea({
    required this.id,
    required this.speaker,
    required this.text,
    required this.source,
    this.authorUid,
  });

  factory Idea.fromFirestore(String id, Map<String, dynamic> data) {
    return Idea(
      id: id,
      speaker: data['speaker'] as String? ?? '',
      text: data['text'] as String? ?? '',
      source: data['source'] as String? ?? '',
      authorUid: data['authorUid'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'speaker': speaker,
        'text': text,
        'source': source,
      };
}
