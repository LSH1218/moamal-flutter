import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import '../../models/group.dart';
import '../../models/idea.dart';
import '../../models/meeting_report.dart';
import '../../models/participant.dart';
import '../../models/session_state.dart';
import '../../services/gemini_grouping_engine.dart';
import '../../services/report_csv_exporter.dart';
import '../../services/report_export_naming.dart';
import '../../services/report_pdf_exporter.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

/// 리포트 화면.
///
/// **StatefulWidget인 이유** (Mercury-Report-06): 부모(`TeacherHomeScreen`)의
/// `setState`는 이미 스택에 올라간 이 route를 리빌드하지 못한다. 생성자로 값을
/// 복사받는 구조였을 때 "AI 요약 생성"을 눌러도 화면이 그대로여서 교사에게는
/// 버튼이 고장난 것으로 보였다. 이제 생성 결과를 `onGenerateReport()`의
/// **반환값**으로 직접 받아 자기 상태를 갱신한다.
class ReportScreen extends StatefulWidget {
  /// 화면 진입 시점의 초기값. 이후 값은 [sessionStream]이 갱신한다 —
  /// 리포트를 생성한 뒤에 학생이 투표하면 이 값만으로는 반영되지 않는다
  /// (교사 홈의 `_goToReport()`가 push 시점의 스냅샷을 캐릭터로 넘길 뿐이라
  /// 화면이 살아있는 동안 새로 일어난 투표를 볼 방법이 없었다. 2026-09-04
  /// 대표 발견).
  final SessionState session;

  /// 교사 홈이 만든 broadcast 스트림을 그대로 받는다. **필수** —
  /// `OrganizeScreen`과 같은 이유로 화면이 직접 `listenToSession()`을
  /// 부르면 안 된다(Mercury-3-Student-01, 재구독 발생).
  final Stream<SessionState> sessionStream;

  final List<Group> groups;
  final GeminiGroupingEngine groupingEngine;
  final String elapsedText;
  final MeetingReport? meetingReport;
  final bool isGeneratingReport;
  final Future<MeetingReport?> Function() onGenerateReport;

  /// 실제 수업 종료 (§16). endedAt 기록 + 로컬 복귀 상태 정리까지 담당하며
  /// 화면 이동은 하지 않는다 — 이동은 이 화면이 랜딩까지 popUntil로 처리한다.
  final Future<void> Function() onEndSession;

