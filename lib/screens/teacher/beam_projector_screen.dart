import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/approved_group.dart';
import '../../models/session_state.dart';
import '../../services/deep_link_service.dart';
import '../../theme/app_theme.dart';

const _kMarks = ['ㄱ', 'ㄴ', 'ㄷ', 'ㄹ', 'ㅁ', 'ㅂ'];

enum _BeamStage { joining, collecting, voting, results }

_BeamStage _stageOf(SessionState s) {
  if (s.ideas.isEmpty) return _BeamStage.joining;
  if (s.voteOpen) return _BeamStage.voting;
  if (s.votes.isNotEmpty) return _BeamStage.results;
  return _BeamStage.collecting;
}

String _stageLabel(_BeamStage stage) => switch (stage) {
      _BeamStage.joining => '입장',
      _BeamStage.collecting => '의견 수집',
      _BeamStage.voting => '투표 진행 중',
      _BeamStage.results => '결과',
    };

class BeamProjectorScreen extends StatefulWidget {
  final String sessionCode;
  final Stream<SessionState> sessionStream;
  final SessionState initialSession;

  const BeamProjectorScreen({
    super.key,
    required this.sessionCode,
    required this.sessionStream,
    required this.initialSession,
  });

  @override
  State<BeamProjectorScreen> createState() => _BeamProjectorScreenState();
}

