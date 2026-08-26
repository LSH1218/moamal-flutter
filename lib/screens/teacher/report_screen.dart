import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import '../../models/group.dart';
import '../../models/meeting_report.dart';
import '../../models/session_state.dart';
import '../../services/gemini_grouping_engine.dart';
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
  final SessionState session;
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

  @override
  void initState() {
    super.initState();
    _report = widget.meetingReport;
    _isGenerating = widget.isGeneratingReport;
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
      if (report != null) _report = report;
      _isGenerating = false;
    });
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

  void _share() {
    final text =
        _report?.toPlainText(widget.session.title) ?? '아직 리포트가 없습니다.';
    share_plus.Share.share(text,
        subject: '모아말 수업기록 ${widget.session.sessionCode}');
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = context.isCompact;
    final session = widget.session;
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
              onTap: meetingReport != null ? _share : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: meetingReport != null
                      ? kYellow
                      : kInk.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '저장 / 공유',
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
              onShare: meetingReport != null ? _share : null,
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
              onShare: meetingReport != null ? _share : null,
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
            ],
          ),
        ),
        // 하단 CTA — 저장/공유(kYellow)와 실제 종료(kRed)를 한 눈에 구분되게 별도 줄로 둔다.
        // 레이아웃 배치(간격·정렬)는 UI/UX 방 재검토 필요.
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: _YellowCta(
            label: '리포트 저장 / 공유 ↗',
            onTap: onShare,
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
                  ],
                ),
              ),
              // 레이아웃 배치(간격·정렬)는 UI/UX 방 재검토 필요.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: _YellowCta(
                  label: 'PDF 내보내기 / 학교 시스템 연동',
                  onTap: onShare,
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
            value: '${session.votes.isNotEmpty ? session.votes.length : session.ideas.length}명',
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: kGreen, width: 3)),
      ),
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
            style: const TextStyle(fontSize: 13, color: kInk, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ── Yellow CTA 버튼 ───────────────────────────────────────────────────────
class _YellowCta extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _YellowCta({required this.label, required this.onTap});

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
        child: Text(
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
