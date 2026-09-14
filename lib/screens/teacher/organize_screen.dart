import 'package:flutter/material.dart';
import '../../models/approved_group.dart';
import '../../models/group.dart';
import '../../models/idea.dart';
import '../../models/session_state.dart';
import '../../repositories/firebase_moamal_repository.dart';
import '../../services/auth_service.dart';
import '../../services/gemini_grouping_engine.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import 'package:provider/provider.dart';
import 'demo_vote_panel.dart';

class OrganizeScreen extends StatefulWidget {
  final String sessionCode;
  /// 교사 홈이 만든 broadcast 스트림을 그대로 받는다. **필수**이다 —
  /// 화면이 직접 listenToSession()을 부르면 리포지터리가 기존 구독을 끊고
  /// 새로 만들기 때문에 build마다 재구독이 발생한다 (Mercury-3-Student-01).
  final Stream<SessionState> sessionStream;
  final SessionState? initialSession;
  final List<Group> groups;
  final FirebaseMoamalRepository repo;
  final GeminiGroupingEngine groupingEngine;

  const OrganizeScreen({
    super.key,
    required this.sessionCode,
    required this.sessionStream,
    this.initialSession,
    required this.groups,
    required this.repo,
    required this.groupingEngine,
  });

  @override
  State<OrganizeScreen> createState() => _OrganizeScreenState();
}

class _OrganizeScreenState extends State<OrganizeScreen> {
  int _tabIndex = 0;

  List<Group> get _currentGroups =>
      widget.groupingEngine.cachedGroups ?? widget.groups;

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