class _BeamProjectorScreenState extends State<BeamProjectorScreen>
    with TickerProviderStateMixin {
  late SessionState _session;
  StreamSubscription<SessionState>? _sub;

  late final AnimationController _barCtrl;
  late final AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;

    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _sub = widget.sessionStream.listen((s) {
      if (mounted) setState(() => _session = s);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _barCtrl.dispose();
    _blinkCtrl.dispose();
    super.dispose();
  }

  Map<String, int> _voteCounts() {
    final counts = <String, int>{};
    for (final groupId in _session.votes.values) {
      counts[groupId] = (counts[groupId] ?? 0) + 1;
    }
    return counts;
  }

  double _blinkOpacity() {
    final t = _blinkCtrl.value;
    return t < 0.5 ? 1.0 - t * 2 * 0.85 : 0.15 + (t - 0.5) * 2 * 0.85;
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stageOf(_session);
    return Scaffold(
      backgroundColor: kGreen,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            return isLandscape
                ? _buildLandscape(stage, constraints)
                : _buildPortrait(stage);
          },
        ),
      ),
    );
  }

  // ── Landscape ─────────────────────────────────────────────────────────────

  Widget _buildLandscape(_BeamStage stage, BoxConstraints outer) {
    return Column(
      children: [
        _buildLandscapeHeader(stage),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: stage == _BeamStage.joining ? 38 : 36,
                ),
                child: _buildLandscapeContent(stage),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeHeader(_BeamStage stage) {
    return Container(
      padding: const EdgeInsets.fromLTRB(48, 26, 48, 26),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
      ),
      child: Row(
        children: [
          _LogoText(fontSize: 30),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              _session.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.72),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 20),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _blinkCtrl,
                  builder: (_, _) => Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: kYellow.withValues(alpha: _blinkOpacity()),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _stageLabel(stage),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeContent(_BeamStage stage) => switch (stage) {
        _BeamStage.joining => _buildJoiningLandscape(),
        _BeamStage.collecting => _buildCollectingLandscape(),
        _BeamStage.voting => _buildVotingLandscape(),
        _BeamStage.results => _buildResultsLandscape(),
      };

  // Stage 1 — 입장 (landscape)
  Widget _buildJoiningLandscape() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(24),
          ),
          child: QrImageView(
            data: DeepLinkService.buildJoinUri(_session.sessionCode),
            version: QrVersions.auto,
            size: 180,
          ),
        ),
        const SizedBox(width: 56),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '폰으로 QR을 찍거나\n코드를 입력하세요',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.72),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              _CodeCells(code: _session.sessionCode, fontSize: 66, cellRadius: 16, gap: 11, cellAspect: 1 / 1.15),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${_session.participants.length}',
                    style: const TextStyle(
                      fontSize: 76,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -3.04,
                      height: 1,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '명 들어왔어요',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Stage 2 — 의견수집 (landscape)
  Widget _buildCollectingLandscape() {
    final submitters = _session.ideas.map((i) => i.speaker).toSet().length;
    final total = _session.participants.length;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '선생님 질문',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: kYellow,
            letterSpacing: 0.52,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _session.title,
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w900,
            letterSpacing: -2.24,
            height: 1.25,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 40),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 34, vertical: 26),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              _AnimBars(
                controller: _barCtrl,
                barColor: kYellow,
                barWidth: 9,
                maxBarHeight: 46,
                count: 4,
                barSpacing: 6,
              ),
              const SizedBox(width: 26),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$submitters',
                      style: const TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2.4,
                        height: 1,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '명 제출 · $total명 중',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '코드 ${_session.sessionCode}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Stage 4 — 투표 (landscape)
  Widget _buildVotingLandscape() {
    final candidates = _session.approvedGroups;
    final voters = _session.votes.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Expanded(
              child: Text(
                '폰에서 하나를 골라요',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.02,
                  color: Colors.white,
                ),
              ),
            ),
            Text(
              '$voters명 참여',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: kYellow,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Column(
            children: [
              for (int i = 0; i < candidates.length && i < 5; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                Expanded(
                  child: _CandidateCardLandscape(
                    group: candidates[i],
                    mark: i < _kMarks.length ? _kMarks[i] : '${i + 1}',
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            '투표가 끝나면 결과를 함께 볼게요',
            style: TextStyle(
              fontSize: 22,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ),
      ],
    );
  }

  // Stage 5 — 결과 (landscape)
  Widget _buildResultsLandscape() {
    final counts = _voteCounts();
    final totalVotes = _session.votes.length;
    final totalParticipants = _session.participants.length;

    final sorted = [..._session.approvedGroups]
      ..sort((a, b) =>
          (counts[b.groupId] ?? 0).compareTo(counts[a.groupId] ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text(
              '투표 결과',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.02,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Text(
              '$totalParticipants명 중 $totalVotes명 참여',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Column(
            children: [
              for (int i = 0; i < sorted.length && i < 5; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                Expanded(
                  child: _ResultCardLandscape(
                    group: sorted[i],
                    voteCount: counts[sorted[i].groupId] ?? 0,
                    totalVotes: totalVotes,
                    isWinner: i == 0,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Portrait ──────────────────────────────────────────────────────────────

  Widget _buildPortrait(_BeamStage stage) {
    return Column(
      children: [
        _buildPortraitHeader(stage),
        Expanded(
          child: switch (stage) {
            _BeamStage.joining => _buildJoiningPortrait(),
            _BeamStage.collecting => _buildCollectingPortrait(),
            _BeamStage.voting => _buildVotingPortrait(_session.votes.length),
            _BeamStage.results => _buildResultsPortrait(),
          },
        ),
      ],
    );
  }

  Widget _buildPortraitHeader(_BeamStage stage) {
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 20, 26, 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
      ),
      child: Row(
        children: [
          _LogoText(fontSize: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _session.title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.65),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedBuilder(
            animation: _blinkCtrl,
            builder: (_, _) => Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: kYellow.withValues(alpha: _blinkOpacity()),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Stage 1 — 입장 (portrait)
  Widget _buildJoiningPortrait() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: QrImageView(
            data: DeepLinkService.buildJoinUri(_session.sessionCode),
            version: QrVersions.auto,
            size: 150,
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _CodeCells(code: _session.sessionCode, fontSize: 30, cellRadius: 11, gap: 7, cellAspect: 1 / 1.15),
        ),
        const SizedBox(height: 18),
        Text(
          '폰으로 QR을 찍거나\n코드를 입력하세요',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.72),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${_session.participants.length}',
              style: const TextStyle(
                fontSize: 46,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.84,
                height: 1,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              '명 들어왔어요',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Stage 2 — 의견수집 (portrait)
  Widget _buildCollectingPortrait() {
    final submitters = _session.ideas.map((i) => i.speaker).toSet().length;
    final total = _session.participants.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          const Text(
            '선생님 질문',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kYellow,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _session.title,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.26,
              height: 1.3,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                _AnimBars(
                  controller: _barCtrl,
                  barColor: kYellow,
                  barWidth: 7,
                  maxBarHeight: 36,
                  count: 4,
                  barSpacing: 5,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$submitters',
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '명 제출 · $total명',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Stage 4 — 투표 (portrait)
  Widget _buildVotingPortrait(int voters) {
    final candidates = _session.approvedGroups;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Expanded(
                child: Text(
                  '폰에서 골라요',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.66,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '$voters명 참여',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kYellow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Column(
              children: [
                for (int i = 0; i < candidates.length && i < 5; i++) ...[
                  if (i > 0) const SizedBox(height: 11),
                  Expanded(
                    child: _CandidateCardPortrait(
                      group: candidates[i],
                      mark: i < _kMarks.length ? _kMarks[i] : '${i + 1}',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '투표가 끝나면\n결과를 함께 볼게요',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Stage 5 — 결과 (portrait) — compact version
  Widget _buildResultsPortrait() {
    final counts = _voteCounts();
    final totalVotes = _session.votes.length;

    final sorted = [..._session.approvedGroups]
      ..sort((a, b) =>
          (counts[b.groupId] ?? 0).compareTo(counts[a.groupId] ?? 0));

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Expanded(
                child: Text(
                  '투표 결과',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.66,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '$totalVotes명 참여',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Column(
              children: [
                for (int i = 0; i < sorted.length && i < 5; i++) ...[
                  if (i > 0) const SizedBox(height: 11),
                  Expanded(
                    child: _ResultCardPortrait(
                      group: sorted[i],
                      voteCount: counts[sorted[i].groupId] ?? 0,
                      totalVotes: totalVotes,
                      isWinner: i == 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _LogoText extends StatelessWidget {
  final double fontSize;
  const _LogoText({required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: fontSize * -0.03,
          color: Colors.white,
        ),
        children: const [
          TextSpan(text: '모아'),
          TextSpan(text: '말', style: TextStyle(color: kYellow)),
        ],
      ),
    );
  }
}

// 6개 kYellow 코드 셀
class _CodeCells extends StatelessWidget {
  final String code;
  final double fontSize;
  final double cellRadius;
  final double gap;
  final double cellAspect;

  const _CodeCells({
    required this.code,
    required this.fontSize,
    required this.cellRadius,
    required this.gap,
    required this.cellAspect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < code.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(
            child: AspectRatio(
              aspectRatio: cellAspect,
              child: Container(
                decoration: BoxDecoration(
                  color: kYellow,
                  borderRadius: BorderRadius.circular(cellRadius),
                ),
                child: Center(
                  child: Text(
                    code[i],
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: fontSize * -0.04,
                      color: kInk,
                    ),
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

// 막대 애니메이션 (수집/정리 단계)
class _AnimBars extends StatelessWidget {
  final AnimationController controller;
  final Color barColor;
  final double barWidth;
  final double maxBarHeight;
  final int count;
  final double barSpacing;

  const _AnimBars({
    required this.controller,
    required this.barColor,
    required this.barWidth,
    required this.maxBarHeight,
    required this.count,
    required this.barSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        return SizedBox(
          height: maxBarHeight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(count, (i) {
              final delay = i / count;
              final t = (controller.value + delay) % 1.0;
              final scale = 0.25 + 0.75 * math.sin(t * math.pi);
              return Container(
                margin: EdgeInsets.only(left: i > 0 ? barSpacing : 0),
                width: barWidth,
                height: (maxBarHeight * scale).clamp(maxBarHeight * 0.25, maxBarHeight),
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// ── Candidate card — landscape ────────────────────────────────────────────────

class _CandidateCardLandscape extends StatelessWidget {
  final ApprovedGroup group;
  final String mark;
  const _CandidateCardLandscape({required this.group, required this.mark});

  @override
  Widget build(BuildContext context) {
    final ideaCount = group.ideaIds.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: kGround,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorderDark, width: 2),
            ),
            child: Center(
              child: Text(
                mark,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: kInk.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.title,
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.14,
                    height: 1.2,
                    color: kInk,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (ideaCount > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '의견 $ideaCount개',
                    style: TextStyle(
                      fontSize: 24,
                      color: kInk.withValues(alpha: 0.5),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Candidate card — portrait ─────────────────────────────────────────────────

class _CandidateCardPortrait extends StatelessWidget {
  final ApprovedGroup group;
  final String mark;
  const _CandidateCardPortrait({required this.group, required this.mark});

  @override
  Widget build(BuildContext context) {
    final ideaCount = group.ideaIds.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kGround,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: kBorderDark, width: 2),
            ),
            child: Center(
              child: Text(
                mark,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: kInk.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.72,
                    height: 1.2,
                    color: kInk,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (ideaCount > 0) ...[
                  const SizedBox(height: 5),
                  Text(
                    '의견 $ideaCount개',
                    style: TextStyle(
                      fontSize: 15,
                      color: kInk.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Result card — landscape ───────────────────────────────────────────────────

class _ResultCardLandscape extends StatelessWidget {
  final ApprovedGroup group;
  final int voteCount;
  final int totalVotes;
  final bool isWinner;

  const _ResultCardLandscape({
    required this.group,
    required this.voteCount,
    required this.totalVotes,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalVotes > 0 ? (voteCount / totalVotes * 100).round() : 0;
    final barValue = totalVotes > 0 ? voteCount / totalVotes : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: BoxDecoration(
        color: isWinner ? kYellow : kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: isWinner ? Border.all(color: kInk, width: 2) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.title,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.08,
                    height: 1.2,
                    color: kInk,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                    height: 16,
                    child: LinearProgressIndicator(
                      value: barValue,
                      backgroundColor: isWinner
                          ? kInk.withValues(alpha: 0.18)
                          : kBorderMid,
                      valueColor: AlwaysStoppedAnimation(
                        isWinner ? kInk : kGreen.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 26),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$voteCount',
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2.08,
                  height: 1,
                  color: kInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '표 · $pct%',
                style: TextStyle(
                  fontSize: 22,
                  color: isWinner
                      ? kInk.withValues(alpha: 0.65)
                      : kInk.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Result card — portrait ────────────────────────────────────────────────────

class _ResultCardPortrait extends StatelessWidget {
  final ApprovedGroup group;
  final int voteCount;
  final int totalVotes;
  final bool isWinner;

  const _ResultCardPortrait({
    required this.group,
    required this.voteCount,
    required this.totalVotes,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalVotes > 0 ? (voteCount / totalVotes * 100).round() : 0;
    final barValue = totalVotes > 0 ? voteCount / totalVotes : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isWinner ? kYellow : kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: isWinner ? Border.all(color: kInk, width: 2) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.66,
                    height: 1.2,
                    color: kInk,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 10,
                    child: LinearProgressIndicator(
                      value: barValue,
                      backgroundColor: isWinner
                          ? kInk.withValues(alpha: 0.18)
                          : kBorderMid,
                      valueColor: AlwaysStoppedAnimation(
                        isWinner ? kInk : kGreen.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$voteCount',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.28,
                  height: 1,
                  color: kInk,
                ),
              ),
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 14,
                  color: kInk.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
