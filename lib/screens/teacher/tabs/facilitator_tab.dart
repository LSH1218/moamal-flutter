import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import '../../../models/group.dart';
import '../../../models/meeting_report.dart';
import '../../../models/session_state.dart';
import '../../../repositories/firebase_moamal_repository.dart';
import '../../../services/deep_link_service.dart';
import '../../../services/gemini_grouping_engine.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/group_card.dart';
import '../../../widgets/stat_row.dart';

class FacilitatorTab extends StatelessWidget {
  final SessionState session;
  final List<Group> groups;
  final GeminiGroupingEngine groupingEngine;
  final FirebaseMoamalRepository repo;
  final String? aiBriefingFlow;
  final String? aiBriefingAction;
  final String? aiBriefingQuestion;
  final MeetingReport? meetingReport;
  final bool isGeneratingReport;
  final VoidCallback onGenerateReport;
  final VoidCallback onReset;
  final Future<void> Function(String) onTitleChanged;

  const FacilitatorTab({
    super.key,
    required this.session,
    required this.groups,
    required this.groupingEngine,
    required this.repo,
    this.aiBriefingFlow,
    this.aiBriefingAction,
    this.aiBriefingQuestion,
    this.meetingReport,
    required this.isGeneratingReport,
    required this.onGenerateReport,
    required this.onReset,
    required this.onTitleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;

    if (isCompact) {
      return _CompactLayout(tab: this);
    }
    return _MediumLayout(tab: this);
  }
}

// ── Compact: 세로 스크롤 ─────────────────────────────────────────────────
class _CompactLayout extends StatelessWidget {
  final FacilitatorTab tab;
  const _CompactLayout({required this.tab});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        StatRow(
          participantCount: tab.session.participants.length,
          ideaCount: tab.session.ideas.length,
          groupCount: tab.groups.length,
        ),
        const SizedBox(height: 12),
        _SessionPanel(
          session: tab.session,
          onTitleChanged: tab.onTitleChanged,
          onReset: tab.onReset,
        ),
        const SizedBox(height: 12),
        _BriefingPanel(
          groups: tab.groups,
          groupingEngine: tab.groupingEngine,
          flow: tab.aiBriefingFlow,
          action: tab.aiBriefingAction,
          question: tab.aiBriefingQuestion,
          session: tab.session,
        ),
        const SizedBox(height: 12),
        _VotePanel(
          session: tab.session,
          groups: tab.groups,
          repo: tab.repo,
        ),
        const SizedBox(height: 12),
        _ReportPanel(
          session: tab.session,
          meetingReport: tab.meetingReport,
          isGenerating: tab.isGeneratingReport,
          onGenerate: tab.onGenerateReport,
        ),
      ],
    );
  }
}