  const ReportScreen({
    super.key,
    required this.session,
    required this.sessionStream,
    required this.groups,
    required this.groupingEngine,
    required this.elapsedText,
    required this.meetingReport,
    required this.isGeneratingReport,
    required this.onGenerateReport,
    required this.onEndSession,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  MeetingReport? _report;
  late bool _isGenerating;
  bool _isEnding = false;
  bool _isExportingPdf = false;
  bool _isExportingCsv = false;

  /// [widget.session]은 push 시점의 스냅샷일 뿐이라, 화면이 열려 있는 동안
  /// 새로 들어오는 투표·발언을 보려면 이 필드를 스트림으로 계속 갱신해야
  /// 한다(위 [ReportScreen.session] 문서 참조).
  late SessionState _session;
  StreamSubscription<SessionState>? _sessionSub;

  /// [_report]를 생성했을 때의 발언·투표 건수. 이후 [_session]의 건수가
  /// 달라지면 요약이 최신 상태가 아니라는 뜻이다(§8, 2026-09-06 — AI 요약을
  /// 실시간으로 다시 만들면 Gemini 호출이 학생 수만큼 폭증하므로, 대신
  /// "내보내기" 시점에만 오래됐으면 자동으로 다시 만든다).
  int? _reportSnapshotIdeaCount;
  int? _reportSnapshotVoteCount;

  @override
  void initState() {
    super.initState();
    _report = widget.meetingReport;
    _isGenerating = widget.isGeneratingReport;
    _session = widget.session;
    if (_report != null) {
      _reportSnapshotIdeaCount = _session.ideas.length;
      _reportSnapshotVoteCount = _session.votes.length;
    }
    _sessionSub = widget.sessionStream.listen((state) {
      if (mounted) setState(() => _session = state);
    });
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    super.dispose();
  }

  String get _dateLabel {
    final now = DateTime.now();
    return '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _generate() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    final report = await widget.onGenerateReport();
    if (!mounted) return;
    setState(() {
      // 실패 시 null이 오므로 기존 리포트를 지우지 않는다.
      if (report != null) {
        _report = report;
        _reportSnapshotIdeaCount = _session.ideas.length;
        _reportSnapshotVoteCount = _session.votes.length;
      }
      _isGenerating = false;
    });
  }

  /// [_report]가 생성된 뒤 발언·투표가 더 들어왔는지 — 서술형 요약(전체 흐름·
  /// 결론·투표 결과)이 실제 데이터보다 오래됐다는 뜻이다. 학생별 표는 항상
  /// `_session`에서 바로 읽으므로 이 값과 무관하게 이미 최신이다.
  bool get _isReportStale =>
      _report != null &&
      (_session.ideas.length != _reportSnapshotIdeaCount ||
          _session.votes.length != _reportSnapshotVoteCount);

  /// 내보내기 직전에만 오래된 요약을 다시 만든다 — 화면을 보는 동안 계속
  /// 자동 재생성하면 학생 수만큼 Gemini 호출이 늘어나 비용·호출 한도를
  /// 금방 소진한다. "실제로 파일을 남기는 순간"만 정확하면 된다는 판단.
  Future<void> _regenerateIfStale() async {
    if (_isReportStale) await _generate();
  }


  /// [수업 끝내기] — 확인 다이얼로그 → endSession() → 랜딩까지 스택 정리.
  /// 리포트 화면(route 3: 랜딩→교사홈→리포트)에서 곧바로 랜딩으로 빠지므로
  /// 교사홈의 PopScope 경로(뒤로가기→다이얼로그)와 달리 popUntil(isFirst)을 쓴다.
  Future<void> _confirmEndSession() async {
    if (_isEnding) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _EndSessionDialog(),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isEnding = true);
    try {
      await widget.onEndSession();
    } finally {
      // 실패해도 되돌아가지 않고 계속 시도할 수 있게 버튼을 되살린다.
      if (mounted) setState(() => _isEnding = false);
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// "저장/공유" → "내보내기" (§8 리포트 기능, 2026-09-04). PDF 파일을 만들어
  /// 표준 OS 공유 시트로 넘긴다 — 교사가 시트에서 파일로 저장(학교 인트라넷·
  /// 나이스 업로드용)하거나 카톡/문자 등으로 그대로 공유할 수 있다. 텍스트만
  /// 던지던 이전 `_share()`를 대체한다.
  Future<void> _exportPdf() async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);
    try {
      await _regenerateIfStale();
      if (!mounted) return;
      final bytes = await buildReportPdf(
        session: _session,
        report: _report,
        groups: widget.groups,
      );
      if (!mounted) return;
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${reportExportFileBaseName(_session)}.pdf',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF를 만드는 데 실패했어요. 다시 시도해 주세요.')),
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  /// CSV 내보내기 — PDF가 사람이 읽는 회의록이라면 이쪽은 학교 인트라넷·나이스처럼
  /// 표 데이터를 기대하는 곳에 붙여넣기 위한 것(§8, 2026-09-04). `Printing`은
  /// PDF 전용이라 파일을 임시 디렉터리에 직접 써서 `Share.shareXFiles`로 공유
  /// 시트를 띄운다 — PDF와 마찬가지로 저장(인트라넷용)·카톡 등 공유 겸용.
  Future<void> _exportCsv() async {
    if (_isExportingCsv) return;
    setState(() => _isExportingCsv = true);
    try {
      // CSV는 _report(AI 서술 요약)를 전혀 참조하지 않고 _session·groups만
      // 쓴다 — 둘 다 이미 실시간이라 PDF와 달리 재생성이 필요 없다.
      final csv = buildReportCsv(session: _session, groups: widget.groups);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${reportExportFileBaseName(_session)}.csv');
      await file.writeAsString(csv, encoding: const Utf8Codec());
      if (!mounted) return;
      await share_plus.Share.shareXFiles([share_plus.XFile(file.path)]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV를 만드는 데 실패했어요. 다시 시도해 주세요.')),
      );
    } finally {
      if (mounted) setState(() => _isExportingCsv = false);
    }
  }

  bool get _isExporting => _isExportingPdf || _isExportingCsv;

  /// 내보내기 형식 선택 시트 — PDF(회의록 문서)와 CSV(학생별 표 데이터) 중
  /// 고른다. appbar 퀵액션과 본문 CTA가 공유한다.
  void _showExportSheet() {
    if (_isExporting) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kCardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('내보내기 형식',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined, color: kGreen),
              title: const Text('PDF — 읽는 회의록'),
              subtitle: const Text('학교 인트라넷 업로드·카톡 등 공유용 문서'),
              onTap: () {
                Navigator.pop(sheetContext);
                _exportPdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined, color: kGreen),
              title: const Text('CSV — 학생별 표 데이터'),
              subtitle: const Text('나이스 등 표 형식 시스템에 붙여넣기용'),
              onTap: () {
                Navigator.pop(sheetContext);
                _exportCsv();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = context.isCompact;
    final session = _session;
    final meetingReport = _report;

    return Scaffold(
      backgroundColor: kGround,
      appBar: AppBar(
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '수업 종료 리포트',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${session.title} · $_dateLabel',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: meetingReport != null && !_isExporting
                  ? _showExportSheet
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: meetingReport != null
                      ? kYellow
                      : kInk.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: kInk),
                      )
                    : Text(
                        '내보내기',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: meetingReport != null
                              ? kInk
                              : kInk.withValues(alpha: 0.4),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: isCompact
          ? _CompactBody(
              session: session,
              groups: widget.groups,
              groupingEngine: widget.groupingEngine,
              elapsedText: widget.elapsedText,
              meetingReport: meetingReport,
              isGenerating: _isGenerating,
              onGenerate: _generate,
              onShare: meetingReport != null && !_isExporting
                  ? _showExportSheet
                  : null,
              isExporting: _isExporting,
              onEndSession: _confirmEndSession,
              isEndingSession: _isEnding,
            )
          : _MediumBody(
              session: session,
              groups: widget.groups,
              groupingEngine: widget.groupingEngine,
              elapsedText: widget.elapsedText,
              meetingReport: meetingReport,
              isGenerating: _isGenerating,
              onGenerate: _generate,
              onShare: meetingReport != null && !_isExporting
                  ? _showExportSheet
                  : null,
              isExporting: _isExporting,
              onEndSession: _confirmEndSession,
              isEndingSession: _isEnding,
            ),
    );
  }
}

// ── Compact: 통계 + 주제 리스트 + 저장 버튼 ──────────────────────────────
class _CompactBody extends StatelessWidget {
  final SessionState session;
  final List<Group> groups;
  final GeminiGroupingEngine groupingEngine;
  final String elapsedText;
  final MeetingReport? meetingReport;
  final bool isGenerating;
  final VoidCallback onGenerate;
  final VoidCallback? onShare;
  final bool isExporting;
  final VoidCallback onEndSession;
  final bool isEndingSession;

  const _CompactBody({
    required this.session,
    required this.groups,
    required this.groupingEngine,
    required this.elapsedText,
    required this.meetingReport,
    required this.isGenerating,
    required this.onGenerate,
    required this.onShare,
    required this.isExporting,
    required this.onEndSession,
    required this.isEndingSession,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
            children: [
              _StatRow(
                  session: session, elapsedText: elapsedText),
              const SizedBox(height: 16),
              _TopicsPanel(
                groups: groups,
                groupingEngine: groupingEngine,
                meetingReport: meetingReport,
                isGenerating: isGenerating,
                onGenerate: onGenerate,
              ),
              const SizedBox(height: 20),
              const Text(
                '참석자 · 학생별 발언 기록',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black38,
                ),
              ),
              const SizedBox(height: 12),
              _StudentRecordsPanel(
                participants: session.participants,
                ideas: session.ideas,
                votes: session.votes,
                groups: groups,
              ),
            ],
          ),
        ),
        // 하단 CTA — 저장/공유(kYellow)와 실제 종료(kRed)를 한 눈에 구분되게 별도 줄로 둔다.
        // 레이아웃 배치(간격·정렬)는 UI/UX 방 재검토 필요.
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: _YellowCta(
            label: isExporting ? '내보내는 중...' : '내보내기 / 공유 ↗',
            onTap: onShare,
            isLoading: isExporting,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
          child: _EndSessionCta(
            onTap: onEndSession,
            isLoading: isEndingSession,
          ),
        ),
      ],
    );
  }
}

