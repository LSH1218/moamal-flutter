import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../utils/responsive.dart';
import '../../models/group.dart';
import '../../models/meeting_report.dart';
import '../../models/session_state.dart';
import '../../repositories/firebase_moamal_repository.dart';
import '../../services/auth_service.dart';
import '../../services/ai_api_client.dart';
import '../../services/gemini_grouping_engine.dart';
import '../../services/whisper_stt_client.dart';
import '../../theme/app_theme.dart';
import 'cluster_vote_screen.dart';
import 'report_screen.dart';

class TeacherHomeScreen extends StatefulWidget {
  final String? initialTitle;
  final String? existingCode;
  const TeacherHomeScreen({super.key, this.initialTitle, this.existingCode});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  late FirebaseMoamalRepository _repo;
  late AuthService _auth;
  late GeminiGroupingEngine _groupingEngine;

  SessionState _session = SessionState.initial();
  List<Group> _groups = [];
  Stream<SessionState>? _sessionStream;
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
  bool _isToggleMode = false;
  final _teacherNotes = <String>[];

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

    final String sessionCode;
    if (widget.existingCode != null) {
      sessionCode = widget.existingCode!;
      setState(() {
        _session = _session.copyWith(sessionCode: sessionCode, ownerUid: uid);
      });
    } else {
      var newSession = _session.copyWith(ownerUid: uid);
      if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty) {
        newSession = newSession.copyWith(title: widget.initialTitle);
      }
      await _repo.publishSession(newSession);
      sessionCode = newSession.sessionCode;
      setState(() => _session = newSession);
    }

    _sessionStream = _repo.listenToSession(sessionCode);
    _sessionStream!.listen((state) {
      if (!mounted) return;
      _groupingEngine.sessionTitle = state.title;
      setState(() {
        _session = state;
        _groups = _groupingEngine.makeGroups(state.ideas);
      });
    });

    _sessionStart = DateTime.now();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedText = _formatElapsed());
    });

    setState(() => _isLoading = false);
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
    AiApiClient()
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
      final allNotes = _teacherNotes.isNotEmpty
          ? _teacherNotes
          : await _repo.getAllTeacherNotes(_session.sessionCode);
      final report = await AiApiClient().generateReport(
          _session.title, _groups, counts, 0,
          teacherNotes: allNotes);
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
    _sessionStream = _repo.listenToSession(newSession.sessionCode);
    _sessionStream!.listen((state) {
      if (!mounted) return;
      _groupingEngine.sessionTitle = state.title;
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
      _teacherNotes.clear();
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
      final text = await _sttClient.stopAndTranscribe(buildWhisperPrompt(_session.title));
      if (!mounted) return;
      if (text.isEmpty) return;
      setState(() => _latestTranscript = text);
      _teacherNotes.add(text);
      _groupingEngine.recentTeacherNotes =
          _teacherNotes.length <= 2 ? List.of(_teacherNotes) : _teacherNotes.sublist(_teacherNotes.length - 2);
      await _repo.addTeacherNote(sessionCode: _session.sessionCode, text: text, uid: _auth.currentUid!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('발문/지시 기록됨'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

  Future<void> _onMicTap() async {
    if (_micStatus == _MicStatus.idle) {
      _isToggleMode = true;
      await _startRecording();
    } else if (_micStatus == _MicStatus.recording && _isToggleMode) {
      await _stopAndTranscribe();
    }
  }

  Future<void> _onMicLongPressStart() async {
    if (_micStatus != _MicStatus.idle) return;
    _isToggleMode = false;
    await _startRecording();
  }

  Future<void> _onMicLongPressEnd() async {
    if (_micStatus != _MicStatus.recording || _isToggleMode) return;
    await _stopAndTranscribe();
  }

  Future<void> _onMicLongPressCancel() async {
    if (_micStatus == _MicStatus.recording && !_isToggleMode) {
      await _cancelRecording();
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

    final isCompact = context.isCompact;

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
            '$_elapsedText 경과 · 참여 ${_session.participants.length}명 · 발언 ${_session.ideas.length}건',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        // 세션 코드 / QR 표시
        IconButton(
          icon: const Icon(Icons.qr_code),
          tooltip: '세션 코드',
          onPressed: () => _showQrSheet(),
        ),
        // 의견 모음 화면으로
        IconButton(
          icon: const Icon(Icons.bubble_chart_outlined),
          tooltip: '의견 모음',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClusterVoteScreen(
                sessionCode: _session.sessionCode,
                sessionStream: _sessionStream,
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

  void _showQrSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: sheetConstraints(),
      builder: (_) => _QrSheet(code: _session.sessionCode),
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
        if (_session.participants.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              itemCount: _session.participants.length,
              separatorBuilder: (context, i) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final p = _session.participants[i];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE0DDD6)),
                  ),
                  child: Text(
                    '${p.number}번 ${p.name}',
                    style: const TextStyle(fontSize: 12, color: kInk, fontWeight: FontWeight.w500),
                  ),
                );
              },
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: 100,
              maxHeight: (MediaQuery.sizeOf(context).height * 0.22).clamp(100, 160),
            ),
            child: _SttBox(
              transcript: _latestTranscript,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            color: kGreen,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
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
              child: SafeArea(
                top: false,
                left: false,
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 80, 0),
                        child: _SttBox(
                          transcript: _latestTranscript,
                          expand: true,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                      child: _StudentReactionRow(session: _session),
                    ),
                  ],
                ),
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
      onTap: _micStatus == _MicStatus.transcribing ? null : _onMicTap,
      onLongPressStart: _micStatus == _MicStatus.transcribing ? null : (_) => _onMicLongPressStart(),
      onLongPressEnd: _micStatus == _MicStatus.transcribing ? null : (_) => _onMicLongPressEnd(),
      onLongPressCancel: _micStatus == _MicStatus.transcribing ? null : _onMicLongPressCancel,
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

  /// true: 부모(Expanded)가 높이를 결정 — Medium 레이아웃
  /// false: 내용 기준 최소 높이 — Compact 레이아웃 (ConstrainedBox로 제한)
  final bool expand;

  const _SttBox({required this.transcript, this.expand = false});

  @override
  Widget build(BuildContext context) {
    const label = Text(
      '실시간 음성',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.black38,
      ),
    );

    final content = transcript == null || transcript!.isEmpty
        ? const Align(
            alignment: Alignment.topLeft,
            child: Text(
              '마이크 버튼을 길게 누르면\n발화가 여기에 표시됩니다.',
              style: TextStyle(fontSize: 14, color: Colors.black38),
            ),
          )
        : Text(
            '"$transcript"',
            style: const TextStyle(fontSize: 16, color: kInk, height: 1.55),
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: expand
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [label, const SizedBox(height: 10), Expanded(child: content)],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [label, const SizedBox(height: 10), content],
            ),
    );
  }
}

