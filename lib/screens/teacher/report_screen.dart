import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import '../../models/group.dart';
import '../../models/meeting_report.dart';
import '../../models/session_state.dart';
import '../../services/gemini_grouping_engine.dart';
import '../../theme/app_theme.dart';

class ReportScreen extends StatelessWidget {
  final SessionState session;
  final List<Group> groups;
  final GeminiGroupingEngine groupingEngine;
  final String elapsedText;
  final MeetingReport? meetingReport;
  final bool isGeneratingReport;
  final VoidCallback onGenerateReport;

  const ReportScreen({
    super.key,
    required this.session,
    required this.groups,
    required this.groupingEngine,
    required this.elapsedText,
    required this.meetingReport,
    required this.isGeneratingReport,
    required this.onGenerateReport,
  });

  String get _dateLabel {
    final now = DateTime.now();
    return '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
  }

  void _share() {
    final text =
        meetingReport?.toPlainText(session.title) ?? '아직 리포트가 없습니다.';
    share_plus.Share.share(text, subject: '모아말 수업기록 ${session.sessionCode}');
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;

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
              onTap: _share,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: kYellow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '저장 / 공유',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: kInk,
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
              groups: groups,
              groupingEngine: groupingEngine,
              elapsedText: elapsedText,
              meetingReport: meetingReport,
              isGenerating: isGeneratingReport,
              onGenerate: onGenerateReport,
              onShare: _share,
            )
          : _MediumBody(
              session: session,
              groups: groups,
              groupingEngine: groupingEngine,
              elapsedText: elapsedText,
              meetingReport: meetingReport,
              isGenerating: isGeneratingReport,
              onGenerate: onGenerateReport,
              onShare: _share,
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
  final VoidCallback onShare;

  const _CompactBody({
    required this.session,
    required this.groups,
    required this.groupingEngine,
    required this.elapsedText,
    required this.meetingReport,
    required this.isGenerating,
    required this.onGenerate,
    required this.onShare,
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
        // 하단 CTA
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          child: _YellowCta(
            label: '리포트 저장 / 공유 ↗',
            onTap: onShare,
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
  final VoidCallback onShare;

  const _MediumBody({
    required this.session,
    required this.groups,
    required this.groupingEngine,
    required this.elapsedText,
    required this.meetingReport,
    required this.isGenerating,
    required this.onGenerate,
    required this.onShare,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: _YellowCta(
                  label: 'PDF 내보내기 / 학교 시스템 연동',
                  onTap: onShare,
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
          OutlinedButton(
            onPressed: isGenerating ? null : onGenerate,
            child: Text(isGenerating ? '생성 중...' : 'AI 요약 다시 생성'),
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
  final VoidCallback onTap;

  const _YellowCta({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: kYellow,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: kInk,
          ),
        ),
      ),
    );
  }
}
