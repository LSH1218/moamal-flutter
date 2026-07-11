import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/group.dart';
import '../../models/meeting_report.dart';
import '../../models/session_state.dart';
import '../../repositories/firebase_moamal_repository.dart';
import '../../services/auth_service.dart';
import '../../services/gemini_api_client.dart';
import '../../services/gemini_grouping_engine.dart';
import '../../services/whisper_stt_client.dart';
import '../../theme/app_theme.dart';
import 'cluster_vote_screen.dart';
import 'report_screen.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  late FirebaseMoamalRepository _repo;
  late AuthService _auth;
  late GeminiGroupingEngine _groupingEngine;

  SessionState _session = SessionState.initial();
  List<Group> _groups = [];
  String? _aiBriefingFlow;
  MeetingReport? _meetingReport;
  bool _isGeneratingReport = false;
  bool _isLoading = true;

  // LIVE 화면 상태
  late DateTime _sessionStart;
  String _elapsedText = '00:00';
  Timer? _elapsedTimer;

  // 교사 STT
  final _sttClient = WhisperSttClient();
  String? _latestTranscript;
  _MicStatus _micStatus = _MicStatus.idle;

  @override
  void initState() {
    super.initState();
    _groupingEngine = GeminiGroupingEngine(onUpdate: _onGroupingUpdated);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSession());
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _repo.stopListening();
    _sttClient.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    _auth = context.read<AuthService>();
    _repo = context.read<FirebaseMoamalRepository>();

    final uid = _auth.currentUid!;
    final newSession = _session.copyWith(ownerUid: uid);
    await _repo.publishSession(newSession);

    _repo.listenToSession(newSession.sessionCode).listen((state) {
      if (!mounted) return;
      setState(() {
        _session = state;
        _groups = _groupingEngine.makeGroups(state.ideas);
      });
    });

    _sessionStart = DateTime.now();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedText = _formatElapsed());
    });

    setState(() {
      _session = newSession;
      _isLoading = false;
    });
  }

  String _formatElapsed() {
    final d = DateTime.now().difference(_sessionStart);
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _onGroupingUpdated() {
    if (!mounted) return;
    setState(() {
      _groups = _groupingEngine.makeGroups(_session.ideas);
    });
    if (_groups.isEmpty) return;
    GeminiApiClient()
        .generateBriefing(_session.title, _groups, _session.ideas)
        .then((r) {
      if (!mounted) return;
      setState(() => _aiBriefingFlow = r.flow);
    }).catchError((_) {});
  }

  Future<void> _generateReport() async {
    if (_isGeneratingReport || _groups.isEmpty) return;
    setState(() => _isGeneratingReport = true);
    try {
      final counts = _groupingEngine.voteCounts(_groups, _session.votes);
      final report = await GeminiApiClient()
          .generateReport(_session.title, _groups, counts, 0);
      if (mounted) setState(() => _meetingReport = report);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('리포트 생성 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingReport = false);
    }
  }

  Future<void> _resetSession() async {
    _groupingEngine.reset();
    _repo.stopListening();
    final newSession =
        SessionState.initial().copyWith(ownerUid: _auth.currentUid);
    await _repo.publishSession(newSession);
    _repo.listenToSession(newSession.sessionCode).listen((state) {
      if (!mounted) return;
      setState(() {
        _session = state;
        _groups = _groupingEngine.makeGroups(state.ideas);
      });
    });
    _sessionStart = DateTime.now();
    if (mounted) {
      setState(() {
        _session = newSession;
        _groups = [];
        _aiBriefingFlow = null;
        _meetingReport = null;
        _elapsedText = '00:00';
        _latestTranscript = null;
      });
    }
  }

  // ── 교사 마이크 ──────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (_micStatus != _MicStatus.idle) return;
    try {
      await _sttClient.startRecording();
      if (mounted) setState(() => _micStatus = _MicStatus.recording);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _stopAndTranscribe() async {
    if (_micStatus != _MicStatus.recording) return;
    setState(() => _micStatus = _MicStatus.transcribing);
    try {
      final text = await _sttClient.stopAndTranscribe();
      if (mounted) setState(() => _latestTranscript = text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _micStatus = _MicStatus.idle);
    }
  }

  Future<void> _cancelRecording() async {
    if (_micStatus == _MicStatus.recording) {
      await _sttClient.cancel();
      if (mounted) setState(() => _micStatus = _MicStatus.idle);
    }
  }

  // ── 화면 빌드 ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: kGround,
        body: Center(child: CircularProgressIndicator(color: kGreen)),
      );
    }

    final isCompact = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: kGround,
      appBar: _buildAppBar(isCompact),
      body: isCompact ? _buildCompactBody() : _buildMediumBody(),
      floatingActionButton: isCompact ? _buildFab() : null,
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
    );
  }

  PreferredSizeWidget _buildAppBar(bool isCompact) {
    return AppBar(
      backgroundColor: kGreen,
      foregroundColor: Colors.white,
      titleSpacing: 16,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  _session.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              const _LiveBadge(),
            ],
          ),
          Text(
            '$_elapsedText 경과 · 학생 ${_session.ideas.length}명 발언',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        // 의견 모음 화면으로
        IconButton(
          icon: const Icon(Icons.bubble_chart_outlined),
          tooltip: '의견 모음',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClusterVoteScreen(
                sessionCode: _session.sessionCode,
                groups: _groups,
                repo: _repo,
                groupingEngine: _groupingEngine,
                onTitleChanged: (title) async {
                  final updated = _session.copyWith(title: title);
                  await _repo.publishSession(updated);
                },
                onReset: _resetSession,
                onEndSession: _goToReport,
              ),
            ),
          ),
        ),
        // 수업 종료
        IconButton(
          icon: const Icon(Icons.stop_circle_outlined),
          tooltip: '수업 종료',
          onPressed: _goToReport,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _goToReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportScreen(
          session: _session,
          groups: _groups,
          groupingEngine: _groupingEngine,
          elapsedText: _elapsedText,
          meetingReport: _meetingReport,
          isGeneratingReport: _isGeneratingReport,
          onGenerateReport: _generateReport,
        ),
      ),
    );
  }

  // ── Compact 바디: STT 박스 → Green 요약 패널 ─────────────────────────────
  Widget _buildCompactBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: _SttBox(
            transcript: _latestTranscript ??
                (_session.ideas.isNotEmpty
                    ? _session.ideas.last.text
                    : null),
            height: 130,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            color: kGreen,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            child: _SummaryPanel(
              groups: _groups,
              groupingEngine: _groupingEngine,
              aiBriefingFlow: _aiBriefingFlow,
              textColor: Colors.white,
              emptyColor: Colors.white60,
            ),
          ),
        ),
      ],
    );
  }

  // ── Medium 바디: Green 요약(왼) + STT+반응(오) + FAB overlay ────────────
  Widget _buildMediumBody() {
    final w = MediaQuery.sizeOf(context).width;

    return Stack(
      children: [
        Row(
          children: [
            // 왼쪽: 누적 요약 (Green)
            SizedBox(
              width: w * 0.55,
              child: Container(
                color: kGreen,
                padding: const EdgeInsets.all(24),
                child: SafeArea(
                  top: false,
                  child: _SummaryPanel(
                    groups: _groups,
                    groupingEngine: _groupingEngine,
                    aiBriefingFlow: _aiBriefingFlow,
                    textColor: Colors.white,
                    emptyColor: Colors.white60,
                  ),
                ),
              ),
            ),
            // 오른쪽: STT + 학생 반응
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 80, 0),
                      child: _SttBox(
                        transcript: _latestTranscript ??
                            (_session.ideas.isNotEmpty
                                ? _session.ideas.last.text
                                : null),
                        height: double.infinity,
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    child: _StudentReactionRow(session: _session),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Yellow FAB 오른쪽 상단
        Positioned(
          top: 16,
          right: 16,
          child: _buildFab(),
        ),
      ],
    );
  }

  Widget _buildFab() {
    final (icon, bg) = switch (_micStatus) {
      _MicStatus.idle => (Icons.mic_none, kYellow),
      _MicStatus.recording => (Icons.mic, const Color(0xFFD32F2F)),
      _MicStatus.transcribing => (Icons.hourglass_top, Colors.grey),
    };

    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopAndTranscribe(),
      onLongPressCancel: () => _cancelRecording(),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: kInk, size: 28),
      ),
    );
  }
}