  int _unclassifiedCount(SessionState session) {
    final classified = <String>{
      for (final g in _currentGroups)
        for (final idea in g.ideas) idea.id,
    };
    return session.ideas.where((i) => !classified.contains(i.id)).length;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SessionState>(
      stream: widget.sessionStream,
      initialData: widget.initialSession,
      builder: (context, snapshot) {
        final session = snapshot.data;
        final groups = _currentGroups;
        final unclassified = session != null ? _unclassifiedCount(session) : 0;

        return Scaffold(
          backgroundColor: kGround,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isTablet = constraints.maxWidth >= AppBreakpoints.compact;
                if (isTablet) {
                  return _buildTabletLayout(session, groups, unclassified);
                }
                return _buildPhoneLayout(session, groups, unclassified);
              },
            ),
          ),
        );
      },
    );
  }

  // ── Phone layout ──────────────────────────────────────────────────────────

  Widget _buildPhoneLayout(
      SessionState? session, List<Group> groups, int unclassified) {
    return Column(
      children: [
        _buildHeader(session, groups),
        _buildTabBar(unclassified),
        Expanded(
          child: session == null
              ? const Center(child: CircularProgressIndicator(color: kGreen))
              : _buildTabContent(session, groups),
        ),
      ],
    );
  }

  // ── Tablet layout (≥600dp) ────────────────────────────────────────────────

  Widget _buildTabletLayout(
      SessionState? session, List<Group> groups, int unclassified) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: sidebar panel (kGreen) — session overview + approved groups
        SizedBox(
          width: 300,
          child: _buildSidebar(session, groups),
        ),
        // Divider
        Container(width: 1, color: const Color(0xFFD8D3C6)),
        // Right: full tab UX
        Expanded(
          child: Column(
            children: [
              _buildTabBar(unclassified, compact: false),
              Expanded(
                child: session == null
                    ? const Center(
                        child: CircularProgressIndicator(color: kGreen))
                    : _buildTabContent(session, groups),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar(SessionState? session, List<Group> groups) {
    final ideaCount = session?.ideas.length ?? 0;
    final groupCount = groups.length;
    final approvedCount = session?.approvedGroups.length ?? 0;
    final voteOpen = session?.voteOpen ?? false;

    return Container(
      color: kGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button + title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.chevron_left,
                        color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  '정리',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Stat cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                _SidebarStat(label: '전체 의견', value: '$ideaCount'),
                const SizedBox(height: 8),
                _SidebarStat(label: 'AI 그룹', value: '$groupCount'),
                const SizedBox(height: 8),
                _SidebarStat(
                  label: '승인 그룹',
                  value: '$approvedCount',
                  accent: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Vote status badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: voteOpen ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: voteOpen ? kYellow : Colors.white38,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    voteOpen ? '투표 진행 중' : '투표 대기',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: voteOpen ? kYellow : Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Approved groups list
          if (session != null && session.approvedGroups.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Text(
                '승인된 후보',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                itemCount: session.approvedGroups.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (ctx, i) {
                  final ag = session.approvedGroups[i];
                  final voteCount = session.votes.values
                      .where((gid) => gid == ag.groupId)
                      .length;
                  return Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            ag.title,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (session.voteOpen) ...[
                          const SizedBox(width: 8),
                          Text(
                            '$voteCount표',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: voteCount > 0 ? kYellow : Colors.white38,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ] else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(SessionState? session, List<Group> groups) {
    final ideaCount = session?.ideas.length ?? 0;
    final groupCount = groups.length;
    final approvedCount = session?.approvedGroups.length ?? 0;

    return Container(
      color: kGreen,
      padding: const EdgeInsets.fromLTRB(14, 14, 18, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.chevron_left,
                  color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '정리',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '의견 $ideaCount건 · 그룹 $groupCount개 · 승인 $approvedCount개',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar(int unclassifiedCount, {bool compact = true}) {
    const labels = ['원문', '승인', '투표'];
    final topPad = compact ? 0.0 : 14.0;
    return Container(
      color: kGreen,
      padding: EdgeInsets.fromLTRB(14, topPad, 14, 12),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = _tabIndex == i;
          final hasBadge = i == 0 && unclassifiedCount > 0;
          return GestureDetector(
            onTap: () => setState(() => _tabIndex = i),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: selected ? kCardBg : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? kInk
                          : Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  if (hasBadge) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: kRed, shape: BoxShape.circle),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Tab content ───────────────────────────────────────────────────────────

  Widget _buildTabContent(SessionState session, List<Group> groups) {
    switch (_tabIndex) {
      case 0:
        return _IdeasTab(
          session: session,
          groups: groups,
          groupingEngine: widget.groupingEngine,
        );
      case 1:
        return _ApproveTab(
          session: session,
          groups: groups,
          groupingEngine: widget.groupingEngine,
          repo: widget.repo,
          sessionCode: widget.sessionCode,
          onSwitchToVote: () => setState(() => _tabIndex = 2),
        );
      case 2:
        return _VoteTab(
          session: session,
          repo: widget.repo,
          sessionCode: widget.sessionCode,
          onSwitchToApprove: () => setState(() => _tabIndex = 1),
        );
      default:
        return const SizedBox();
    }
  }
}

// ── 원문 탭 ───────────────────────────────────────────────────────────────────

class _IdeasTab extends StatefulWidget {
  final SessionState session;
  final List<Group> groups;
  final GeminiGroupingEngine groupingEngine;

  const _IdeasTab({
    required this.session,
    required this.groups,
    required this.groupingEngine,
  });

  @override
  State<_IdeasTab> createState() => _IdeasTabState();
}

class _IdeasTabState extends State<_IdeasTab> {
  String? _filterGroupId; // null=전체, 'unclassified'=미분류, else group.id

  Map<String, Group> get _ideaGroupMap {
    final map = <String, Group>{};
    for (final g in widget.groups) {
      for (final idea in g.ideas) {
        map[idea.id] = g;
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final ideaGroupMap = _ideaGroupMap;
    final classifiedIds = ideaGroupMap.keys.toSet();
    final unclassifiedCount =
        widget.session.ideas.where((i) => !classifiedIds.contains(i.id)).length;

    // Filter
    List<dynamic> filtered; // List<Idea>
    if (_filterGroupId == null) {
      filtered = List.of(widget.session.ideas);
    } else if (_filterGroupId == 'unclassified') {
      filtered = widget.session.ideas
          .where((i) => !classifiedIds.contains(i.id))
          .toList();
    } else {
      final targetGroup =
          widget.groups.firstWhere((g) => g.id == _filterGroupId,
              orElse: () => widget.groups.first);
      final targetIds = targetGroup.ideas.map((i) => i.id).toSet();
      filtered =
          widget.session.ideas.where((i) => targetIds.contains(i.id)).toList();
    }

    // Sort: unclassified first
    filtered.sort((a, b) {
      final aClass = classifiedIds.contains((a as dynamic).id);
      final bClass = classifiedIds.contains((b as dynamic).id);
      if (aClass == bClass) return 0;
      return aClass ? 1 : -1;
    });

    return Column(
      children: [
        // Filter chips (horizontal scroll — no fixed height so font scale works)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Row(
            children: [
              _FilterChip(
                label: '미분류 $unclassifiedCount',
                selected: _filterGroupId == 'unclassified',
                accent: true,
                onTap: () => setState(() => _filterGroupId =
                    _filterGroupId == 'unclassified' ? null : 'unclassified'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: '전체 ${widget.session.ideas.length}',
                selected: _filterGroupId == null,
                onTap: () => setState(() => _filterGroupId = null),
              ),
              ...widget.groups.map((g) {
                final gid = g.id;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _FilterChip(
                    label: widget.groupingEngine.makeGroupTitle(g),
                    selected: _filterGroupId == gid,
                    onTap: () => setState(() =>
                        _filterGroupId = _filterGroupId == gid ? null : gid),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Idea list
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('아직 의견이 없습니다.',
                      style: TextStyle(color: Colors.black38)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final idea = filtered[i] as dynamic;
                    final group = ideaGroupMap[idea.id as String];
                    final isUnclassified = group == null;
                    final groupTitle = group != null
                        ? widget.groupingEngine.makeGroupTitle(group)
                        : '미분류';

                    return _IdeaCard(
                      speaker: idea.speaker as String,
                      text: idea.text as String,
                      isUnclassified: isUnclassified,
                      groupTitle: groupTitle,
                      onMoveTap: () => _showMoveSheet(
                        ctx,
                        idea as Idea,
                        group,
                        widget.groups,
                        widget.groupingEngine,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

void _showMoveSheet(
  BuildContext context,
  Idea idea,
  Group? currentGroup,
  List<Group> groups,
  GeminiGroupingEngine groupingEngine,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MoveGroupSheet(
      idea: idea,
      currentGroupId: currentGroup?.id,
      groups: groups,
      groupingEngine: groupingEngine,
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool accent;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        decoration: BoxDecoration(
          color: selected
              ? (accent ? kYellow : kInk)
              : kCardBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Colors.transparent : kBorder,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected
                ? (accent ? kInk : Colors.white)
                : kInk.withValues(alpha: 0.7),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _IdeaCard extends StatelessWidget {
  final String speaker;
  final String text;
  final bool isUnclassified;
  final String groupTitle;
  final VoidCallback? onMoveTap;

  const _IdeaCard({
    required this.speaker,
    required this.text,
    required this.isUnclassified,
    required this.groupTitle,
    this.onMoveTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnclassified ? kYellow : kBorder,
          width: isUnclassified ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                speaker,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kGreen,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 15.5,
              height: 1.6,
              color: kInk,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUnclassified
                        ? kYellow
                        : kGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          groupTitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isUnclassified ? kInk : kGreen,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.expand_more,
                          size: 13,
                          color: isUnclassified ? kInk : kGreen),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onMoveTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: kGround,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: kBorder),
                  ),
                  child: Text(
                    '그룹 이동',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: kInk.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 승인 탭 ───────────────────────────────────────────────────────────────────

class _ApproveTab extends StatefulWidget {
  final SessionState session;
  final List<Group> groups;
  final GeminiGroupingEngine groupingEngine;
  final FirebaseMoamalRepository repo;
  final String sessionCode;
  final VoidCallback onSwitchToVote;

  const _ApproveTab({
    required this.session,
    required this.groups,
    required this.groupingEngine,
    required this.repo,
    required this.sessionCode,
    required this.onSwitchToVote,
  });

  @override
  State<_ApproveTab> createState() => _ApproveTabState();
}

class _ApproveTabState extends State<_ApproveTab> {
  final _pendingIds = <String>{};

  AuthService? _auth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _auth = context.read<AuthService>();
  }

  bool _isApproved(String groupId) =>
      widget.session.approvedGroups.any((a) => a.groupId == groupId);

  Future<void> _approve(Group group) async {
    if (_pendingIds.contains(group.id)) return;
    setState(() => _pendingIds.add(group.id));
    try {
      final now = DateTime.now();
      final ownerUid = widget.session.ownerUid ?? _auth?.currentUid ?? '';
      final newList = [
        ...widget.session.approvedGroups,
        ApprovedGroup(
          groupId: group.id,
          title: widget.groupingEngine.makeGroupTitle(group),
          ideaIds: group.ideas.map((i) => i.id).toList(),
          approvedAt: now,
          approvedBy: ownerUid,
          revision: 1,
        ),
      ];
      await widget.repo.approveGroups(widget.sessionCode, newList);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('승인 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _pendingIds.remove(group.id));
    }
  }

  Future<void> _unapprove(String groupId) async {
    if (_pendingIds.contains(groupId)) return;
    setState(() => _pendingIds.add(groupId));
    try {
      await widget.repo.deleteApprovedGroup(widget.sessionCode, groupId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('승인 취소 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _pendingIds.remove(groupId));
    }
  }

  Future<void> _showRenameDialog(String groupId, String currentTitle) async {
    final ctrl = TextEditingController(text: currentTitle);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          '그룹 이름 수정',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: kInk),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: kInk),
          decoration: InputDecoration(
            filled: true,
            fillColor: kGround,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kGreen, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kGreen, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소',
                style: TextStyle(color: kGreen, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('저장',
                style: TextStyle(color: kGreen, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    // ctrl은 로컬 변수로 다이얼로그 종료 후 GC 처리 — 애니메이션 중 dispose 시 assertion 크래시 방지
    if (result == null || result.isEmpty) return;

    final newList = widget.session.approvedGroups.map((a) {
      if (a.groupId != groupId) return a;
      return ApprovedGroup(
        groupId: a.groupId,
        title: result,
        ideaIds: a.ideaIds,
        approvedAt: a.approvedAt,
        approvedBy: a.approvedBy,
        revision: a.revision + 1,
      );
    }).toList();
    await widget.repo.approveGroups(widget.sessionCode, newList);
  }

  void _showMergeSheet(BuildContext context, Group sourceGroup, String sourceTitle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MergeGroupSheet(
        sourceGroup: sourceGroup,
        sourceTitle: sourceTitle,
        otherGroups: widget.groups.where((g) => g.id != sourceGroup.id).toList(),
        groupingEngine: widget.groupingEngine,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.groups;
    final approvedCount = widget.session.approvedGroups.length;
    final canToggle = !widget.session.voteOpen;

    if (groups.isEmpty) {
      return const Center(
        child: Text(
          '아직 의견 그룹이 없습니다.\n학생 의견이 모이면 AI가 자동으로 묶어요.',
          style: TextStyle(color: Colors.black38, height: 1.6),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            itemCount: groups.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final group = groups[i];
              final approved = _isApproved(group.id);
              final approvedGroup = approved
                  ? widget.session.approvedGroups
                      .firstWhere((a) => a.groupId == group.id)
                  : null;
              final title = approvedGroup?.title ??
                  widget.groupingEngine.makeGroupTitle(group);
              final isPending = _pendingIds.contains(group.id);

              return _GroupApproveCard(
                group: group,
                approvedGroup: approvedGroup,
                title: title,
                approved: approved,
                isPending: isPending,
                canToggle: canToggle,
                onApprove: () => _approve(group),
                onUnapprove: () => _unapprove(group.id),
                onRename: approved
                    ? () => _showRenameDialog(group.id, title)
                    : null,
                onIdeaMove: (idea) => _showMoveSheet(
                  context,
                  idea,
                  group,
                  widget.groups,
                  widget.groupingEngine,
                ),
                onMerge: widget.groups.length > 1
                    ? () => _showMergeSheet(context, group, title)
                    : null,
              );
            },
          ),
        ),
        // Bottom bar
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
          decoration: BoxDecoration(
            color: kCardBg,
            border: Border(
                top: BorderSide(color: const Color(0xFFE4E0D6))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '승인한 $approvedCount개 그룹이 학생 투표 카드에 올라갑니다',
                style: const TextStyle(fontSize: 12, color: Colors.black45),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: approvedCount > 0 ? widget.onSwitchToVote : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: approvedCount > 0
                          ? kGreen
                          : kInk.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '투표 탭으로',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: approvedCount > 0
                            ? Colors.white
                            : kInk.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupApproveCard extends StatelessWidget {
  final Group group;
  final ApprovedGroup? approvedGroup;
  final String title;
  final bool approved;
  final bool isPending;
  final bool canToggle;
  final VoidCallback onApprove;
  final VoidCallback onUnapprove;
  final VoidCallback? onRename;
  final void Function(Idea idea)? onIdeaMove;
  final VoidCallback? onMerge;

  const _GroupApproveCard({
    required this.group,
    required this.approvedGroup,
    required this.title,
    required this.approved,
    required this.isPending,
    required this.canToggle,
    required this.onApprove,
    required this.onUnapprove,
    this.onRename,
    this.onIdeaMove,
    this.onMerge,
  });

  Future<void> _handleTap(BuildContext context) async {
    if (!canToggle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('투표 진행 중에는 변경할 수 없어요')),
      );
      return;
    }
    if (!approved) {
      onApprove();
      return;
    }
    // 승인 취소는 교사가 수정한 그룹명까지 함께 지우는 파괴적 액션이라 확인을 받는다.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
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
                      '승인을 취소할까요?',
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
                '"$title" 그룹이 학생 투표 카드에서 사라져요. 직접 수정한 그룹 이름도 함께 없어집니다.',
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
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: kGreen,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          '유지하기',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, true),
                    child: Container(
                      width: 104,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: kCardBg,
                        border: Border.all(color: kRed, width: 1.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        '취소',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kRed,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) onUnapprove();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: approved ? kGreen : kBorder,
          width: approved ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 14, 0),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: approved ? kGreen : kYellow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    approved ? '승인됨' : 'AI 제안',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: approved ? Colors.white : kInk,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${group.ideas.length}개 의견',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Colors.black38,
                  ),
                ),
                const Spacer(),
                // Merge chip
                GestureDetector(
                  onTap: onMerge,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: kGround,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: kBorder),
                    ),
                    child: const Text(
                      '병합',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black45,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 8, 14, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.03 * 19,
                      color: kInk,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onRename != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onRename,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: kGround,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: kBorder),
                      ),
                      child: const Text(
                        '이름 수정',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: kGreen,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Ideas list
          ...group.ideas.take(5).map((idea) => Container(
                margin: const EdgeInsets.fromLTRB(15, 0, 15, 6),
                padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
                decoration: BoxDecoration(
                  color: kGround,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${idea.speaker}  ${idea.text}',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          color: kInk,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onIdeaMove != null ? () => onIdeaMove!(idea) : null,
                      child: Text(
                        '이동',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: kGreen.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          if (group.ideas.length > 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 6),
              child: Text(
                '+ ${group.ideas.length - 5}개 더',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black38,
                ),
              ),
            ),
          const SizedBox(height: 8),
          // Action button
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: GestureDetector(
              // 투표 중에도 탭은 항상 받는다 — canToggle이 false일 때 null을 주면
              // 아무 반응이 없어 교사가 "안 눌렸나?" 하고 재탭하는 습관이 생기고,
              // 투표가 닫힌 뒤 같은 자리를 누르면 실제로 승인이 삭제됐다(Mercury-4-Organize-01).
              onTap: isPending ? null : () => _handleTap(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: approved
                      ? kCardBg
                      : (canToggle ? kGreen : kInk.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(14),
                  border: approved
                      ? Border.all(color: kGreen, width: 1.5)
                      : null,
                ),
                child: isPending
                    ? Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            // kGreen 배경(미승인 버튼) 위 kGreen 스피너는 사실상 안 보였다
                            // (Mercury-4-Organize-04) — 배경과 반대색으로 분기
                            color: approved ? kGreen : Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        approved ? '승인 취소' : '승인하기',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: approved
                              ? kGreen
                              : (canToggle
                                  ? Colors.white
                                  : kInk.withValues(alpha: 0.4)),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 투표 탭 ───────────────────────────────────────────────────────────────────

class _VoteTab extends StatefulWidget {
  final SessionState session;
  final FirebaseMoamalRepository repo;
  final String sessionCode;
  final VoidCallback onSwitchToApprove;

  const _VoteTab({
    required this.session,
    required this.repo,
    required this.sessionCode,
    required this.onSwitchToApprove,
  });

  @override
  State<_VoteTab> createState() => _VoteTabState();
}

class _VoteTabState extends State<_VoteTab> {
  bool _isToggling = false;

  Future<void> _toggleVote() async {
    if (_isToggling) return;
    setState(() => _isToggling = true);
    try {
      await widget.repo.setVoteOpen(
          widget.sessionCode, !widget.session.voteOpen);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final approved = session.approvedGroups;
    // 투표율 분모는 접속 중인 학생 — 나간 학생은 투표할 수 없다 (Gemini-1-Exit-01)
    final totalParticipants = session.activeParticipants.length;
    final votedCount = session.votes.length;
    final notVotedCount =
        totalParticipants > votedCount ? totalParticipants - votedCount : 0;

    // Vote counts per group
    final counts = <String, int>{};
    for (final gid in session.votes.values) {
      counts[gid] = (counts[gid] ?? 0) + 1;
    }
    final maxVotes = counts.values.isEmpty
        ? 1
        : counts.values.reduce((a, b) => a > b ? a : b);

    // 1위 group id
    String? topGroupId;
    if (session.voteOpen && counts.isNotEmpty) {
      topGroupId = counts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            children: [
              DemoVotePanel(key: ValueKey(session.sessionCode), session: session),
              // Stat row
              _VoteStatRow(
                totalParticipants: totalParticipants,
                votedCount: votedCount,
                notVotedCount: notVotedCount,
                voteOpen: session.voteOpen,
              ),
              const SizedBox(height: 16),
              if (approved.isEmpty) ...[
                // Empty state
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorder),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                            color: kYellow, shape: BoxShape.circle),
                        child: const Center(
                          child: Text('!',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: kInk)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '승인한 그룹이 없어 투표를 시작할 수 없어요',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: kInk,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '승인 탭에서 후보를 먼저 승인하세요',
                        style:
                            TextStyle(fontSize: 12.5, color: Colors.black38),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: widget.onSwitchToApprove,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: kGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '승인 탭으로',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  '승인된 후보 그룹 · 실시간 득표',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kInk.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 10),
                ...approved.map((group) {
                  final c = counts[group.groupId] ?? 0;
                  final isTop = group.groupId == topGroupId;
                  final ratio = maxVotes > 0 ? c / maxVotes : 0.0;
                  final pct = votedCount > 0
                      ? (c / votedCount * 100).round()
                      : 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                      decoration: BoxDecoration(
                        color: kCardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isTop && session.voteOpen
                              ? kYellow
                              : kBorder,
                          width: isTop && session.voteOpen ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  group.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: kInk,
                                  ),
                                ),
                              ),
                              Text(
                                session.voteOpen ? '$c표 · $pct%' : '—',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: kGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: LinearProgressIndicator(
                              value: session.voteOpen ? ratio : 0,
                              minHeight: 12,
                              backgroundColor:
                                  kInk.withValues(alpha: 0.09),
                              valueColor: AlwaysStoppedAnimation(
                                isTop && session.voteOpen
                                    ? kYellow
                                    : kGreen.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        // Bottom action area
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          decoration: BoxDecoration(
            color: kGround,
            border: Border(top: BorderSide(color: kBorder)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: approved.isEmpty || _isToggling ? null : _toggleVote,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: approved.isEmpty
                          ? kInk.withValues(alpha: 0.14)
                          : (session.voteOpen
                              ? const Color(0xFFD32F2F)
                              : kGreen),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: _isToggling
                        ? const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            ),
                          )
                        : Text(
                            session.voteOpen
                                ? '투표 닫고 결과 확정'
                                : '투표 시작',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.w700,
                              color: approved.isEmpty
                                  ? kInk.withValues(alpha: 0.4)
                                  : Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              if (session.voteOpen) ...[
                const SizedBox(height: 8),
                Text(
                  '닫으면 학생 화면에 결과가 공개되고 더 투표할 수 없습니다',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: kInk.withValues(alpha: 0.45),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _VoteStatRow extends StatelessWidget {
  final int totalParticipants;
  final int votedCount;
  final int notVotedCount;
  final bool voteOpen;

  const _VoteStatRow({
    required this.totalParticipants,
    required this.votedCount,
    required this.notVotedCount,
    required this.voteOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCell(
          label: '참여 학생',
          value: '$totalParticipants',
          highlight: false,
        ),
        const SizedBox(width: 8),
        _StatCell(
          label: '투표 완료',
          value: voteOpen ? '$votedCount' : '—',
          highlight: true,
        ),
        const SizedBox(width: 8),
        _StatCell(
          label: '미참여',
          value: voteOpen ? '$notVotedCount' : '—',
          highlight: false,
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _StatCell({
    required this.label,
    required this.value,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: highlight ? kGreen : kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: highlight ? null : Border.all(color: kBorder),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.03 * 22,
                color: highlight ? kYellow : kGreen,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: highlight
                    ? Colors.white.withValues(alpha: 0.7)
                    : kInk.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sidebar stat widget ───────────────────────────────────────────────────────

class _SidebarStat extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;

  const _SidebarStat({
    required this.label,
    required this.value,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent
            ? kYellow.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: accent ? kYellow : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 병합 시트 (8d) ────────────────────────────────────────────────────────────

class _MergeGroupSheet extends StatefulWidget {
  final Group sourceGroup;
  final String sourceTitle;
  final List<Group> otherGroups;
  final GeminiGroupingEngine groupingEngine;

  const _MergeGroupSheet({
    required this.sourceGroup,
    required this.sourceTitle,
    required this.otherGroups,
    required this.groupingEngine,
  });

  @override
  State<_MergeGroupSheet> createState() => _MergeGroupSheetState();
}

class _MergeGroupSheetState extends State<_MergeGroupSheet> {
  final _selectedIds = <String>{};
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.sourceTitle);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  int get _totalIdeas {
    int count = widget.sourceGroup.ideas.length;
    for (final g in widget.otherGroups) {
      if (_selectedIds.contains(g.id)) count += g.ideas.length;
    }
    return count;
  }

  void _doMerge() {
    final name = _nameCtrl.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final engine = widget.groupingEngine;
    engine.mergeGroups(
      widget.sourceGroup.id,
      _selectedIds.toList(),
      name.isEmpty ? widget.sourceTitle : name,
    );
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content: const Text('그룹이 병합되었습니다'),
      action: SnackBarAction(
        label: '되돌리기',
        onPressed: engine.undoMerge,
      ),
      duration: const Duration(seconds: 5),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final canMerge = _selectedIds.isNotEmpty;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Container(
      decoration: const BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 26,
        left: 20,
        right: 20,
        top: 18,
      ),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: kInk.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          const Text(
            '그룹 병합',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
          ),
          const SizedBox(height: 14),
          // Source group card
          Container(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
            decoration: BoxDecoration(
              color: kGround,
              border: Border.all(color: kGreen, width: 2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '지금 그룹',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kGreen,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        widget.sourceTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.03 * 17,
                          color: kInk,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      '의견 ${widget.sourceGroup.ideas.length}건',
                      style: TextStyle(
                        fontSize: 12,
                        color: kInk.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Target group list
          Text(
            '합칠 그룹 고르기 · 여러 개 선택 가능',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kInk.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.otherGroups.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final g = widget.otherGroups[i];
                final selected = _selectedIds.contains(g.id);
                final title = widget.groupingEngine.makeGroupTitle(g);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedIds.remove(g.id);
                    } else {
                      _selectedIds.add(g.id);
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    decoration: BoxDecoration(
                      color: kCardBg,
                      border: Border.all(
                        color: selected ? kYellow : kBorder,
                        width: selected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        // Checkbox
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: selected ? kYellow : Colors.transparent,
                            border: selected
                                ? null
                                : Border.all(color: kBorderDark, width: 2),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: selected
                              ? const Center(
                                  child: Text(
                                    '✓',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: kInk,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: kInk,
                              overflow: TextOverflow.ellipsis,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${g.ideas.length}건',
                          style: TextStyle(
                            fontSize: 12,
                            color: kInk.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          // Merged group name
          Text(
            '병합 후 그룹명',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kInk.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: kCardBg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kGreen, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kGreen, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kGreen, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '의견 $_totalIdeas건이 한 그룹으로 합쳐집니다 · 병합 직후 되돌리기 가능',
            style: TextStyle(
              fontSize: 11.5,
              color: kInk.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 14),
          // Action buttons
          Row(
            children: [
              SizedBox(
                width: 104,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: kCardBg,
                      border: Border.all(color: kGreen, width: 1.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      '취소',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kGreen,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: canMerge ? _doMerge : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: canMerge ? kGreen : kInk.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '병합하기',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: canMerge
                            ? Colors.white
                            : kInk.withValues(alpha: 0.35),
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
      ),
    );
  }
}

// ── 그룹 이동 시트 (6b) ────────────────────────────────────────────────────────

class _MoveGroupSheet extends StatefulWidget {
  final Idea idea;
  final String? currentGroupId;
  final List<Group> groups;
  final GeminiGroupingEngine groupingEngine;

  const _MoveGroupSheet({
    required this.idea,
    required this.currentGroupId,
    required this.groups,
    required this.groupingEngine,
  });

  @override
  State<_MoveGroupSheet> createState() => _MoveGroupSheetState();
}

class _MoveGroupSheetState extends State<_MoveGroupSheet> {
  String? _selectedGroupId;

  List<Group> get _targets => widget.groups
      .where((g) => g.id != widget.currentGroupId)
      .toList();

  void _doMove(String? targetGroupId) {
    widget.groupingEngine.moveIdea(
      widget.idea.id,
      targetGroupId,
      ideaFallback: widget.idea,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final targets = _targets;
    final canMove = _selectedGroupId != null;

    return Container(
      decoration: const BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 26,
        left: 20,
        right: 20,
        top: 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: kInk.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          const Text(
            '어느 그룹으로 옮길까요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
          ),
          const SizedBox(height: 12),
          // Idea preview card
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: kGround,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.idea.speaker,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kGreen,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.idea.text,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.55,
                    color: kInk,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Group list
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: targets.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '이동할 수 있는 다른 그룹이 없습니다',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: kInk.withValues(alpha: 0.4),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: targets.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final g = targets[i];
                      final isSelected = _selectedGroupId == g.id;
                      final title = widget.groupingEngine.makeGroupTitle(g);
                      return GestureDetector(
                        onTap: () => setState(
                            () => _selectedGroupId = isSelected ? null : g.id),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
                          decoration: BoxDecoration(
                            color: isSelected ? kGreen : kGround,
                            border: Border.all(
                              color: isSelected ? kGreen : kBorderMid,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : kInk,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${g.ideas.length}개',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.65)
                                      : kInk.withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 14),
          // Action buttons
          Row(
            children: [
              // 새 그룹
              SizedBox(
                width: 110,
                child: GestureDetector(
                  onTap: () => _doMove(null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: kCardBg,
                      border: Border.all(color: kGreen, width: 1.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      '새 그룹',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kGreen,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 옮기기
              Expanded(
                child: GestureDetector(
                  onTap: canMove ? () => _doMove(_selectedGroupId) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: canMove ? kGreen : kInk.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '옮기기',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: canMove
                            ? Colors.white
                            : kInk.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
