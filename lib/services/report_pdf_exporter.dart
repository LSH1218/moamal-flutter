import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/group.dart';
import '../models/idea.dart';
import '../models/meeting_report.dart';
import '../models/session_state.dart';

/// 리포트를 PDF 파일(bytes)로 만든다 (§8 리포트 기능, 2026-09-04 — "공유"를
/// "내보내기" 중심으로 재정의). 화면(`report_screen.dart`)·`toPlainText()`와
/// 같은 조인 규칙(authorUid ↔ participants, votes ↔ groups)을 그대로 쓴다.
///
/// [fontLoader]는 테스트에서 네트워크 없이 폰트를 대체하기 위한 주입 지점이다.
/// 실제 앱에서는 기본값(`PdfGoogleFonts.notoSansKRRegular/Bold`)이 한글 렌더링을
/// 담당한다 — pdf 패키지 기본 폰트(Helvetica 등)엔 한글 글리프가 없다.
Future<Uint8List> buildReportPdf({
  required SessionState session,
  required MeetingReport? report,
  required List<Group> groups,
  Future<pw.Font> Function()? regularFontLoader,
  Future<pw.Font> Function()? boldFontLoader,
}) async {
  final regular =
      await (regularFontLoader ?? PdfGoogleFonts.notoSansKRRegular)();
  final bold = await (boldFontLoader ?? PdfGoogleFonts.notoSansKRBold)();

  final doc = pw.Document();
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);

  final groupTitleById = {for (final g in groups) g.id: g.displayTitle};
  final byUid = <String, List<Idea>>{};
  for (final idea in session.ideas) {
    final uid = idea.authorUid;
    if (uid == null) continue;
    byUid.putIfAbsent(uid, () => []).add(idea);
  }
  final sortedParticipants = [...session.participants]
    ..sort((a, b) => a.number.compareTo(b.number));
  final activeCount = sortedParticipants.where((p) => p.isActive).length;

  doc.addPage(
    pw.MultiPage(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text('학급회의 요약 리포트',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('주제: ${session.title}',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
        pw.SizedBox(height: 16),
        if (report != null) ..._reportSections(report),
        pw.SizedBox(height: 12),
        pw.Text('참석자 · 학생별 발언 기록',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(
          activeCount == sortedParticipants.length
              ? '참석 ${sortedParticipants.length}명'
              : '참석 ${sortedParticipants.length}명 · 종료 시점 접속 $activeCount명',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 8),
        ...sortedParticipants.map((p) {
          final ideas = byUid[p.uid] ?? const [];
          final voteLabel = session.votes.containsKey(p.uid)
              ? '투표: ${groupTitleById[session.votes[p.uid]] ?? "(그룹 정보 없음)"}'
              : '투표 안 함';
          final leftLabel = p.isActive ? '' : ' · 이탈함';
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${p.displayName}  (발언 ${ideas.length}건, $voteLabel$leftLabel)',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
                if (ideas.isEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Text('발언 없음',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey500)),
                  )
                else
                  ...ideas.map((idea) => pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text('· ${idea.text}',
                            style: const pw.TextStyle(fontSize: 10)),
                      )),
              ],
            ),
          );
        }),
      ],
    ),
  );

  return doc.save();
}

List<pw.Widget> _reportSections(MeetingReport report) {
  pw.Widget section(String title, String body) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(body, style: const pw.TextStyle(fontSize: 10.5)),
          ],
        ),
      );

  return [
    section('전체 흐름', report.overview),
    pw.Text('의견 묶음',
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 2),
    ...report.groups.asMap().entries.map((e) {
      final g = e.value;
      final suffix = g.votes > 0 ? ' · ${g.votes}표' : '';
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('${e.key + 1}. ${g.title} (발언 ${g.ideaCount}건$suffix)',
                style: const pw.TextStyle(fontSize: 10.5)),
            if (g.keyQuote.isNotEmpty)
              pw.Text('   "${g.keyQuote}"',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey700)),
          ],
        ),
      );
    }),
    pw.SizedBox(height: 8),
    section('투표 결과', report.voteSummary),
    section('결론', report.conclusion),
    if (report.unresolved != null) section('미결 쟁점', report.unresolved!),
    section('교사 후속 조치', report.nextAction),
  ];
}
