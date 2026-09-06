import '../models/session_state.dart';

/// PDF·CSV 내보내기 파일명의 "제목_날짜" 부분을 만든다(확장자 제외).
/// 세션 코드 대신 교사가 정한 주제를 써서(§8, 2026-09-06 대표 요청) 파일
/// 목록에서 어떤 수업 요약인지 바로 알아볼 수 있게 한다.
///
/// [now]는 테스트에서 날짜를 고정하기 위한 주입 지점 — 생략하면 실제 현재
/// 시각을 쓴다.
String reportExportFileBaseName(SessionState session, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final date = '${today.year}-${today.month.toString().padLeft(2, '0')}-'
      '${today.day.toString().padLeft(2, '0')}';

  final rawTitle = session.title.trim();
  final safeTitle = (rawTitle.isEmpty ? '수업기록' : rawTitle)
      // 파일 시스템(윈도우 포함)에서 못 쓰는 문자 제거
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final title = safeTitle.isEmpty
      ? '수업기록'
      : (safeTitle.length > 40 ? safeTitle.substring(0, 40) : safeTitle);

  return '${title}_$date';
}
