import 'package:flutter_test/flutter_test.dart';
import 'package:moamal/models/idea.dart';
import 'package:moamal/models/meeting_report.dart';
import 'package:moamal/models/participant.dart';

Participant _p(String uid, int number, String name, {DateTime? leftAt}) =>
    Participant(
      uid: uid,
      number: number,
      name: name,
      joinedAt: DateTime(2026, 9, 4),
      leftAt: leftAt,
    );

Idea _idea(String id, String text, {String? authorUid}) => Idea(
      id: id,
      speaker: '학생',
      text: text,
      source: 'stt',
      authorUid: authorUid,
    );

MeetingReport _report() => const MeetingReport(
      overview: '전체 흐름',
      groups: [],
      voteSummary: '투표 요약',
      conclusion: '결론',
      nextAction: '후속 조치',
    );

void main() {
  group('Idea.authorUid (§8 리포트 기능, 2026-09-04)', () {
    test('fromFirestore가 authorUid를 읽는다', () {
      final idea = Idea.fromFirestore('i1', {
        'speaker': '학생',
        'text': '내용',
        'source': 'stt',
        'authorUid': 'u1',
      });
      expect(idea.authorUid, 'u1');
    });

    test('authorUid 없는 구버전 문서는 null', () {
      final idea = Idea.fromFirestore('i1', {'speaker': '학생', 'text': '내용'});
      expect(idea.authorUid, isNull);
    });
  });

  group('MeetingReport.toPlainText 학생별 발언 기록', () {
    test('participants를 안 넘기면 학생별 섹션이 없다 (하위 호환)', () {
      final text = _report().toPlainText('테스트 세션');
      expect(text.contains('[ 참석자 · 학생별 발언 기록 ]'), isFalse);
    });

    test('participants를 넘기면 번호순으로 발언이 귀속된다', () {
      final text = _report().toPlainText(
        '테스트 세션',
        participants: [
          _p('u2', 2, '이영희'),
          _p('u1', 1, '김철수'),
        ],
        ideas: [
          _idea('i1', '첫 번째 발언', authorUid: 'u1'),
          _idea('i2', '두 번째 발언', authorUid: 'u2'),
          _idea('i3', '세 번째 발언', authorUid: 'u1'),
        ],
      );

      expect(text.contains('[ 참석자 · 학생별 발언 기록 ]'), isTrue);
      // 번호순(1번 먼저)이므로 김철수가 이영희보다 앞선다.
      expect(
        text.indexOf('1번 김철수'),
        lessThan(text.indexOf('2번 이영희')),
      );
      expect(text.contains('1번 김철수 (발언 2건, 투표 안 함):'), isTrue);
      expect(text.contains('· 첫 번째 발언'), isTrue);
      expect(text.contains('· 세 번째 발언'), isTrue);
      expect(text.contains('2번 이영희 (발언 1건, 투표 안 함):'), isTrue);
    });

    test('발언 없는 학생도 0건으로 표시된다', () {
      final text = _report().toPlainText(
        '테스트',
        participants: [_p('u1', 1, '김철수')],
        ideas: const [],
      );
      expect(text.contains('1번 김철수 (발언 0건, 투표 안 함)'), isTrue);
    });

    test('authorUid 없는(구버전) 발언은 특정 학생에게 붙지 않는다', () {
      final text = _report().toPlainText(
        '테스트',
        participants: [_p('u1', 1, '김철수')],
        ideas: [_idea('i1', '작성자 미상 발언')],
      );
      expect(text.contains('1번 김철수 (발언 0건, 투표 안 함)'), isTrue);
      expect(text.contains('작성자 미상 발언'), isFalse);
    });

    test('votes·groupTitleById를 넘기면 투표 여부·대상이 표시된다', () {
      final text = _report().toPlainText(
        '테스트',
        participants: [_p('u1', 1, '김철수'), _p('u2', 2, '이영희')],
        ideas: const [],
        votes: {'u1': 'g1'},
        groupTitleById: {'g1': '소풍 장소'},
      );
      expect(text.contains('1번 김철수 (발언 0건, 투표: 소풍 장소)'), isTrue);
      expect(text.contains('2번 이영희 (발언 0건, 투표 안 함)'), isTrue);
    });

    test('투표 기록은 있는데 그룹 제목을 못 찾으면 안내 문구로 대체된다', () {
      final text = _report().toPlainText(
        '테스트',
        participants: [_p('u1', 1, '김철수')],
        ideas: const [],
        votes: {'u1': 'deleted-group'},
        groupTitleById: const {},
      );
      expect(text.contains('투표: (그룹 정보 없음)'), isTrue);
    });

    test('전원 접속 중이면 인원수만 표시된다', () {
      final text = _report().toPlainText(
        '테스트',
        participants: [_p('u1', 1, '김철수'), _p('u2', 2, '이영희')],
        ideas: const [],
      );
      expect(text.contains('참석 2명\n'), isTrue);
      expect(text.contains('현재 접속'), isFalse);
    });

    test('이탈한 학생이 있으면 참석/접속 인원이 나뉘고 개별 표시도 붙는다', () {
      final text = _report().toPlainText(
        '테스트',
        participants: [
          _p('u1', 1, '김철수'),
          _p('u2', 2, '이영희', leftAt: DateTime(2026, 9, 4, 10)),
        ],
        ideas: const [],
      );
      expect(text.contains('참석 2명 · 종료 시점 접속 1명'), isTrue);
      expect(text.contains('1번 김철수 (발언 0건, 투표 안 함)'), isTrue);
      expect(text.contains('2번 이영희 (발언 0건, 투표 안 함, 이탈함)'), isTrue);
    });
  });
}
