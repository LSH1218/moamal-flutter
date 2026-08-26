import 'package:cloud_firestore/cloud_firestore.dart';

class Participant {
  final String uid;
  final int number;
  final String name;
  final DateTime joinedAt;

  /// 학생이 명시적으로 `나가기`를 눌러 퇴장한 시각. null이면 접속 중.
  /// 앱 강제 종료·백그라운드 장기 이탈은 감지하지 못한다 (Gemini-1-Exit-01 한계).
  final DateTime? leftAt;

  const Participant({
    required this.uid,
    required this.number,
    required this.name,
    required this.joinedAt,
    this.leftAt,
  });

  bool get isActive => leftAt == null;

  // 교사 화면·의견 발표자 표시용: "3번 김철수"
  String get displayName => '$number번 $name';

  factory Participant.fromFirestore(String uid, Map<String, dynamic> data) {
    return Participant(
      uid: uid,
      number: data['number'] as int? ?? 0,
      name: data['name'] as String? ?? '',
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      leftAt: (data['leftAt'] as Timestamp?)?.toDate(),
    );
  }

  // leftAt: null을 명시적으로 포함한다 — 재입장 시 merge set만으로 퇴장 표시가 해제된다.
  Map<String, dynamic> toFirestore() => {
        'number': number,
        'name': name,
        'joinedAt': Timestamp.fromDate(joinedAt),
        'leftAt': null,
      };
}
