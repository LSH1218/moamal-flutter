import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/responsive.dart';
import '../../models/group.dart';
import '../../models/meeting_report.dart';
import '../../models/session_state.dart';
import '../../repositories/firebase_moamal_repository.dart';
import '../../services/auth_service.dart';
import '../../services/ai_api_client.dart';
import '../../services/deep_link_service.dart';
import '../../services/gemini_grouping_engine.dart';
import '../../services/whisper_stt_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/draft_sheet.dart';
import '../../widgets/group_card.dart';
import '../../widgets/stat_row.dart';
import '../../widgets/teacher_dock.dart';
import 'beam_projector_screen.dart';
import 'mic_control_screen.dart';
import 'organize_screen.dart';
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
  String? _aiBriefingAction;
  String? _aiBriefingQuestion;
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
  bool _isDraftOpen = false;
  DateTime? _recordingStartTime;
  final _teacherNotes = <String>[];

  // VAD (토글 모드 침묵 자동 종료)
  StreamSubscription<double>? _amplitudeSub;
  DateTime? _lastSpeechTime;
  static const double _silenceThresholdDb = -34.0;
  static const int _silenceSec = 3;

  // 탭 상태
  int _tabIndex = 0;
  bool _hasBriefingUpdate = false;

  @override
  void initState() {
    super.initState();
    _groupingEngine = GeminiGroupingEngine(onUpdate: _onGroupingUpdated);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSession());
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _stopVAD();
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_teacher_session', sessionCode);

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
      setState(() {
        _aiBriefingFlow = r.flow;
        _aiBriefingAction = r.action;
        _aiBriefingQuestion = r.question;
        // 브리핑 탭이 선택되지 않은 경우에만 빨간 점 표시
        if (_tabIndex != 1) _hasBriefingUpdate = true;
      });
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
        _aiBriefingAction = null;
        _aiBriefingQuestion = null;
        _meetingReport = null;
        _elapsedText = '00:00';
        _latestTranscript = null;
        _hasBriefingUpdate = false;
      });
      _teacherNotes.clear();
    }
  }

  // ── 마이크 ──────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (_micStatus != _MicStatus.idle) return;
    try {
      await _sttClient.startRecording();
      _recordingStartTime = DateTime.now();
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
    final wasPtt = !_isToggleMode;
    setState(() => _micStatus = _MicStatus.transcribing);
    try {
      final text =
          await _sttClient.stopAndTranscribe(buildWhisperPrompt(_session.title));
      if (!mounted || text.isEmpty) return;
      setState(() => _latestTranscript = text);

      if (wasPtt) {
        // PTT → 초안 확인 시트
        await _showTeacherDraftSheet(text);
      } else {
        // 탭 → 즉시 기록
        await _recordNote(text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('발문/지시 기록됨'),
              duration: Duration(seconds: 2),
            ),
          );
        }
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

  Future<void> _recordNote(String text) async {
    _teacherNotes.add(text);
    _groupingEngine.recentTeacherNotes = _teacherNotes.length <= 2
        ? List.of(_teacherNotes)
        : _teacherNotes.sublist(_teacherNotes.length - 2);
    await _repo.addTeacherNote(
      sessionCode: _session.sessionCode,
      text: text,
      uid: _auth.currentUid!,
    );
  }

  Future<void> _showTeacherDraftSheet(String text) async {
    setState(() => _isDraftOpen = true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: sheetConstraints(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => DraftSheet(
        initialText: text,
        recordDuration: _recordingStartTime != null
            ? DateTime.now().difference(_recordingStartTime!)
            : Duration.zero,
        onSubmit: (finalText) async {
          Navigator.pop(ctx);
          await _recordNote(finalText);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('발문 기록됨'), duration: Duration(seconds: 2)),
            );
          }
        },
        onReRecord: () {
          Navigator.pop(ctx);
          _startRecording();
        },
      ),
    );
    if (mounted) setState(() => _isDraftOpen = false);
  }

  Future<void> _cancelRecording() async {
    if (_micStatus == _MicStatus.recording) {
      _stopVAD();
      await _sttClient.cancel();
      if (mounted) setState(() => _micStatus = _MicStatus.idle);
    }
  }

  void _startVAD() {
    _lastSpeechTime = DateTime.now();
    _amplitudeSub = _sttClient.amplitudeStream.listen((db) {
      if (!mounted) return;
      if (db > _silenceThresholdDb) {
        _lastSpeechTime = DateTime.now();
      } else {
        final silence = DateTime.now().difference(_lastSpeechTime!);
        if (silence.inSeconds >= _silenceSec) {
          _stopVAD();
          _stopAndTranscribe();
        }
      }
    });
  }

  void _stopVAD() {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
  }

  Future<void> _onMicTap() async {
    if (_micStatus == _MicStatus.idle) {
      _isToggleMode = true;
      await _startRecording();
      if (_micStatus == _MicStatus.recording) _startVAD();
    } else if (_micStatus == _MicStatus.recording && _isToggleMode) {
      _stopVAD();
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

  // ── 네비게이션 ───────────────────────────────────────────────────────────

  void _showQrSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: sheetConstraints(),
      builder: (sheetCtx) => _QrSheet(
        code: _session.sessionCode,
        onOpenProjector: () {
          Navigator.pop(sheetCtx);
          _goToProjector();
        },
      ),
    );
  }

  void _goToProjector() {
    if (_sessionStream == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BeamProjectorScreen(
          sessionCode: _session.sessionCode,
          sessionStream: _sessionStream!,
          initialSession: _session,
        ),
      ),
    );
  }

  void _goToSummary() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizeScreen(
          sessionCode: _session.sessionCode,
          sessionStream: _sessionStream,
          initialSession: _session,
          groups: _groups,
          repo: _repo,
          groupingEngine: _groupingEngine,
        ),
      ),
    );
  }

  void _goToStudents() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MicControlScreen(
          sessionCode: _session.sessionCode,
          session: _session,
          repo: _repo,
        ),
      ),
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

  Future<bool> _onWillPop() async {
    final ideaCount = _session.ideas.length;
    final leave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: kCardBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
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
                      color: kYellow,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Center(
                      child: Text('!',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: kInk)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '나가면 수업이 종료됩니다',
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
                '지금까지 모은 의견 $ideaCount건과 AI 요약은 수업기록에 저장됩니다. 학생 화면에는 종료 안내가 표시됩니다.',
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
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: kGreen,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          '수업 계속하기',
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
                        border: Border.all(
                            color: const Color(0xFFD32F2F), width: 1.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        '종료',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD32F2F),
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
    return leave ?? false;
  }

  // ── 빌드 ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: kGround,
        body: Center(child: CircularProgressIndicator(color: kGreen)),
      );
    }

    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _onWillPop();
        if (leave && mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('active_teacher_session');
          if (mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: kGround,
        body: isTablet ? _buildTabletBody() : _buildPhoneBody(),
      ),
    );
  }

  // ── 폰 세로 레이아웃 ───────────────────────────────────────────────────

  Widget _buildPhoneBody() {
    return Column(
      children: [
        _buildHeader(),
        _buildTabBar(),
        Expanded(
          child: _tabIndex == 0 ? _buildSummaryTab() : _buildBriefingTab(),
        ),
        _buildSttBox(),
        TeacherDock(
          micButton: _buildMicWidget(),
          unclassifiedCount: (_session.ideas.length -
              _groups.fold(0, (sum, g) => sum + g.ideas.length))
              .clamp(0, 9999).toInt(),
          micHint: _micHint,
          onShare: _showQrSheet,
          onSummary: _goToSummary,
          onStudents: _goToStudents,
          onEnd: _goToReport,
        ),
      ],
    );
  }

  // ── 태블릿 레이아웃 ────────────────────────────────────────────────────

  Widget _buildTabletBody() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 좌: 브리핑 + 통계 + 요약
              Expanded(
                flex: 52,
                child: Container(
                  color: kGreen,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: StatRow(
                            participantCount: _session.participants.length,
                            ideaCount: _session.ideas.length,
                            groupCount: _groups.length,
                          ),
                        ),
                        Expanded(child: _buildTabletSummaryList()),
                      ],
                    ),
                  ),
                ),
              ),
              // 우: STT + 독
              Expanded(
                flex: 48,
                child: SafeArea(
                  top: false,
                  left: false,
                  child: Column(
                    children: [
                      Expanded(child: _buildSttBox(expanded: true)),
                      TeacherDock(
                        micButton: _buildMicWidget(),
                        unclassifiedCount: 0,
                        micHint: _micHint,
                        onShare: _showQrSheet,
                        onSummary: _goToSummary,
                        onStudents: _goToStudents,
                        onEnd: _goToReport,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 헤더 ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: kGreen,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _session.title.isEmpty ? '수업 제목 없음' : _session.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _elapsedText,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kYellow,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 10),
              const _LiveBadge(),
            ],
          ),
        ),
      ),
    );
  }

  // ── 탭 바 ─────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: kGreen,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(
        children: [
          _Tab(
            label: '요약 ${_groups.length}',
            selected: _tabIndex == 0,
            onTap: () => setState(() => _tabIndex = 0),
          ),
          const SizedBox(width: 8),
          _Tab(
            label: '브리핑',
            selected: _tabIndex == 1,
            hasDot: _hasBriefingUpdate,
            onTap: () => setState(() {
              _tabIndex = 1;
              _hasBriefingUpdate = false;
            }),
          ),
        ],
      ),
    );
  }

  // ── 요약 탭 ───────────────────────────────────────────────────────────

  Widget _buildSummaryTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      children: [
        StatRow(
          participantCount: _session.participants.length,
          ideaCount: _session.ideas.length,
          groupCount: _groups.length,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Text(
              'AI 누적 요약',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kInk),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _goToSummary,
              child: const Text(
                '정리하기 ›',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: kGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '의견이 들어오면 자동으로 요약됩니다.',
              style: TextStyle(fontSize: 14, color: kInk.withValues(alpha: 0.4)),
            ),
          )
        else
          ..._groups.map((g) => GroupCard(group: g, ideaCount: g.ideas.length)),
      ],
    );
  }

  Widget _buildTabletSummaryList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
      children: [
        if (_groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '의견이 들어오면 자동으로 요약됩니다.',
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5)),
            ),
          )
        else
          ..._groups.map((g) => GroupCard(group: g, ideaCount: g.ideas.length)),
      ],
    );
  }

  // ── 브리핑 탭 ─────────────────────────────────────────────────────────

  Widget _buildBriefingTab() {
    if (_groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '의견이 들어오면 AI 브리핑이 여기에 표시됩니다.',
            style: TextStyle(fontSize: 14, color: kInk.withValues(alpha: 0.4)),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final action = _aiBriefingAction ?? _defaultNextAction();
    final question = _aiBriefingQuestion ?? _defaultQuestion();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      children: [
        // 지금 흐름
        if (_aiBriefingFlow != null) ...[
          _BriefingCard(
            label: '지금 흐름',
            body: _aiBriefingFlow!,
          ),
          const SizedBox(height: 10),
        ],
        // 교사가 할 일
        _BriefingCard(
          label: '교사가 할 일',
          body: action,
          isAction: true,
          onSummary: _goToSummary,
          unclassifiedCount: (_session.ideas.length -
              _groups.fold(0, (sum, g) => sum + g.ideas.length))
              .clamp(0, 9999).toInt(),
        ),
        const SizedBox(height: 10),
        // 추천 질문
        if (question.isNotEmpty) ...[
          const Text(
            '추천 질문',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kInk),
          ),
          const SizedBox(height: 8),
          _QuestionCard(question: question),
        ],
      ],
    );
  }

  String _defaultNextAction() {
    if (_session.ideas.length < 3) return '의견을 조금 더 받은 뒤 묶음을 확인하세요.';
    if (_groups.length == 1) return '비슷한 의견이 모였습니다. 실행 방법이나 우려점을 한 번 더 물어보세요.';
    if (!_session.voteOpen && _session.votes.isEmpty) {
      return '묶음 제목과 대표 의견을 확인한 뒤 투표를 시작할 수 있습니다.';
    }
    if (_session.voteOpen) return '투표가 진행 중입니다. 공용 화면에서 결과 흐름을 함께 보세요.';
    return '투표 결과를 바탕으로 결정 사항과 남은 쟁점을 정리하세요.';
  }

  String _defaultQuestion() {
    if (_groups.isEmpty) return '';
    if (_groups.length == 1) {
      return '이 의견을 실제로 실행한다면 가장 먼저 바꿔야 할 점은 무엇일까요?';
    }
    return '"${_groups[0].displayTitle}"와 "${_groups[1].displayTitle}" 중 지금 상황에서 더 중요한 기준은 무엇일까요?';
  }

  // ── STT 박스 ─────────────────────────────────────────────────────────

  Widget _buildSttBox({bool expanded = false}) {
    final isRecording = _micStatus == _MicStatus.recording;

    final inner = Padding(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '실시간 음성 · 교사 발문',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kInk.withValues(alpha: 0.45),
                ),
              ),
              if (isRecording) ...[
                const Spacer(),
                _WaveformBars(),
              ],
            ],
          ),
          const SizedBox(height: 8),
          expanded
              ? Expanded(
                  child: SingleChildScrollView(
                    child: _sttContent(),
                  ),
                )
              : _sttContent(),
        ],
      ),
    );

    final box = Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      decoration: BoxDecoration(
        color: kCardBg,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: expanded
          ? inner
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 130),
              child: SingleChildScrollView(child: inner),
            ),
    );

    return expanded
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: box,
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
            child: box,
          );
  }

  Widget _sttContent() {
    if (_latestTranscript == null || _latestTranscript!.isEmpty) {
      return Text(
        _micStatus == _MicStatus.transcribing
            ? '음성을 텍스트로 바꾸는 중입니다...'
            : '마이크를 탭하거나 길게 눌러 발문을 기록하세요.',
        style: TextStyle(
          fontSize: 15,
          color: kInk.withValues(alpha: 0.4),
          height: 1.55,
        ),
      );
    }
    return Text(
      '"$_latestTranscript"',
      style: const TextStyle(fontSize: 15, color: kInk, height: 1.55),
    );
  }

  // ── 마이크 위젯 (독에 넘길 시각 전용) ────────────────────────────────

  Widget _buildMicWidget() {
    final bool disabled = _micStatus == _MicStatus.transcribing || _isDraftOpen;
    final bool isRecording = _micStatus == _MicStatus.recording;

    final Color bg;
    final Widget icon;

    if (_isDraftOpen) {
      bg = kYellow;
      icon = const Icon(Icons.check, color: kInk, size: 28);
    } else {
      bg = switch (_micStatus) {
        _MicStatus.idle => kYellow,
        _MicStatus.recording => kRed,
        _MicStatus.transcribing => kBlue,
      };
      icon = _micStatus == _MicStatus.transcribing
          ? const Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              ),
            )
          : Icon(
              isRecording ? Icons.mic : Icons.mic_none,
              color: isRecording ? Colors.white : kInk,
              size: 28,
            );
    }

    final micVisual = Stack(
      alignment: Alignment.center,
      children: [
        if (isRecording) const _PulsingRing(),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: kGreen, width: 4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4D20231F),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: icon,
        ),
      ],
    );

    return GestureDetector(
      onTap: disabled ? null : _onMicTap,
      onLongPressStart: disabled ? null : (_) => _onMicLongPressStart(),
      onLongPressEnd: disabled ? null : (_) => _onMicLongPressEnd(),
      child: micVisual,
    );
  }

  String get _micHint {
    return switch (_micStatus) {
      _MicStatus.idle => '탭 · 길게 눌러 발문 녹음',
      _MicStatus.recording =>
        _isToggleMode ? '다시 탭하면 전사합니다' : '손을 떼면 전사합니다',
      _MicStatus.transcribing => '음성을 텍스트로 변환 중...',
    };
  }
}