// ── Medium: 왼쪽(통계+인용) / 오른쪽(AI 주제+내보내기) ─────────────────
class _MediumBody extends StatelessWidget {
  final SessionState session;
  final List<Group> groups;
  final GeminiGroupingEngine groupingEngine;
  final String elapsedText;
  final MeetingReport? meetingReport;
  final bool isGenerating;
  final VoidCallback onGenerate;
  final VoidCallback? onShare;
  final bool isExporting;
  final VoidCallback onEndSession;
  final bool isEndingSession;

  const _MediumBody({
    required this.session,
    required this.groups,
    required this.groupingEngine,
    required this.elapsedText,
    required this.meetingReport,
    required this.isGenerating,
    required this.onGenerate,
    required this.onShare,
    required this.isExporting,
    required this.onEndSession,
    required this.isEndingSession,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 왼쪽: 통계 + 주목 발언
        SizedBox(
          width: w * 0.45,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 24),
            children: [
              _StatRow(session: session, elapsedText: elapsedText),
              const SizedBox(height: 20),
              const Text(
                '주목할 학생 발언',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black38,
                ),
              ),
              const SizedBox(height: 12),
              _QuoteCards(
                  meetingReport: meetingReport, groups: groups),
            ],
          ),
        ),
        Container(width: 1, color: const Color(0xFFE0DDD6)),
        // 오른쪽: AI 요약 주제 + PDF 버튼
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  children: [
                    const Text(
                      '핵심 주제 (AI 요약)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TopicsPanel(
                      groups: groups,
                      groupingEngine: groupingEngine,
                      meetingReport: meetingReport,
                      isGenerating: isGenerating,
                      onGenerate: onGenerate,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '참석자 · 학생별 발언 기록',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StudentRecordsPanel(
                      participants: session.participants,
                      ideas: session.ideas,
                      votes: session.votes,
                      groups: groups,
                    ),
                  ],
                ),
              ),
              // 레이아웃 배치(간격·정렬)는 UI/UX 방 재검토 필요.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: _YellowCta(
                  label: isExporting
                      ? '내보내는 중...'
                      : '내보내기 / 학교 시스템 연동',
                  onTap: onShare,
                  isLoading: isExporting,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: _EndSessionCta(
                  onTap: onEndSession,
                  isLoading: isEndingSession,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 통계 3개 ──────────────────────────────────────────────────────────────
class _StatRow extends StatelessWidget {
  final SessionState session;
  final String elapsedText;

  const _StatRow({required this.session, required this.elapsedText});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(
            // participants(누적 입장자)가 정확한 출석 인원이다. 구 세션 등
            // participants가 비어 있으면(기록 자체가 없던 시절) 기존 근사치로
            // 폴백한다 — 발언·투표 어느 쪽도 안 한 학생이 있으면 실제보다
            // 적게 셀 수 있는 값이라 참석 기록이 있을 땐 쓰지 않는다.
            value:
                '${session.participants.isNotEmpty ? session.participants.length : (session.votes.isNotEmpty ? session.votes.length : session.ideas.length)}명',
            label: '참여'),
        const SizedBox(width: 8),
        _StatChip(value: '${session.ideas.length}개', label: '발언'),
        const SizedBox(width: 8),
        _StatChip(value: elapsedText, label: '수업'),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;

  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kInk,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black38),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 핵심 주제 패널 ────────────────────────────────────────────────────────
class _TopicsPanel extends StatelessWidget {
  final List<Group> groups;
  final GeminiGroupingEngine groupingEngine;
  final MeetingReport? meetingReport;
  final bool isGenerating;
  final VoidCallback onGenerate;

  const _TopicsPanel({
    required this.groups,
    required this.groupingEngine,
    required this.meetingReport,
    required this.isGenerating,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    // AI 리포트가 있으면 리포트의 그룹 사용
    final topics = meetingReport != null
        ? meetingReport!.groups
            .asMap()
            .entries
            .map((e) =>
                '${e.value.title}${e.value.keyQuote.isNotEmpty ? ' → ${e.value.keyQuote}' : ''}')
            .toList()
        : groups
            .asMap()
            .entries
            .map((e) => groupingEngine.makeGroupTitle(e.value))
            .toList();

    if (topics.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '의견이 수집된 후 AI 요약을 생성할 수 있습니다.',
            style: TextStyle(fontSize: 13, color: Colors.black38),
          ),
          const SizedBox(height: 12),
          if (groups.isNotEmpty)
            OutlinedButton(
              onPressed: isGenerating ? null : onGenerate,
              child: Text(isGenerating ? '생성 중...' : 'AI 요약 생성'),
            ),
        ],
      );
    }

    return Column(
      children: [
        ...topics.asMap().entries.map(
          (e) => _TopicItem(index: e.key + 1, text: e.value),
        ),
        if (meetingReport == null && groups.isNotEmpty) ...[
          const SizedBox(height: 12),
          // 이 분기는 meetingReport == null일 때만 렌더링된다 — 즉 아직 한 번도
          // 생성된 적이 없다. "다시 생성"은 실제로 일어난 적 없는 재생성을 암시해
          // Mercury-Report-04로 이어졌다.
          OutlinedButton(
            onPressed: isGenerating ? null : onGenerate,
            child: Text(isGenerating ? '생성 중...' : 'AI 요약 생성'),
          ),
        ],
      ],
    );
  }
}