// ── STT 실시간 음성 박스 ──────────────────────────────────────────────────
class _SttBox extends StatelessWidget {
  final String? transcript;
  final double height;

  const _SttBox({required this.transcript, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '실시간 음성',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black38,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: transcript == null || transcript!.isEmpty
                ? const Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      '마이크 버튼을 길게 누르면\n발화가 여기에 표시됩니다.',
                      style: TextStyle(fontSize: 14, color: Colors.black38),
                    ),
                  )
                : Text(
                    '"$transcript"',
                    style: const TextStyle(
                      fontSize: 16,
                      color: kInk,
                      height: 1.55,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── 누적 요약 패널 ────────────────────────────────────────────────────────
class _SummaryPanel extends StatelessWidget {
  final List<Group> groups;
  final GeminiGroupingEngine groupingEngine;
  final String? aiBriefingFlow;
  final Color textColor;
  final Color emptyColor;

  const _SummaryPanel({
    required this.groups,
    required this.groupingEngine,
    required this.aiBriefingFlow,
    required this.textColor,
    required this.emptyColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '누적 요약',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 14),
        if (groups.isEmpty)
          Text(
            '의견이 들어오면 자동으로 요약됩니다.',
            style: TextStyle(fontSize: 14, color: emptyColor),
          )
        else
          ...groups.asMap().entries.map(
            (e) => _SummaryItem(
              index: e.key + 1,
              title: groupingEngine.makeGroupTitle(e.value),
              summary: e.value.summary,
              textColor: textColor,
            ),
          ),
        if (aiBriefingFlow != null && groups.isEmpty) ...[
          const SizedBox(height: 10),
          Text(
            aiBriefingFlow!,
            style: TextStyle(fontSize: 14, color: textColor),
          ),
        ],
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final int index;
  final String title;
  final String summary;
  final Color textColor;

  const _SummaryItem({
    required this.index,
    required this.title,
    required this.summary,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(right: 10, top: 1),
            decoration: BoxDecoration(
              color: kYellow,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: kInk,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    height: 1.4,
                  ),
                ),
                if (summary.isNotEmpty)
                  Text(
                    summary,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 학생 반응 (Medium 하단) ───────────────────────────────────────────────
class _StudentReactionRow extends StatelessWidget {
  final SessionState session;

  const _StudentReactionRow({required this.session});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ReactionChip(
            count: session.ideas.length,
            label: '발언',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ReactionChip(
            count: session.votes.length,
            label: '투표',
          ),
        ),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final int count;
  final String label;

  const _ReactionChip({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '$count명',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: kGreen,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black38)),
        ],
      ),
    );
  }
}

// ── LIVE 뱃지 ─────────────────────────────────────────────────────────────
class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _ctrl,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

enum _MicStatus { idle, recording, transcribing }