// ── LIVE 배지 ─────────────────────────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: kRed,
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

// ── 탭 버튼 ───────────────────────────────────────────────────────────────
class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final bool hasDot;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.selected,
    this.hasDot = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? kCardBg : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: selected ? kInk : Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ),
          if (hasDot)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: kRed,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 브리핑 카드 ───────────────────────────────────────────────────────────
class _BriefingCard extends StatelessWidget {
  final String label;
  final String body;
  final bool isAction;
  final VoidCallback? onSummary;
  final int unclassifiedCount;

  const _BriefingCard({
    required this.label,
    required this.body,
    this.isAction = false,
    this.onSummary,
    this.unclassifiedCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAction ? kYellow : kCardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isAction
                  ? kInk.withValues(alpha: 0.55)
                  : kInk.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isAction ? FontWeight.w700 : FontWeight.w400,
              color: kInk,
              height: 1.6,
            ),
          ),
          if (isAction && onSummary != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                GestureDetector(
                  onTap: onSummary,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: kInk,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '정리 열기 →',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (unclassifiedCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: kInk.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '미분류 ${unclassifiedCount}건',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kInk.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final String question;
  const _QuestionCard({required this.question});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: kCardBg,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              question,
              style: const TextStyle(fontSize: 14.5, height: 1.55, color: kInk),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: kGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '읽기',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── STT 파형 애니메이션 ───────────────────────────────────────────────────
class _WaveformBars extends StatefulWidget {
  const _WaveformBars();

  @override
  State<_WaveformBars> createState() => _WaveformBarsState();
}

class _WaveformBarsState extends State<_WaveformBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final delay = i * 0.15;
        return Padding(
          padding: const EdgeInsets.only(left: 2),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = (_ctrl.value + delay) % 1.0;
              final h = 4.0 + 10.0 * (t < 0.5 ? t * 2 : (1 - t) * 2);
              return Container(
                width: 3,
                height: h,
                decoration: BoxDecoration(
                  color: kRed,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}

// ── QR 시트 ────────────────────────────────────────────────────────────────
class _QrSheet extends StatelessWidget {
  final String code;
  final VoidCallback? onOpenProjector;
  const _QrSheet({required this.code, this.onOpenProjector});

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
            LayoutBuilder(builder: (context, constraints) {
              final size = (constraints.maxWidth * 0.45).clamp(120.0, 200.0);
              return QrImageView(
                  data: DeepLinkService.buildJoinUri(code),
                  size: size,
                  version: QrVersions.auto);
            }),
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
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenProjector,
                icon: const Icon(Icons.cast),
                label: const Text('빔프로젝터 화면 열기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      body: LayoutBuilder(builder: (context, constraints) {
        final qrSize = (constraints.maxWidth * 0.55).clamp(200.0, 380.0);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              QrImageView(
                  data: DeepLinkService.buildJoinUri(code),
                  size: qrSize,
                  version: QrVersions.auto),
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
                style: TextStyle(fontSize: 14, color: Colors.black38),
              ),
            ],
          ),
        );
      }),
    );
  }
}

enum _MicStatus { idle, recording, transcribing }

// ── 마이크 녹음 중 펄스 링 ────────────────────────────────────────────────
class _PulsingRing extends StatefulWidget {
  const _PulsingRing();

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _scale = Tween(begin: 1.0, end: 1.55).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _fade = Tween(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: kRed.withValues(alpha: _fade.value),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
