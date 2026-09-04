import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moamal/models/group.dart';
import 'package:moamal/models/idea.dart';
import 'package:moamal/models/participant.dart';
import 'package:moamal/models/session_state.dart';
import 'package:moamal/services/report_csv_exporter.dart';

Participant _p(String uid, int number, String name, {DateTime? leftAt}) =>
    Participant(
      uid: uid,
      number: number,
      name: name,
      joinedAt: DateTime(2026, 9, 4),
      leftAt: leftAt,
    );

SessionState _session({
  List<Idea> ideas = const [],
  List<Participant> participants = const [],
  Map<String, String> votes = const {},
}) =>
    SessionState(
      sessionCode: 'ABC123',
      title: '테스트',
      voteOpen: false,
      ideas: ideas,
      votes: votes,
      participants: participants,
    );

void main() {
  test('UTF-8 BOM으로 시작해 엑셀에서 한글이 안 깨진다', () {
    final csv = buildReportCsv(session: _session(), groups: const []);
    expect(csv.startsWith('﻿'), isTrue);
  });

  test('헤더와 학생별 행이 번호순으로 들어간다', () {
    final csv = buildReportCsv(
      session: _session(
        participants: [
          _p('u2', 2, '이영희'),
          _p('u1', 1, '김철수'),
        ],
        ideas: [
          Idea(id: 'i1', speaker: '학생', text: '첫 발언', source: 'stt', authorUid: 'u1'),
          Idea(id: 'i2', speaker: '학생', text: '둘째 발언', source: 'stt', authorUid: 'u1'),
        ],
        votes: {'u1': 'g1'},
      ),
      groups: [Group(id: 'g1', ideas: const [], aiTitle: '소풍 장소')],
    );

    final rows = Csv(dynamicTyping: true).decode(csv.replaceFirst('﻿', ''));
    expect(rows[0], ['번호', '이름', '참석 상태', '발언 건수', '발언 내용', '투표 여부', '투표 대상']);
    expect(rows[1], [1, '김철수', '접속 중', 2, '첫 발언 | 둘째 발언', '투표함', '소풍 장소']);
    expect(rows[2], [2, '이영희', '접속 중', 0, '', '투표 안 함', '']);
  });

  test('이탈한 학생은 참석 상태가 "이탈함"으로 표시된다', () {
    final csv = buildReportCsv(
      session: _session(
        participants: [
          _p('u1', 1, '김철수', leftAt: DateTime(2026, 9, 4, 10)),
        ],
      ),
      groups: const [],
    );
    final rows = Csv(dynamicTyping: true).decode(csv.replaceFirst('﻿', ''));
    expect(rows[1][2], '이탈함');
  });

  test('쉼표·줄바꿈이 든 발언도 CSV 왕복이 깨지지 않는다', () {
    final csv = buildReportCsv(
      session: _session(
        participants: [_p('u1', 1, '김철수')],
        ideas: [
          Idea(
              id: 'i1',
              speaker: '학생',
              text: '경복궁, 롯데월드 중\n어디가 좋을까요?',
              source: 'stt',
              authorUid: 'u1'),
        ],
      ),
      groups: const [],
    );
    final rows = Csv(dynamicTyping: true).decode(csv.replaceFirst('﻿', ''));
    expect(rows[1][4], '경복궁, 롯데월드 중\n어디가 좋을까요?');
  });
}
