import 'package:flutter/material.dart';
import '../../models/approved_group.dart';
import '../../models/group.dart';
import '../../models/session_state.dart';
import '../../repositories/firebase_moamal_repository.dart';
import '../../services/gemini_grouping_engine.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/group_card.dart';

class ClusterVoteScreen extends StatefulWidget {
  final String sessionCode;
  final Stream<SessionState>? sessionStream;
  final List<Group> groups;
  final FirebaseMoamalRepository repo;
  final GeminiGroupingEngine groupingEngine;
  final Future<void> Function(String) onTitleChanged;
  final VoidCallback onReset;
  final VoidCallback onEndSession;

  const ClusterVoteScreen({
    super.key,
    required this.sessionCode,
    this.sessionStream,
    required this.groups,
    required this.repo,
    required this.groupingEngine,
    required this.onTitleChanged,
    required this.onReset,
    required this.onEndSession,
  });

  @override
  State<ClusterVoteScreen> createState() => _ClusterVoteScreenState();
}

class _ClusterVoteScreenState extends State<ClusterVoteScreen> {
  bool _isApproving = false;
  bool _approved = false;

  @override
  void initState() {
    super.initState();
    widget.groupingEngine.onGroupUpdate = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    widget.groupingEngine.onGroupUpdate = null;
    super.dispose();
  }

  List<Group> get _currentGroups =>
      widget.groupingEngine.cachedGroups ?? widget.groups;

