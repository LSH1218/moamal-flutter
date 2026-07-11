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

  String toPlainText(String sessionTitle) {
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
    return sb.toString();
  }
}