class _TopicItem extends StatelessWidget {
  final int index;
  final String text;

  const _TopicItem({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 10, top: 1),
            decoration: BoxDecoration(
              color: kGreen,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: kInk, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 학생별 발언 기록 (§8 리포트 기능, 2026-09-04) ───────────────────────────
// participants·ideas는 이미 SessionState로 로드돼 있어 신규 구독 없이
// authorUid ↔ participant uid 조인만으로 구성한다.
class _StudentRecordsPanel extends StatelessWidget {
  final List<Participant> participants;
  final List<Idea> ideas;

  /// participantId → groupId (SessionState.votes, 이미 로드돼 있음 — 교사는
  /// `firestore.rules` `votes/{participantId}`에 `isOwner` 전체 read 권한이
  /// 있어 학생 비밀투표 원칙과 충돌 없이 개인별 투표를 볼 수 있다).
  final Map<String, String> votes;
  final List<Group> groups;

  const _StudentRecordsPanel({
    required this.participants,
    required this.ideas,
    required this.votes,
    required this.groups,
  });

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const Text(
        '학생이 참여하면 이름별 발언 기록이 여기에 표시됩니다.',
        style: TextStyle(fontSize: 13, color: Colors.black38),
      );
    }

    final groupTitleById = {for (final g in groups) g.id: g.displayTitle};

    final sorted = [...participants]
      ..sort((a, b) => a.number.compareTo(b.number));
    final activeCount = sorted.where((p) => p.isActive).length;

    final attributedIds = sorted.map((p) => p.uid).toSet();
    // 표시명("번호번 이름") → uid. authorUid가 참가자와 안 맞을 때만 쓰는 보조
    // 매칭이다 — 실제 학생 제출은 speaker가 항상 '학생' 고정값이라 이 경로를
    // 타지 않고, 데모 시드처럼 speaker에 표시명을 직접 넣은 경우에만 해당된다.
    final uidByDisplayName = {for (final p in sorted) p.displayName: p.uid};

    final byUid = <String, List<Idea>>{};
    var unattributedCount = 0;
    for (final idea in ideas) {
      final uid = idea.authorUid;
      final resolvedUid = (uid != null && attributedIds.contains(uid))
          ? uid
          : uidByDisplayName[idea.speaker];
      if (resolvedUid == null) {
        unattributedCount++;
        continue;
      }
      byUid.putIfAbsent(resolvedUid, () => []).add(idea);
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              activeCount == sorted.length
                  ? '참석 ${sorted.length}명'
                  : '참석 ${sorted.length}명 · 현재 접속 $activeCount명',
              style: const TextStyle(fontSize: 12, color: Colors.black38),
            ),
          ),
        ),
        ...sorted.map(
          (p) => _StudentRecordCard(
            participant: p,
            ideas: byUid[p.uid] ?? const [],
            hasVoted: votes.containsKey(p.uid),
            votedGroupTitle: groupTitleById[votes[p.uid]],
          ),
        ),
        if (unattributedCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '작성자 미상 발언 $unattributedCount건 (구버전 기록)',
              style: const TextStyle(fontSize: 12, color: Colors.black38),
            ),
          ),
      ],
    );
  }
}