// ── 누적 요약 패널 ────────────────────────────────────────────────────────
class _SummaryPanel extends StatefulWidget {
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
  State<_SummaryPanel> createState() => _SummaryPanelState();
}

class _SummaryPanelState extends State<_SummaryPanel> {
  final _scrollCtrl = ScrollController();

  @override
  void didUpdateWidget(_SummaryPanel old) {
    super.didUpdateWidget(old);
    if (widget.groups.length != old.groups.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollCtrl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '누적 요약',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: widget.textColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 14),
          if (widget.groups.isEmpty)
            Text(
              '의견이 들어오면 자동으로 요약됩니다.',
              style: TextStyle(fontSize: 14, color: widget.emptyColor),
            )
          else
            ...widget.groups.asMap().entries.map(
              (e) => _SummaryItem(
                index: e.key + 1,
                title: widget.groupingEngine.makeGroupTitle(e.value),
                summary: e.value.summary,
                textColor: widget.textColor,
              ),
            ),
          if (widget.aiBriefingFlow != null && widget.groups.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              widget.aiBriefingFlow!,
              style: TextStyle(fontSize: 14, color: widget.textColor),
            ),
          ],
        ],
      ),
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

// ── 세션 코드 QR 바텀시트 ─────────────────────────────────────────────────
class _QrSheet extends StatelessWidget {
  final String code;
  const _QrSheet({required this.code});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '학생 참여 코드',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final size =
                    (constraints.maxWidth * 0.45).clamp(120.0, 200.0);
                return QrImageView(
                    data: code, size: size, version: QrVersions.auto);
              },
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('코드가 복사됐습니다')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: kGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '탭하면 코드가 복사됩니다',
              style: TextStyle(fontSize: 12, color: Colors.black38),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _QrFullScreen(code: code),
                    ),
                  );
                },
                icon: const Icon(Icons.fullscreen),
                label: const Text('전체 화면으로 보기 (학생 공유용)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 전체화면 QR (교실 공유용) ────────────────────────────────────────────
class _QrFullScreen extends StatelessWidget {
  final String code;
  const _QrFullScreen({required this.code});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        title: const Text('학생 참여 코드'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final qrSize =
              (constraints.maxWidth * 0.55).clamp(200.0, 380.0);
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                QrImageView(data: code, size: qrSize, version: QrVersions.auto),
                const SizedBox(height: 32),
                Text(
                  code,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 14,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'QR 코드를 스캔하거나 코드를 직접 입력하세요',
                  style: TextStyle(fontSize: 14, color: Colors.black45),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
