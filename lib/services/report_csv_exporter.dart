import 'package:csv/csv.dart';

import '../models/group.dart';
import '../models/idea.dart';
import '../models/session_state.dart';

/// 리포트를 CSV(학생별 참여·발언·투표 표)로 만든다 (§8 리포트 기능,
/// 2026-09-04). PDF가 사람이 읽는 회의록이라면 CSV는 학교 인트라넷·나이스처럼
/// 표 형태 데이터를 기대하는 시스템에 붙여넣기 위한 것 — 그래서 서술형
/// 섹션(전체 흐름·결론 등)은 담지 않고 학생별 행만 담는다. 화면·PDF와 같은
/// 조인 규칙(authorUid ↔ participants, votes ↔ groups)을 그대로 쓴다.
String buildReportCsv({
  required SessionState session,
  required List<Group> groups,
}) {
  final groupTitleById = {for (final g in groups) g.id: g.displayTitle};
  final sorted = [...session.participants]
    ..sort((a, b) => a.number.compareTo(b.number));

  final attributedIds = sorted.map((p) => p.uid).toSet();
  // authorUid가 참가자와 안 맞을 때만 쓰는 보조 매칭(표시명 "번호번 이름"
  // 기준) — report_screen.dart의 _StudentRecordsPanel과 동일 규칙.
  final uidByDisplayName = {for (final p in sorted) p.displayName: p.uid};
  final byUid = <String, List<Idea>>{};
  for (final idea in session.ideas) {
    final uid = idea.authorUid;
    final resolvedUid = (uid != null && attributedIds.contains(uid))
        ? uid
        : uidByDisplayName[idea.speaker];
    if (resolvedUid == null) continue;
    byUid.putIfAbsent(resolvedUid, () => []).add(idea);
  }

  final rows = <List<dynamic>>[
    ['번호', '이름', '참석 상태', '발언 건수', '발언 내용', '투표 여부', '투표 대상'],
  ];
  for (final p in sorted) {
    final ideas = byUid[p.uid] ?? const [];
    final hasVoted = session.votes.containsKey(p.uid);
    rows.add([
      p.number,
      p.name,
      p.isActive ? '접속 중' : '이탈함',
      ideas.length,
      ideas.map((i) => i.text).join(' | '),
      hasVoted ? '투표함' : '투표 안 함',
      hasVoted
          ? (groupTitleById[session.votes[p.uid]] ?? '(그룹 정보 없음)')
          : '',
    ]);
  }

  // addBom: 엑셀에서 한글이 깨지지 않도록 UTF-8 BOM을 앞에 붙인다.
  return Csv(addBom: true).encode(rows);
}
