import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moamal/models/participant.dart';
import 'package:moamal/models/session_state.dart';

Participant _p(String uid, int number, {DateTime? leftAt}) => Participant(
      uid: uid,
      number: number,
      name: '학생$number',
      joinedAt: DateTime(2026, 8, 26),
      leftAt: leftAt,
    );

void main() {
  group('Participant.leftAt (Gemini-1-Exit-01)', () {
    test('leftAt이 없으면 접속 중', () {
      expect(_p('u1', 1).isActive, isTrue);
    });

    test('leftAt이 있으면 퇴장', () {
      expect(_p('u1', 1, leftAt: DateTime(2026, 8, 26, 10)).isActive, isFalse);
    });

    test('toFirestore는 leftAt: null을 포함한다 — 재입장 시 merge set으로 퇴장 해제', () {
      expect(_p('u1', 1).toFirestore().containsKey('leftAt'), isTrue);
      expect(_p('u1', 1).toFirestore()['leftAt'], isNull);
    });

    test('fromFirestore가 leftAt Timestamp를 읽는다', () {
      final p = Participant.fromFirestore('u1', {
        'number': 3,
        'name': '김철수',
        'joinedAt': Timestamp.fromDate(DateTime(2026, 8, 26)),
        'leftAt': Timestamp.fromDate(DateTime(2026, 8, 26, 10)),
      });
      expect(p.isActive, isFalse);
      expect(p.displayName, '3번 김철수');
    });
  });

  group('SessionState 라이프사이클', () {
    SessionState base(List<Participant> ps, {DateTime? endedAt}) => SessionState(
          sessionCode: 'ABC123',
          title: '테스트',
          voteOpen: false,
          ideas: const [],
          votes: const {},
          participants: ps,
          endedAt: endedAt,
        );

    test('activeParticipants는 접속 중만, participants는 누적 전체', () {
      final s = base([
        _p('u1', 1),
        _p('u2', 2, leftAt: DateTime(2026, 8, 26, 10)),
        _p('u3', 3),
      ]);
      expect(s.participants.length, 3);
      expect(s.activeParticipants.length, 2);
      expect(s.activeParticipants.map((p) => p.uid), ['u1', 'u3']);
    });

    test('endedAt이 있으면 isEnded (Gemini-1-Exit-03)', () {
      expect(base(const []).isEnded, isFalse);
      expect(base(const [], endedAt: DateTime(2026, 8, 26)).isEnded, isTrue);
    });
  });
}
