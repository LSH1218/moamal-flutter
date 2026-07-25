import 'package:cloud_firestore/cloud_firestore.dart';

class Participant {
  final String uid;
  final int number;
  final String name;
  final DateTime joinedAt;

  const Participant({
    required this.uid,
    required this.number,
    required this.name,
    required this.joinedAt,
  });

  // 교사 화면·의견 발표자 표시용: "3번 김철수"
  String get displayName => '$number번 $name';

  factory Participant.fromFirestore(String uid, Map<String, dynamic> data) {
    return Participant(
      uid: uid,
      number: data['number'] as int? ?? 0,
      name: data['name'] as String? ?? '',
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'number': number,
        'name': name,
        'joinedAt': Timestamp.fromDate(joinedAt),
      };
}
