import 'package:flutter/material.dart';
import '../../models/approved_group.dart';
import '../../models/group.dart';
import '../../models/merge_log.dart';
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
  MergeLog? _lastMergeLog;

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

  Future<void> _doMerge(
    String sourceId,
    List<String> targetIds,
    String newTitle,
    List<ApprovedGroup> approvedGroups,
  ) async {
    final log = widget.groupingEngine
        .mergeGroups(sourceId, targetIds, newTitle, approvedGroups: approvedGroups);
    if (log == null) return;
    try {
      await widget.repo.saveMergeLog(widget.sessionCode, log);
      if (mounted) setState(() => _lastMergeLog = log);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('병합 저장 실패: $e')));
      }
    }
  }

  Future<void> _doUndoMerge() async {
    final log = _lastMergeLog;
    if (log == null || log.undone) return;
    try {
      widget.groupingEngine.undoMerge();
      await widget.repo.undoMergeLog(widget.sessionCode, log);
      if (mounted) setState(() => _lastMergeLog = log.copyWith(undone: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('되돌리기 실패: $e')));
      }
    }
  }

  void _showMergeSheet(List<ApprovedGroup> approvedGroups) {
    if (_currentGroups.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('병합하려면 그룹이 2개 이상 필요합니다')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: sheetConstraints(),
      builder: (_) => _MergeSheet(
        groups: _currentGroups,
        groupingEngine: widget.groupingEngine,
        onMerge: (sourceId, targetIds, title) =>
            _doMerge(sourceId, targetIds, title, approvedGroups),
      ),
    );
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
    final canUndo = widget.groupingEngine.canUndoMerge &&
        _lastMergeLog != null &&
        !(_lastMergeLog!.undone);

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
          // 병합 되돌리기
          if (canUndo)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: '병합 되돌리기',
              onPressed: _doUndoMerge,
            ),
          // 그룹 병합
          if (_currentGroups.length >= 2)
            IconButton(
              icon: const Icon(Icons.merge_type),
              tooltip: '그룹 병합',
              onPressed: () =>
                  _showMergeSheet(session.approvedGroups),
            ),
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
            group: e.value,
            ideaCount: e.value.ideas.length,
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
                    group: e.value,
                    ideaCount: e.value.ideas.length,
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

// ── 그룹 병합 바텀시트 ────────────────────────────────────────────────────
class _MergeSheet extends StatefulWidget {
  final List<Group> groups;
  final GeminiGroupingEngine groupingEngine;
  final Future<void> Function(String sourceId, List<String> targetIds, String title) onMerge;

  const _MergeSheet({
    required this.groups,
    required this.groupingEngine,
    required this.onMerge,
  });

  @override
  State<_MergeSheet> createState() => _MergeSheetState();
}

class _MergeSheetState extends State<_MergeSheet> {
  String? _sourceId;
  final _targetIds = <String>{};
  late final TextEditingController _titleCtrl;
  bool _isMerging = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  bool get _canConfirm =>
      _sourceId != null && _targetIds.isNotEmpty && _titleCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('그룹 병합',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('기준 그룹을 하나 선택하고, 흡수될 그룹을 체크하세요.',
                  style: TextStyle(fontSize: 13, color: Colors.black45)),
              const SizedBox(height: 16),
              ...widget.groups.map((g) {
                final title = widget.groupingEngine.makeGroupTitle(g);
                final isSource = _sourceId == g.id;
                final isTarget = _targetIds.contains(g.id);
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() {
                    _sourceId = g.id;
                    _targetIds.remove(g.id);
                    if (_titleCtrl.text.isEmpty) _titleCtrl.text = title;
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        // 커스텀 라디오 인디케이터
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSource ? kGreen : Colors.black26,
                              width: isSource ? 2 : 1.5,
                            ),
                          ),
                          child: isSource
                              ? Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: kGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: TextStyle(
                                      fontWeight: isSource
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: kInk)),
                              Text('${g.ideas.length}건',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black38)),
                            ],
                          ),
                        ),
                        if (_sourceId != null && !isSource)
                          Checkbox(
                            value: isTarget,
                            activeColor: kYellow,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _targetIds.add(g.id);
                              } else {
                                _targetIds.remove(g.id);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: '병합 후 그룹 제목',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kGreen),
                  onPressed: _canConfirm && !_isMerging
                      ? () async {
                          setState(() => _isMerging = true);
                          await widget.onMerge(
                              _sourceId!, _targetIds.toList(), _titleCtrl.text.trim());
                          if (context.mounted) Navigator.pop(context);
                        }
                      : null,
                  child: _isMerging
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('병합하기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