// ── Medium: 왼쪽(세션+브리핑) / 오른쪽(스탯+투표+리포트) ─────────────────
class _MediumLayout extends StatelessWidget {
  final FacilitatorTab tab;
  const _MediumLayout({required this.tab});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: w * 0.45,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            children: [
              _SessionPanel(
                session: tab.session,
                onTitleChanged: tab.onTitleChanged,
                onReset: tab.onReset,
              ),
              const SizedBox(height: 12),
              _BriefingPanel(
                groups: tab.groups,
                groupingEngine: tab.groupingEngine,
                flow: tab.aiBriefingFlow,
                action: tab.aiBriefingAction,
                question: tab.aiBriefingQuestion,
                session: tab.session,
              ),
            ],
          ),
        ),
        Container(width: 1, color: const Color(0xFFE0DDD6)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 14, 14, 14),
            children: [
              StatRow(
          participantCount: tab.session.participants.length,
          ideaCount: tab.session.ideas.length,
          groupCount: tab.groups.length,
        ),
              const SizedBox(height: 12),
              _VotePanel(
                session: tab.session,
                groups: tab.groups,
                repo: tab.repo,
              ),
              const SizedBox(height: 12),
              _ReportPanel(
                session: tab.session,
                meetingReport: tab.meetingReport,
                isGenerating: tab.isGeneratingReport,
                onGenerate: tab.onGenerateReport,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 패널들 ────────────────────────────────────────────────────────────────

class _SessionPanel extends StatefulWidget {
  final SessionState session;
  final Future<void> Function(String) onTitleChanged;
  final VoidCallback onReset;

  const _SessionPanel({
    required this.session,
    required this.onTitleChanged,
    required this.onReset,
  });

  @override
  State<_SessionPanel> createState() => _SessionPanelState();
}

class _SessionPanelState extends State<_SessionPanel> {
  late TextEditingController _titleCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.session.title);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '수업 세션',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '오늘의 질문',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: kGreen,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(isDense: true),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      widget.onTitleChanged(_titleCtrl.text.trim()),
                  child: const Text('질문 저장'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onReset,
                  child: const Text('전체 초기화'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: QrImageView(
              data: DeepLinkService.buildJoinUri(widget.session.sessionCode),
              version: QrVersions.auto,
              size: 140,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.session.sessionCode,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: kGreen,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _VotePanel extends StatelessWidget {
  final SessionState session;
  final List<Group> groups;
  final FirebaseMoamalRepository repo;

  const _VotePanel({
    required this.session,
    required this.groups,
    required this.repo,
  });

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final gid in session.votes.values) {
      counts[gid] = (counts[gid] ?? 0) + 1;
    }

    // 최대 득표수 (바 차트용)
    final maxVotes = counts.values.isEmpty
        ? 1
        : counts.values.reduce((a, b) => a > b ? a : b);

    return _Panel(
      title: '묶음과 투표',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      repo.setVoteOpen(session.sessionCode, !session.voteOpen),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        session.voteOpen ? const Color(0xFFD32F2F) : kGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(session.voteOpen ? '투표 닫기' : '투표 시작'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => repo.clearVotes(session.sessionCode),
                  child: const Text('투표 초기화'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (groups.isEmpty)
            const Text(
              '아직 등록된 의견이 없습니다.',
              style: TextStyle(color: Colors.black38),
            )
          else
            ...groups.asMap().entries.map((e) {
              final voteCount = counts[e.value.id] ?? 0;
              return Column(
                children: [
                  GroupCard(
                    group: e.value,
                    ideaCount: e.value.ideas.length,
                  ),
                  if (session.votes.isNotEmpty)
                    _VoteBar(
                      voteCount: voteCount,
                      maxVotes: maxVotes,
                      isTop: e.key == 0,
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _VoteBar extends StatelessWidget {
  final int voteCount;
  final int maxVotes;
  final bool isTop;

  const _VoteBar({
    required this.voteCount,
    required this.maxVotes,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxVotes > 0 ? voteCount / maxVotes : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: ratio,
          minHeight: 8,
          backgroundColor: const Color(0xFFE0DDD6),
          valueColor: AlwaysStoppedAnimation(isTop ? kYellow : kGreen),
        ),
      ),
    );
  }
}

class _BriefingPanel extends StatelessWidget {
  final List<Group> groups;
  final GeminiGroupingEngine groupingEngine;
  final String? flow;
  final String? action;
  final String? question;
  final SessionState session;

  const _BriefingPanel({
    required this.groups,
    required this.groupingEngine,
    this.flow,
    this.action,
    this.question,
    required this.session,
  });

  String _makeSummary() {
    if (groups.isEmpty) return '';
    final largest = groups.reduce(
      (a, b) => a.ideas.length >= b.ideas.length ? a : b,
    );
    return '총 ${session.ideas.length}개의 의견이 ${groups.length}개 묶음으로 정리되었습니다. '
        '가장 많이 나온 흐름은 "${groupingEngine.makeGroupTitle(largest)}"입니다.';
  }

  String _makeNextAction() {
    if (session.ideas.length < 3) return '의견을 조금 더 받은 뒤 묶음을 확인하세요.';
    if (groups.length == 1) return '비슷한 의견이 모였습니다. 실행 방법이나 우려점을 한 번 더 물어보세요.';
    if (!session.voteOpen && session.votes.isEmpty) {
      return '묶음 제목과 대표 의견을 확인한 뒤 투표를 시작할 수 있습니다.';
    }
    if (session.voteOpen) return '투표가 진행 중입니다. 공용 화면에서 결과 흐름을 함께 보세요.';
    return '투표 결과를 바탕으로 결정 사항과 남은 쟁점을 정리하세요.';
  }

  String _makeFollowUpQuestion() {
    if (groups.isEmpty) return '';
    if (groups.length == 1) {
      return '이 의견을 실제로 실행한다면 가장 먼저 바꿔야 할 점은 무엇일까요?';
    }
    return '"${groupingEngine.makeGroupTitle(groups[0])}"와 '
        '"${groupingEngine.makeGroupTitle(groups[1])}" 중 '
        '지금 상황에서 더 중요한 기준은 무엇일까요?';
  }

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return _Panel(
        title: '진행자 정리 패널',
        child: const Text(
          '의견이 들어오면 여기에서 큰 흐름과 다음 진행 행동을 보여줍니다.',
          style: TextStyle(color: Colors.black38),
        ),
      );
    }

    return _Panel(
      title: '진행자 정리 패널',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('현재 흐름'),
          Text(flow ?? _makeSummary()),
          _label('바로 할 일'),
          Text(
            action ?? _makeNextAction(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: kGreen,
            ),
          ),
          _label('핵심어'),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: groupingEngine
                .topKeywords(session.ideas, 6)
                .asMap()
                .entries
                .map(
                  (e) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: e.key == 0 ? kYellow : kGround,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: e.key == 0
                            ? kYellow
                            : kInk.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: e.key == 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: kInk,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          _label('추천 다음 질문'),
          Text(question ?? _makeFollowUpQuestion()),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: kGreen,
          ),
        ),
      );
}

class _ReportPanel extends StatelessWidget {
  final SessionState session;
  final MeetingReport? meetingReport;
  final bool isGenerating;
  final VoidCallback onGenerate;

  const _ReportPanel({
    required this.session,
    this.meetingReport,
    required this.isGenerating,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '수업기록 초안',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (meetingReport != null) ...[
            Text(meetingReport!.overview),
            const Divider(height: 20),
            ...meetingReport!.groups.asMap().entries.map((e) {
              final g = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${e.key + 1}. ${g.title}  |  발언 ${g.ideaCount}건'
                  '${g.votes > 0 ? ' · ${g.votes}표' : ''}\n'
                  '${g.keyQuote.isNotEmpty ? '"${g.keyQuote}"' : ''}',
                ),
              );
            }),
            const Divider(height: 20),
            Text(meetingReport!.voteSummary),
            Text(
              meetingReport!.conclusion,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (meetingReport!.unresolved != null)
              Text(
                meetingReport!.unresolved!,
                style: const TextStyle(color: Color(0xFFD32F2F)),
              ),
            Text(meetingReport!.nextAction),
          ] else
            const Text(
              'AI 리포트를 생성하면 구조화된 수업기록이 나타납니다.',
              style: TextStyle(color: Colors.black38),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isGenerating ? null : onGenerate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isGenerating ? null : kYellow,
                    foregroundColor: kInk,
                  ),
                  child: Text(isGenerating ? '생성 중...' : 'AI 리포트 생성'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final text = meetingReport?.toPlainText(session.title) ??
                        '아직 리포트가 없습니다.';
                    share_plus.Share.share(
                      text,
                      subject: '모아말 수업기록 ${session.sessionCode}',
                    );
                  },
                  child: const Text('공유'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 공용 패널 컨테이너 ────────────────────────────────────────────────────
class _Panel extends StatelessWidget {
  final String title;
  final Widget child;

  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: kInk,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
