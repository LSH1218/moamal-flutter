import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:moamal/models/group.dart';
import 'package:moamal/models/idea.dart';
import 'package:moamal/models/meeting_report.dart';
import 'package:moamal/models/participant.dart';
import 'package:moamal/models/session_state.dart';
import 'package:moamal/services/report_pdf_exporter.dart';

// 실제 앱은 PdfGoogleFonts로 네트워크에서 한글 폰트를 받아오지만, 테스트는
// 네트워크에 기대지 않도록 pdf 패키지 내장 폰트로 주입한다 — 한글 렌더링
// 검증이 목적이 아니라 조인·구조 생성 로직 검증이 목적이다.
Future<pw.Font> _testFont() async => pw.Font.helvetica();

SessionState _session({
  List<Idea> ideas = const [],
  List<Participant> participants = const [],
  Map<String, String> votes = const {},
}) =>
    SessionState(
      sessionCode: 'ABC123',
      title: '테스트 세션',
      voteOpen: false,
      ideas: ideas,
      votes: votes,
      participants: participants,
    );

void main() {
  test('report가 null이어도 학생별 기록만으로 PDF bytes를 생성한다', () async {
    final bytes = await buildReportPdf(
      session: _session(participants: [
        Participant(
            uid: 'u1', number: 1, name: '김철수', joinedAt: DateTime(2026, 9, 4)),
      ]),
      report: null,
      groups: const [],
      regularFontLoader: _testFont,
      boldFontLoader: _testFont,
    );
    expect(bytes, isNotEmpty);
    // PDF 매직 넘버
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('report·참석자·투표가 모두 있어도 예외 없이 생성된다', () async {
    final bytes = await buildReportPdf(
      session: _session(
        ideas: [
          Idea(id: 'i1', speaker: '학생', text: '발언1', source: 'stt', authorUid: 'u1'),
        ],
        participants: [
          Participant(
              uid: 'u1', number: 1, name: '김철수', joinedAt: DateTime(2026, 9, 4)),
          Participant(
              uid: 'u2',
              number: 2,
              name: '이영희',
              joinedAt: DateTime(2026, 9, 4),
              leftAt: DateTime(2026, 9, 4, 10)),
        ],
        votes: {'u1': 'g1'},
      ),
      report: const MeetingReport(
        overview: '흐름 요약',
        groups: [
          GroupSummary(title: '소풍 장소', ideaCount: 1, votes: 1, keyQuote: '인용문')
        ],
        voteSummary: '투표 요약',
        conclusion: '결론',
        nextAction: '후속 조치',
        unresolved: '미결 쟁점',
      ),
      groups: [
        Group(id: 'g1', ideas: const [], aiTitle: '소풍 장소'),
      ],
      regularFontLoader: _testFont,
      boldFontLoader: _testFont,
    );
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
