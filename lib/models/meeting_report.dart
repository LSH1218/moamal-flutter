import 'idea.dart';
import 'participant.dart';

class GroupSummary {
  final String title;
  final int ideaCount;
  final int votes;
  final String keyQuote;

  const GroupSummary({
    required this.title,
    required this.ideaCount,
    required this.votes,
    required this.keyQuote,
  });

  factory GroupSummary.fromJson(Map<String, dynamic> j) => GroupSummary(
        title: j['title'] as String? ?? '',
        ideaCount: j['size'] as int? ?? 0,
        votes: j['votes'] as int? ?? 0,
        keyQuote: j['key_quote'] as String? ?? '',
      );
}

class MeetingReport {
  final String overview;
  final List<GroupSummary> groups;
  final String voteSummary;
  final String conclusion;
  final String nextAction;
  final String? unresolved;

  const MeetingReport({
    required this.overview,
    required this.groups,
    required this.voteSummary,
    required this.conclusion,
    required this.nextAction,
    this.unresolved,
  });

  factory MeetingReport.fromJson(Map<String, dynamic> j) {
    final groupsJson = j['groups'] as List<dynamic>? ?? [];
    return MeetingReport(
      overview: j['overview'] as String? ?? '',
      groups: groupsJson
          .map((g) => GroupSummary.fromJson(g as Map<String, dynamic>))
          .toList(),
      voteSummary: j['vote_summary'] as String? ?? '',
      conclusion: j['conclusion'] as String? ?? '',
      nextAction: j['next_action'] as String? ?? '',
      unresolved: j['unresolved'] as String?,
    );
  }

  /// [participants]·[ideas]를 넘기면 `authorUid` 기준으로 조인한
  /// "학생별 발언 기록" 섹션을 덧붙인다 (§8 리포트 기능, 2026-09-04).
  /// [votes]·[groupTitleById]를 함께 넘기면 학생별 투표 여부도 붙는다.
  /// 화면의 `_StudentRecordsPanel`과 같은 조인 규칙을 쓴다.
  String toPlainText(
    String sessionTitle, {
    List<Participant> participants = const [],
    List<Idea> ideas = const [],
    Map<String, String> votes = const {},
    Map<String, String> groupTitleById = const {},
  }) {
    final sb = StringBuffer();
    sb.writeln('■ 학급회의 요약 리포트');
    sb.writeln('주제: $sessionTitle\n');
    sb.writeln('[ 전체 흐름 ]\n$overview\n');
    sb.writeln('[ 의견 묶음 ]');
    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      sb.write('${i + 1}. ${g.title} (발언 ${g.ideaCount}건');
      if (g.votes > 0) sb.write(' · ${g.votes}표');
      sb.writeln(')');
      if (g.keyQuote.isNotEmpty) sb.writeln('   "${g.keyQuote}"');
    }
    sb.writeln('\n[ 투표 결과 ]\n$voteSummary\n');
    sb.writeln('[ 결론 ]\n$conclusion\n');
    if (unresolved != null) sb.writeln('[ 미결 쟁점 ]\n$unresolved\n');
    sb.writeln('[ 교사 후속 조치 ]\n$nextAction');

    if (participants.isNotEmpty) {
      final byUid = <String, List<Idea>>{};
      for (final idea in ideas) {
        final uid = idea.authorUid;
        if (uid == null) continue;
        byUid.putIfAbsent(uid, () => []).add(idea);
      }
      final sorted = [...participants]
        ..sort((a, b) => a.number.compareTo(b.number));
      final activeCount = sorted.where((p) => p.isActive).length;

      sb.writeln('\n[ 참석자 · 학생별 발언 기록 ]');
      sb.writeln(activeCount == sorted.length
          ? '참석 ${sorted.length}명'
          : '참석 ${sorted.length}명 · 종료 시점 접속 $activeCount명');
      for (final p in sorted) {
        final own = byUid[p.uid] ?? const [];
        final voteLabel = votes.containsKey(p.uid)
            ? '투표: ${groupTitleById[votes[p.uid]] ?? "(그룹 정보 없음)"}'
            : '투표 안 함';
        final leftLabel = p.isActive ? '' : ', 이탈함';
        sb.write('${p.displayName} (발언 ${own.length}건, $voteLabel$leftLabel)');
        sb.writeln(own.isEmpty ? '' : ':');
        for (final idea in own) {
          sb.writeln('  · ${idea.text}');
        }
      }
    }

    return sb.toString();
  }
}