  Future<void> _approveGroups(SessionState? session) async {
    final groups = _currentGroups;
    if (_isApproving || groups.isEmpty) return;
    setState(() => _isApproving = true);
    try {
      final now = DateTime.now();
      final approvedBy = session?.ownerUid ?? '';
      final toSave = groups
          .map((g) => ApprovedGroup(
                groupId: g.id,
                title: widget.groupingEngine.makeGroupTitle(g),
                ideaIds: g.ideas.map((i) => i.id).toList(),
                approvedAt: now,
                approvedBy: approvedBy,
                revision: 1,
              ))
          .toList();
      await widget.repo.approveGroups(widget.sessionCode, toSave);
      widget.groupingEngine.freeze();
      if (mounted) setState(() => _approved = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('승인 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SessionState>(
      stream: widget.sessionStream ?? widget.repo.listenToSession(widget.sessionCode),
      builder: (context, snapshot) {
        final session = snapshot.data;
        final isCompact = context.isCompact;

        final counts = <String, int>{};
        if (session != null) {
          for (final gid in session.votes.values) {
            counts[gid] = (counts[gid] ?? 0) + 1;
          }
        }

        final totalVotes = session?.votes.length ?? 0;

        return Scaffold(
          backgroundColor: kGround,
          appBar: _buildAppBar(session, isCompact),
          body: session == null
              ? const Center(
                  child: CircularProgressIndicator(color: kGreen))
              : isCompact
                  ? _CompactBody(
                      session: session,
                      groups: _currentGroups,
                      groupingEngine: widget.groupingEngine,
                      counts: counts,
                      totalVotes: totalVotes,
                    )
                  : _MediumBody(
                      session: session,
                      groups: _currentGroups,
                      groupingEngine: widget.groupingEngine,
                      counts: counts,
                      totalVotes: totalVotes,
                    ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(SessionState? session, bool isCompact) {
    final ideaCount = session?.ideas.length ?? 0;
    final groupCount = _currentGroups.length;
    final voteOpen = session?.voteOpen ?? false;
    final hasApprovedGroups = session?.approvedGroups.isNotEmpty ?? false;

    return AppBar(
      backgroundColor: kGround,
      foregroundColor: kInk,
      elevation: 0,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '학생 의견 모음',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: kInk),
            ),
            Text(
              '$ideaCount개 발언 · $groupCount개 주제로 묶임',
              style: const TextStyle(fontSize: 12, color: Colors.black38),
            ),
          ],
        ),
      ),
      actions: [
        if (session != null) ...[
          // 그룹 승인 버튼 — 아직 승인하지 않았을 때만 표시
          if (!hasApprovedGroups && !_approved && _currentGroups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _isApproving
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: kGreen),
                      ),
                    )
                  : GestureDetector(
                      onTap: () => _approveGroups(session),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: kGreen,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '그룹 승인',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
            ),
          // 승인 완료 배지
          if (hasApprovedGroups || _approved)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Chip(
                label: Text('승인됨',
                    style: TextStyle(fontSize: 12, color: kGreen)),
                backgroundColor: Color(0xFFE8F5E9),
                side: BorderSide.none,
                padding: EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          // 투표 시작/닫기 버튼
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () =>
                  widget.repo.setVoteOpen(widget.sessionCode, !voteOpen),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: voteOpen ? const Color(0xFFD32F2F) : kYellow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  voteOpen ? '투표 닫기' : '투표 시작',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: voteOpen ? Colors.white : kInk,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Compact: 클러스터 카드 + 바 차트 세로 ────────────────────────────────
class _CompactBody extends StatelessWidget {
  final SessionState session;
  final List<Group> groups;
  final GeminiGroupingEngine groupingEngine;
  final Map<String, int> counts;
  final int totalVotes;

  const _CompactBody({
    required this.session,
    required this.groups,
    required this.groupingEngine,
    required this.counts,
    required this.totalVotes,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const Center(
        child: Text('아직 의견이 없습니다.',
            style: TextStyle(color: Colors.black38)),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
      children: [
        ...groups.asMap().entries.map(
          (e) => GroupCard(
            index: e.key,
            group: e.value,
            voteCount: counts[e.value.id] ?? 0,
            editable: false,
            titleOverride: groupingEngine.makeGroupTitle(e.value),
          ),
        ),
        if (totalVotes > 0) ...[
          const SizedBox(height: 8),
          _VoteBarChart(
            groups: groups,
            groupingEngine: groupingEngine,
            counts: counts,
            totalVotes: totalVotes,
            barHeight: 10,
            showPercent: true,
          ),
        ],
      ],
    );
  }
}

// ── Medium: 클러스터(왼) + 바 차트(오) ───────────────────────────────────
class _MediumBody extends StatelessWidget {
  final SessionState session;
  final List<Group> groups;
  final GeminiGroupingEngine groupingEngine;
  final Map<String, int> counts;
  final int totalVotes;

  const _MediumBody({
    required this.session,
    required this.groups,
    required this.groupingEngine,
    required this.counts,
    required this.totalVotes,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    if (groups.isEmpty) {
      return const Center(
        child: Text('아직 의견이 없습니다.',
            style: TextStyle(color: Colors.black38)),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 왼쪽: 클러스터 카드
        SizedBox(
          width: w * 0.55,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 24),
            children: groups
                .asMap()
                .entries
                .map(
                  (e) => GroupCard(
                    index: e.key,
                    group: e.value,
                    voteCount: counts[e.value.id] ?? 0,
                    editable: false,
                    titleOverride: groupingEngine.makeGroupTitle(e.value),
                  ),
                )
                .toList(),
          ),
        ),
        Container(width: 1, color: const Color(0xFFE0DDD6)),
        // 오른쪽: 투표 바 차트
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '음성 투표 결과',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black38,
                  ),
                ),
                const SizedBox(height: 20),
                if (totalVotes == 0)
                  const Text(
                    '투표를 시작하면\n결과가 여기에 표시됩니다.',
                    style: TextStyle(fontSize: 14, color: Colors.black38),
                  )
                else
                  _VoteBarChart(
                    groups: groups,
                    groupingEngine: groupingEngine,
                    counts: counts,
                    totalVotes: totalVotes,
                    barHeight: 14,
                    showPercent: true,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── 투표 바 차트 ──────────────────────────────────────────────────────────
class _VoteBarChart extends StatelessWidget {
  final List<Group> groups;
  final GeminiGroupingEngine groupingEngine;
  final Map<String, int> counts;
  final int totalVotes;
  final double barHeight;
  final bool showPercent;

  const _VoteBarChart({
    required this.groups,
    required this.groupingEngine,
    required this.counts,
    required this.totalVotes,
    required this.barHeight,
    required this.showPercent,
  });

  @override
  Widget build(BuildContext context) {
    final maxVotes = counts.values.isEmpty
        ? 1
        : counts.values.reduce((a, b) => a > b ? a : b);

    return Column(
      children: groups.asMap().entries.map((e) {
        final g = e.value;
        final c = counts[g.id] ?? 0;
        final ratio = maxVotes > 0 ? c / maxVotes : 0.0;
        final pct = totalVotes > 0 ? (c / totalVotes * 100).round() : 0;
        final isTop = e.key == 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      groupingEngine.makeGroupTitle(g),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                      ),
                    ),
                  ),
                  if (showPercent)
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: kInk,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(barHeight / 2),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: barHeight,
                  backgroundColor: const Color(0xFFE0DDD6),
                  valueColor:
                      AlwaysStoppedAnimation(isTop ? kYellow : kGreen),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