class _StudentRecordCard extends StatelessWidget {
  final Participant participant;
  final List<Idea> ideas;

  /// votes 맵에 이 학생의 항목이 있는지 — 투표 여부 자체는 그룹 제목을
  /// 찾을 수 있는지와 무관하게 이걸로 판단한다.
  final bool hasVoted;

  /// 투표한 그룹의 제목. votes엔 있는데 groups에서 못 찾으면(병합·삭제된
  /// 그룹) null — 이 경우도 "투표함"은 맞으므로 hasVoted로만 판단한다.
  final String? votedGroupTitle;

  const _StudentRecordCard({
    required this.participant,
    required this.ideas,
    required this.hasVoted,
    required this.votedGroupTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        participant.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: kInk,
                        ),
                      ),
                    ),
                    if (!participant.isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: kInk.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '이탈함',
                          style: TextStyle(
                              fontSize: 10, color: Colors.black45),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '발언 ${ideas.length}건',
                style: const TextStyle(fontSize: 12, color: Colors.black38),
              ),
            ],
          ),
          if (ideas.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '발언 없음',
                style: TextStyle(fontSize: 13, color: Colors.black26),
              ),
            )
          else
            ...ideas.map(
              (idea) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '· ${idea.text}',
                  style: const TextStyle(fontSize: 13, color: kInk, height: 1.4),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              hasVoted ? '투표: ${votedGroupTitle ?? "(그룹 정보 없음)"}' : '투표 안 함',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: hasVoted ? kGreen : Colors.black26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 주목 발언 인용 카드 ───────────────────────────────────────────────────
class _QuoteCards extends StatelessWidget {
  final MeetingReport? meetingReport;
  final List<Group> groups;

  const _QuoteCards(
      {required this.meetingReport, required this.groups});

  @override
  Widget build(BuildContext context) {
    // AI 리포트 키 인용 사용, 없으면 의견 샘플
    final quotes = <_Quote>[];

    if (meetingReport != null) {
      for (final g in meetingReport!.groups) {
        if (g.keyQuote.isNotEmpty) {
          quotes.add(_Quote(speaker: g.title, text: g.keyQuote));
        }
      }
    } else {
      for (final g in groups) {
        if (g.ideas.isNotEmpty) {
          final idea = g.ideas.first;
          quotes.add(_Quote(speaker: idea.speaker, text: idea.text));
        }
      }
    }

    if (quotes.isEmpty) {
      return const Text(
        '발언이 쌓이면 주목할 인용이 표시됩니다.',
        style: TextStyle(fontSize: 13, color: Colors.black38),
      );
    }

    return Column(
      children: quotes
          .take(2)
          .map((q) => _QuoteCard(quote: q))
          .toList(),
    );
  }
}

class _Quote {
  final String speaker;
  final String text;
  const _Quote({required this.speaker, required this.text});
}

class _QuoteCard extends StatelessWidget {
  final _Quote quote;

  const _QuoteCard({required this.quote});

  @override
  Widget build(BuildContext context) {
    // 면마다 다른 색 Border(left만 kGreen) + borderRadius를 같이 주면
    // paint 단계에서 "A borderRadius can only be given on borders with
    // uniform colors." 예외가 나 카드 전체가 안 보이게 된다
    // (GroupCard와 동일 원인, Gemini-2-Summary-01 참조).
    // 좌측 강조띠를 Stack으로 분리해 우회한다.
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          color: Colors.white,
          child: Stack(
            children: [
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: SizedBox(width: 3, child: ColoredBox(color: kGreen)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quote.speaker,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: kGreen,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '"${quote.text}"',
                      style: const TextStyle(
                          fontSize: 13, color: kInk, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Yellow CTA 버튼 ───────────────────────────────────────────────────────
class _YellowCta extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  const _YellowCta(
      {required this.label, required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: enabled ? kYellow : kInk.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: kInk),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: enabled ? kInk : kInk.withValues(alpha: 0.35),
                ),
              ),
      ),
    );
  }
}

// ── 수업 끝내기 CTA (§16) ─────────────────────────────────────────────────
// kYellow 저장/공유와 대비되는 kRed 아웃라인 — 파괴적 액션임을 시각적으로 분리.
// 배치·간격은 UI/UX 방 재검토 대상.
class _EndSessionCta extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLoading;

  const _EndSessionCta({required this.onTap, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: kCardBg,
          border: Border.all(color: kRed, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: kRed),
              )
            : const Text(
                '수업 끝내기',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: kRed,
                ),
              ),
      ),
    );
  }
}

/// 수업 종료 확인. barrierDismissible: false — 되돌릴 수 없는 액션이라
/// 실수로 바깥을 탭해 닫히면 안 된다 (teacher_home_screen.dart _onWillPop()과 같은 원칙).
class _EndSessionDialog extends StatelessWidget {
  const _EndSessionDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: kRed,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Center(
                    child: Text('!',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '수업을 끝낼까요?',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: kInk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '학생 화면에 종료 안내가 표시되고 더 이상 의견을 낼 수 없어요. 되돌릴 수 없어요.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.65,
                color: kInk.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: kGround,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        '취소',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kInk,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: kRed,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        '수업 끝내기',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
