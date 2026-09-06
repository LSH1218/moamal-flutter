import 'package:flutter_test/flutter_test.dart';
import 'package:moamal/models/session_state.dart';
import 'package:moamal/services/report_export_naming.dart';

SessionState _session(String title) => SessionState(
      sessionCode: 'ABC123',
      title: title,
      voteOpen: false,
      ideas: const [],
      votes: const {},
    );

void main() {
  final fixedNow = DateTime(2026, 9, 6);

  test('교사가 정한 주제와 날짜로 파일명을 만든다', () {
    final name =
        reportExportFileBaseName(_session('학급회의'), now: fixedNow);
    expect(name, '학급회의_2026-09-06');
  });

  test('세션 코드가 아니라 주제를 쓴다', () {
    final name = reportExportFileBaseName(_session('토론'), now: fixedNow);
    expect(name.contains('ABC123'), isFalse);
    expect(name.startsWith('토론_'), isTrue);
  });

  test('주제가 비어 있으면 "수업기록"으로 대체된다', () {
    final name = reportExportFileBaseName(_session('   '), now: fixedNow);
    expect(name, '수업기록_2026-09-06');
  });

  test('파일 시스템에서 못 쓰는 문자를 제거한다', () {
    final name = reportExportFileBaseName(
      _session('토론: 급식 메뉴? "찬/반*"'),
      now: fixedNow,
    );
    expect(name, '토론 급식 메뉴 찬반_2026-09-06');
  });

  test('연속 공백은 하나로 줄인다', () {
    final name =
        reportExportFileBaseName(_session('학급   회의'), now: fixedNow);
    expect(name, '학급 회의_2026-09-06');
  });

  test('너무 긴 주제는 40자로 잘린다', () {
    final longTitle = '가' * 60;
    final name = reportExportFileBaseName(_session(longTitle), now: fixedNow);
    expect(name, '${'가' * 40}_2026-09-06');
  });

  test('한 자리 월·일도 두 자리로 패딩된다', () {
    final name = reportExportFileBaseName(
      _session('학급회의'),
      now: DateTime(2026, 1, 5),
    );
    expect(name, '학급회의_2026-01-05');
  });
}
