import 'package:flutter/material.dart';
import '../../models/participant.dart';
import '../../models/session_state.dart';
import '../../repositories/firebase_moamal_repository.dart';
import '../../theme/app_theme.dart';

class MicControlScreen extends StatefulWidget {
  final String sessionCode;
  final SessionState session;
  final FirebaseMoamalRepository repo;

  const MicControlScreen({
    super.key,
    required this.sessionCode,
    required this.session,
    required this.repo,
  });

  @override
  State<MicControlScreen> createState() => _MicControlScreenState();
}

class _MicControlScreenState extends State<MicControlScreen> {
  // uid → forceStop(true=꺼짐)
  final _forcedMap = <String, bool>{};
  final _pendingSet = <String>{};
  bool _loadingInitial = true;
  bool _allPending = false;

  // 나간 학생은 제어 대상이 아니다 (Gemini-1-Exit-01).
  // activeParticipants가 새 리스트를 주므로 정렬이 원본을 건드리지 않는다.
  List<Participant> get _participants => widget.session.activeParticipants
    ..sort((a, b) => a.number.compareTo(b.number));

  int get _offCount => _forcedMap.values.where((v) => v).length;
  // 교사 화면에서 학생이 실제로 녹음 중인지 알 방법 없음 — 0으로 표시
  int get _recCount => 0;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final map = <String, bool>{};
    for (final p in _participants) {
      try {
        final muted = await widget.repo
            .listenToForceStop(widget.sessionCode, p.uid)
            .first;
        map[p.uid] = muted;
      } catch (_) {
        map[p.uid] = false;
      }
    }
    if (!mounted) return;
    setState(() {
      _forcedMap.addAll(map);
      _loadingInitial = false;
    });
  }

  Future<void> _toggleOne(String uid) async {
    if (_pendingSet.contains(uid) || _allPending) return;
    final wasMuted = _forcedMap[uid] ?? false;
    setState(() {
      _pendingSet.add(uid);
      _forcedMap[uid] = !wasMuted; // optimistic
    });
    try {
      if (wasMuted) {
        await widget.repo.clearForceStop(widget.sessionCode, uid);
        await widget.repo.forceStartMic(widget.sessionCode, uid);
      } else {
        await widget.repo.forceStopMic(widget.sessionCode, uid);
        await widget.repo.clearForceStart(widget.sessionCode, uid);
      }
    } catch (e) {
      if (mounted) setState(() => _forcedMap[uid] = wasMuted); // revert
    } finally {
      if (mounted) setState(() => _pendingSet.remove(uid));
    }
  }

  Future<void> _muteAll() async {
    if (_allPending) return;
    setState(() {
      _allPending = true;
      for (final p in _participants) {
        _forcedMap[p.uid] = true;
      }
    });
    try {
      for (final p in _participants) {
        await widget.repo.forceStopMic(widget.sessionCode, p.uid);
        await widget.repo.clearForceStart(widget.sessionCode, p.uid);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    } finally {
      if (mounted) setState(() => _allPending = false);
    }
  }

  Future<void> _unmuteAll() async {
    if (_allPending) return;
    setState(() {
      _allPending = true;
      for (final p in _participants) {
        _forcedMap[p.uid] = false;
      }
    });
    try {
      for (final p in _participants) {
        await widget.repo.clearForceStop(widget.sessionCode, p.uid);
        await widget.repo.forceStartMic(widget.sessionCode, p.uid);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    } finally {
      if (mounted) setState(() => _allPending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _participants.length;

    return Scaffold(
      backgroundColor: kGround,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(total),
            _buildBulkButtons(),
            _buildNoticeCard(),
            Expanded(
              child: _loadingInitial
                  ? const Center(
                      child: CircularProgressIndicator(color: kGreen))
                  : _participants.isEmpty
                      ? _buildEmptyState()
                      : _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(int total) {
    return Container(
      color: kGreen,
      padding: const EdgeInsets.fromLTRB(14, 8, 18, 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
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
                  '마이크 제어',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '참여 $total명 · 녹음 중 $_recCount명 · 꺼짐 $_offCount명',
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

  // ── Bulk buttons ──────────────────────────────────────────────────────────

  Widget _buildBulkButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _allPending ? null : _muteAll,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _allPending
                      ? kInk.withValues(alpha: 0.5)
                      : kInk,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _allPending
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      )
                    : const Text(
                        '전체 끄기',
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
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _allPending ? null : _unmuteAll,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _allPending
                      ? kYellow.withValues(alpha: 0.5)
                      : kYellow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _allPending
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: kInk),
                        ),
                      )
                    : const Text(
                        '전체 켜기',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: kInk,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Notice card ───────────────────────────────────────────────────────────

  Widget _buildNoticeCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Text(
        '끄면 학생 화면에 "선생님이 마이크를 잠시 껐어요" 안내가 즉시 표시됩니다.',
        style: TextStyle(
          fontSize: 12,
          height: 1.55,
          color: kInk.withValues(alpha: 0.55),
        ),
      ),
    );
  }

  // ── Student list ──────────────────────────────────────────────────────────

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      itemCount: _participants.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final p = _participants[i];
        final isMuted = _forcedMap[p.uid] ?? false;
        final isPending = _pendingSet.contains(p.uid);
        return _StudentRow(
          participant: p,
          isMuted: isMuted,
          isPending: isPending,
          onToggle: () => _toggleOne(p.uid),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
                color: kYellow, shape: BoxShape.circle),
            child: const Center(
              child: Text('!',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: kInk)),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '아직 참여한 학생이 없어요',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kInk.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '학생이 코드를 입력하면 목록에 나타납니다',
            style: TextStyle(
              fontSize: 12.5,
              color: kInk.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Student row ───────────────────────────────────────────────────────────────

class _StudentRow extends StatelessWidget {
  final Participant participant;
  final bool isMuted;
  final bool isPending;
  final VoidCallback onToggle;

  const _StudentRow({
    required this.participant,
    required this.isMuted,
    required this.isPending,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: isMuted ? kGround : kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          // Status dot
          SizedBox(
            width: 12,
            height: 12,
            child: _StatusDot(isMuted: isMuted),
          ),
          const SizedBox(width: 12),
          // Number
          SizedBox(
            width: 42,
            child: Text(
              '${participant.number}번',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kGreen,
              ),
            ),
          ),
          // Name
          Expanded(
            child: Text(
              participant.name,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: kInk,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // State text
          SizedBox(
            width: 52,
            child: Text(
              isMuted ? '꺼짐' : '대기',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isMuted
                    ? kDisabled
                    : kInk.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Toggle button
          GestureDetector(
            onTap: isPending ? null : onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isPending
                    ? kGround
                    : (isMuted ? kYellow : kGround),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: kBorderMid),
              ),
              child: isPending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: kGreen),
                    )
                  : Text(
                      isMuted ? '켜기' : '끄기',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isMuted ? kInk : kInk.withValues(alpha: 0.6),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status dot (녹음 중 = kRed + 파동, 대기 = ink22%, 꺼짐 = kDisabled) ──────

class _StatusDot extends StatefulWidget {
  final bool isMuted;

  const _StatusDot({required this.isMuted});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  // AnimationController 준비됨 — 추후 학생 녹음 중 신호 수신 시 파동 애니메이션 활성화
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.isMuted ? kDisabled : kInk.withValues(alpha: 0.22);

    return Stack(
      alignment: Alignment.center,
      children: [
        // 파동 레이어 (현재는 미사용 — 녹음 중 상태가 없으므로)
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
