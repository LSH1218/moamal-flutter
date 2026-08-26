import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/idea.dart';
import '../../models/session_state.dart';
import '../../repositories/firebase_moamal_repository.dart';
import '../../services/auth_service.dart';
import '../../services/whisper_stt_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

class StudentSessionScreen extends StatefulWidget {
  final String sessionCode;
  final String? participantNumber;
  final String? participantName;

  const StudentSessionScreen({
    super.key,
    required this.sessionCode,
    this.participantNumber,
    this.participantName,
  });

  @override
  State<StudentSessionScreen> createState() => _StudentSessionScreenState();
}

class _StudentSessionScreenState extends State<StudentSessionScreen>
    with TickerProviderStateMixin {
  late FirebaseMoamalRepository _repo;
  late AuthService _auth;
  final _sttClient = WhisperSttClient();

  // build()에서 만들면 setState마다 Firestore 구독이 끊겼다 다시 붙는다.
  // initState에서 한 번만 만들어 재사용한다 (Mercury-3-Student-01).
  Stream<SessionState>? _sessionStream;

  // Vote state
  String? _pendingVoteId;
  String? _myVote;
  bool _isVoting = false;

  // Mic state
  _MicStatus _micStatus = _MicStatus.idle;
  bool _forceStopped = false;
  bool _isToggleMode = false;

  // Pending/undo
  String? _pendingText;
  String? _lastTranscript;
  int _undoSeconds = 5;
  Timer? _undoTimer;

  String _sessionTitle = '';

  // VAD
  StreamSubscription<double>? _amplitudeSub;
  DateTime? _lastSpeechTime;
  static const double _silenceThresholdDb = -40.0;
  static const int _silenceSec = 3;

  // Force control
  StreamSubscription<bool>? _forceStartSub;
  StreamSubscription<bool>? _forceStopSub;
  bool _forceStartBannerVisible = false;
  bool _forceStopBannerVisible = false;
  Timer? _forceStartBannerTimer;

  // Ripple animation
  late final AnimationController _rippleCtrl;
  late final Animation<double> _rippleScale;
  late final Animation<double> _rippleOpacity;

  @override
  void initState() {
    super.initState();
    _repo = context.read<FirebaseMoamalRepository>();
    _auth = context.read<AuthService>();
    _sessionStream = _repo.listenToSession(widget.sessionCode);

    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _rippleScale = Tween<double>(
      begin: 1.0,
      end: 1.9,
    ).animate(CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut));
    _rippleOpacity = Tween<double>(
      begin: 0.55,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut));

    _listenForceStart();
    _listenForceStop();
  }

  void _listenForceStart() {
    final uid = _auth.currentUid;
    if (uid == null) return;
    _forceStartSub = _repo.listenToForceStart(widget.sessionCode, uid).listen((
      on,
    ) {
      if (on && mounted) _handleForceStart(uid);
    });
  }

  Future<void> _handleForceStart(String uid) async {
    await _repo.clearForceStart(widget.sessionCode, uid);
    // 잠금 해제는 마이크 상태와 무관하게 항상 수행한다.
    // 상태 확인을 앞에 두면 학생이 발언을 마친 done 상태에서 early-return 되어
    // 교사가 [시작]을 눌러도 잠금이 풀리지 않는다 (Mercury-3-Student-03).
    if (!mounted) return;
    setState(() {
      _forceStopped = false;
      _forceStopBannerVisible = false;
      _forceStartBannerVisible = true;
    });
    _forceStartBannerTimer?.cancel();
    _forceStartBannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _forceStartBannerVisible = false);
    });
    HapticFeedback.mediumImpact();

    // 자동 녹음 시작은 _onTap과 동일 규칙 — idle 또는 done에서만.
    if (_micStatus != _MicStatus.idle && _micStatus != _MicStatus.done) return;
    if (_micStatus == _MicStatus.done) {
      setState(() {
        _micStatus = _MicStatus.idle;
        _lastTranscript = null;
      });
    }
    _isToggleMode = true;
    await _startRecording();
    if (_micStatus == _MicStatus.recording) _startVAD();
  }

  void _listenForceStop() {
    final uid = _auth.currentUid;
    if (uid == null) return;
    _forceStopSub = _repo.listenToForceStop(widget.sessionCode, uid).listen((
      on,
    ) {
      if (on && mounted) _handleForceStop(uid);
    });
  }

  Future<void> _handleForceStop(String uid) async {
    _stopVAD();
    if (_micStatus == _MicStatus.recording) {
      await _sttClient.cancel();
      _rippleCtrl.stop();
      _rippleCtrl.reset();
      if (mounted) setState(() => _micStatus = _MicStatus.idle);
    }
    if (mounted) {
      setState(() {
        _forceStopped = true;
        _forceStopBannerVisible = true;
      });
    }
    await _repo.clearForceStop(widget.sessionCode, uid);
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    _forceStartBannerTimer?.cancel();
    _rippleCtrl.dispose();
    _stopVAD();
    _forceStartSub?.cancel();
    _forceStopSub?.cancel();
    _repo.stopListening();
    _sttClient.dispose();
    super.dispose();
  }

  // ── Recording ─────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (_micStatus != _MicStatus.idle) return;
    try {
      await _sttClient.startRecording();
      if (mounted) {
        setState(() => _micStatus = _MicStatus.recording);
        _rippleCtrl.repeat();
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _stopAndTranscribe() async {
    if (_micStatus != _MicStatus.recording) return;
    _stopVAD();
    _rippleCtrl.stop();
    _rippleCtrl.reset();
    setState(() => _micStatus = _MicStatus.transcribing);
    try {
      final text = await _sttClient.stopAndTranscribe(
        buildWhisperPrompt(_sessionTitle),
      );
      if (mounted) {
        if (text.isNotEmpty) {
          setState(() {
            _micStatus = _MicStatus.pending;
            _pendingText = text;
            _undoSeconds = 5;
          });
          _startUndoTimer();
        } else {
          setState(() => _micStatus = _MicStatus.idle);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
        setState(() => _micStatus = _MicStatus.idle);
      }
    }
  }

  Future<void> _cancelRecording() async {
    if (_micStatus != _MicStatus.recording) return;
    _stopVAD();
    await _sttClient.cancel();
    _rippleCtrl.stop();
    _rippleCtrl.reset();
    if (mounted) setState(() => _micStatus = _MicStatus.idle);
  }

  // ── Undo / confirm ────────────────────────────────────────────────────────

  void _startUndoTimer() {
    _undoTimer?.cancel();
    _undoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = _undoSeconds - 1;
      setState(() => _undoSeconds = next);
      if (next <= 0) {
        timer.cancel();
        _confirmSubmit();
      }
    });
  }

  Future<void> _confirmSubmit() async {
    final text = _pendingText;
    if (text == null) return;
    setState(() {
      _micStatus = _MicStatus.done;
      _lastTranscript = text;
      _pendingText = null;
    });
    await _submitIdea(text);
  }

  void _undoSubmit() {
    _undoTimer?.cancel();
    _undoTimer = null;
    setState(() {
      _micStatus = _MicStatus.idle;
      _pendingText = null;
      _undoSeconds = 5;
    });
  }

  // ── VAD ───────────────────────────────────────────────────────────────────

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
    _lastSpeechTime = null;
  }

  // ── Gesture handlers ──────────────────────────────────────────────────────

  Future<void> _onTap() async {
    if (_forceStopped) return;
    if (_micStatus == _MicStatus.idle || _micStatus == _MicStatus.done) {
      if (_micStatus == _MicStatus.done) {
        setState(() {
          _micStatus = _MicStatus.idle;
          _lastTranscript = null;
        });
      }
      _isToggleMode = true;
      await _startRecording();
      if (_micStatus == _MicStatus.recording) _startVAD();
    } else if (_micStatus == _MicStatus.recording && _isToggleMode) {
      _stopVAD();
      await _stopAndTranscribe();
    }
  }

  Future<void> _onLongPressStart() async {
    if (_forceStopped) return;
    if (_micStatus != _MicStatus.idle) return;
    _isToggleMode = false;
    await _startRecording();
  }

  Future<void> _onLongPressEnd() async {
    if (_micStatus != _MicStatus.recording || _isToggleMode) return;
    await _stopAndTranscribe();
  }

  Future<void> _onLongPressCancel() async {
    if (_micStatus == _MicStatus.recording && !_isToggleMode) {
      await _cancelRecording();
    }
  }

  Future<void> _submitIdea(String text) async {
    final idea = Idea(
      id: const Uuid().v4(),
      speaker: '학생',
      text: text,
      source: 'stt',
    );
    await _repo.submitIdea(widget.sessionCode, idea);
  }

  Future<void> _castVote() async {
    final gid = _pendingVoteId;
    if (gid == null || _isVoting || _myVote != null) return;
    setState(() => _isVoting = true);
    try {
      final uid = _auth.currentUid!;
      await _repo.castVote(widget.sessionCode, uid, gid);
      if (mounted) {
        setState(() {
          _myVote = gid;
          _pendingVoteId = null;
        });
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SessionState>(
      stream: _sessionStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: kGround,
            body: Center(child: CircularProgressIndicator(color: kGreen)),
          );
        }
        final state = snapshot.data!;
        _sessionTitle = state.title;

        // Latest teacher note → question card
        Idea? teacherNote;
        for (final idea in state.ideas.reversed) {
          if (idea.speaker == '교사') {
            teacherNote = idea;
            break;
          }
        }

        final showVote =
            state.voteOpen && state.approvedGroups.isNotEmpty ||
            (!state.voteOpen &&
                _myVote != null &&
                state.approvedGroups.isNotEmpty);

        return Scaffold(
          backgroundColor: kGround,
          body: SafeArea(
            child: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) async {
                if (didPop) return;
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => const _ExitDialog(),
                );
                if ((ok ?? false) && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: context.isCompact
                  ? _compactLayout(state, teacherNote, showVote)
                  : _mediumLayout(state, teacherNote, showVote),
            ),
          ),
        );
      },
    );
  }

  Widget _compactLayout(SessionState state, Idea? teacherNote, bool showVote) {
    if (showVote) {
      return Column(
        children: [
          _header(state),
          Expanded(child: _voteView(state)),
        ],
      );
    }
    return Column(
      children: [
        _header(state),
        if (teacherNote != null) _questionCard(teacherNote.text),
        if (_forceStartBannerVisible) _forceStartBanner(),
        if (_forceStopBannerVisible) _forcedStopBanner(),
        Expanded(child: _speakContent()),
        _micArea(),
      ],
    );
  }

  Widget _mediumLayout(SessionState state, Idea? teacherNote, bool showVote) {
    if (showVote) {
      return Column(
        children: [
          _header(state),
          Expanded(child: _voteView(state)),
        ],
      );
    }
    final w = MediaQuery.sizeOf(context).width;
    return Column(
      children: [
        _header(state),
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: w * 0.5,
                child: Column(
                  children: [
                    if (teacherNote != null) _questionCard(teacherNote.text),
                    if (_forceStartBannerVisible) _forceStartBanner(),
                    if (_forceStopBannerVisible) _forcedStopBanner(),
                    Expanded(child: _speakContent()),
                  ],
                ),
              ),
              Container(width: 1, color: const Color(0xFFE0DDD6)),
              SizedBox(
                width: w * 0.5,
                child: SingleChildScrollView(child: _micArea()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _header(SessionState state) {
    final badge =
        widget.participantNumber != null && widget.participantName != null
        ? '${widget.participantNumber}번 ${widget.participantName}'
        : null;

    return Container(
      color: kGreen,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              state.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Question card ─────────────────────────────────────────────────────────

  Widget _questionCard(String text) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: kYellow),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '선생님이 물었어요',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: kInk.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        text,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                          color: kInk,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Force-start banner ────────────────────────────────────────────────────

  Widget _forceStartBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: kYellow,
              shape: BoxShape.circle,
            ),
            child: const Center(child: Icon(Icons.mic, size: 14, color: kInk)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '선생님이 발언을 시작했어요',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Force-stop banner ─────────────────────────────────────────────────────

  Widget _forcedStopBanner() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _forceStopBannerVisible = false),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: kRed,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: kYellow,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '!',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: kInk,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '선생님이 마이크를 잠시 껐어요.\n다시 켜질 때까지 기다려요',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.close,
              size: 18,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ],
        ),
      ),
    );
  }

  // ── Speak content (state-switched) ────────────────────────────────────────

  Widget _speakContent() {
    switch (_micStatus) {
      case _MicStatus.idle:
      case _MicStatus.recording:
      case _MicStatus.transcribing:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _micStatus == _MicStatus.transcribing
                      ? '음성을 텍스트로 바꾸는 중이에요'
                      : '아래 큰 버튼을 눌러 말해요',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kInk.withValues(alpha: 0.55),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_micStatus != _MicStatus.transcribing) ...[
                  const SizedBox(height: 6),
                  Text(
                    '한 번 눌러서 말하고 다시 누르기\n또는 누른 채로 말하고 손 떼기',
                    style: TextStyle(
                      fontSize: 13,
                      color: kInk.withValues(alpha: 0.42),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        );

      case _MicStatus.pending:
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
          child: Column(
            children: [
              // Result card
              _submittedCard(_pendingText ?? '', pending: true),
              const SizedBox(height: 10),
              // Undo bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                decoration: BoxDecoration(
                  color: kInk,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 38,
                      height: 38,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: _undoSeconds / 5,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
                            valueColor: const AlwaysStoppedAnimation(kYellow),
                            strokeWidth: 3,
                          ),
                          Text(
                            '$_undoSeconds',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: kYellow,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '잘못 들어갔나요?\n$_undoSeconds초 안에 되돌릴 수 있어요',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _undoSubmit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: kYellow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '되돌리기',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kInk,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case _MicStatus.done:
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
          child: Column(
            children: [
              _submittedCard(_lastTranscript ?? '', pending: false),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: kGround,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: kGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.check, size: 13, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '기록이 확정됐어요. 더 하고 싶은 말이 있으면 한 번 더 말해요.',
                        style: TextStyle(
                          fontSize: 13,
                          color: kInk,
                          height: 1.4,
                        ),
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

  Widget _submittedCard(String text, {required bool pending}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kYellow, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: kYellow,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.check, size: 13, color: kInk),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '선생님에게 보냈어요',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(fontSize: 18, height: 1.6, color: kInk),
          ),
        ],
      ),
    );
  }

  // ── Mic area ──────────────────────────────────────────────────────────────

  Widget _micArea() {
    final isBlocked =
        _forceStopped ||
        _micStatus == _MicStatus.transcribing ||
        _micStatus == _MicStatus.pending;

    final statusTitle = _forceStopped
        ? '마이크 꺼짐'
        : switch (_micStatus) {
            _MicStatus.idle => '말하기',
            _MicStatus.recording => _isToggleMode ? '녹음 중' : '녹음 중',
            _MicStatus.transcribing => '변환 중',
            _MicStatus.pending => '전송됨',
            _MicStatus.done => '다시 말하기',
          };

    final hintText = _forceStopped
        ? '선생님이 마이크를 잠시 껐어요'
        : switch (_micStatus) {
            _MicStatus.idle => '탭하거나 길게 눌러 말해요',
            _MicStatus.recording =>
              _isToggleMode ? '다시 탭하면 전송합니다' : '손을 떼면 전송합니다',
            _MicStatus.transcribing => '음성을 텍스트로 바꾸는 중입니다',
            _MicStatus.pending => '아무것도 안 하면 확정돼요',
            _MicStatus.done => '탭하거나 길게 눌러 다시 말해요',
          };

    final screenH = MediaQuery.sizeOf(context).height;
    // Compact vertical space (landscape or very small phone)
    final tight = screenH < 520;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, tight ? 4 : 8, 16, tight ? 12 : 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!tight)
            Text(
              statusTitle,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: kInk,
              ),
            ),
          if (!tight) const SizedBox(height: 12),
          _micButton(isBlocked, tight: tight),
          const SizedBox(height: 8),
          Text(
            tight ? statusTitle : hintText,
            style: TextStyle(fontSize: 12, color: kInk.withValues(alpha: 0.5)),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _micButton(bool isBlocked, {bool tight = false}) {
    final size = tight ? 96.0 : 148.0;

    final bg = _forceStopped
        ? kDisabled
        : switch (_micStatus) {
            _MicStatus.recording => kRed,
            _MicStatus.transcribing => kBlue,
            _MicStatus.pending => kDisabled,
            _ => kYellow,
          };
    final fg = _forceStopped || _micStatus == _MicStatus.pending
        ? Colors.white
        : switch (_micStatus) {
            _MicStatus.recording || _MicStatus.transcribing => Colors.white,
            _ => kInk,
          };
    final icon = _forceStopped
        ? Icons.mic_off
        : switch (_micStatus) {
            _MicStatus.recording => Icons.mic,
            _ => Icons.mic_none,
          };

    return GestureDetector(
      onTap: isBlocked ? null : _onTap,
      onLongPressStart: isBlocked ? null : (_) => _onLongPressStart(),
      onLongPressEnd: isBlocked ? null : (_) => _onLongPressEnd(),
      onLongPressCancel: isBlocked ? null : _onLongPressCancel,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_micStatus == _MicStatus.recording)
              AnimatedBuilder(
                animation: _rippleCtrl,
                builder: (_, _) => Container(
                  width: size * _rippleScale.value,
                  height: size * _rippleScale.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kRed.withValues(alpha: _rippleOpacity.value),
                  ),
                ),
              ),
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: _micStatus == _MicStatus.transcribing
                  ? Center(
                      child: SizedBox(
                        width: size * 0.3,
                        height: size * 0.3,
                        child: CircularProgressIndicator(
                          color: fg,
                          strokeWidth: 3,
                        ),
                      ),
                    )
                  : Icon(icon, color: fg, size: size * 0.34),
            ),
          ],
        ),
      ),
    );
  }

  // ── Vote view ─────────────────────────────────────────────────────────────

  Widget _voteView(SessionState state) {
    final groups = state.approvedGroups;
    final counts = <String, int>{};
    for (final gid in state.votes.values) {
      counts[gid] = (counts[gid] ?? 0) + 1;
    }
    final maxVotes = counts.values.isEmpty
        ? 1
        : counts.values.reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        // Status banner
        Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: state.voteOpen ? kYellow : kInk,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: state.voteOpen ? kInk : kYellow,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    state.voteOpen ? Icons.check : Icons.info_outline,
                    size: 14,
                    color: state.voteOpen ? Colors.white : kInk,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.voteOpen ? '투표가 열렸어요' : '투표가 닫혔어요',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: state.voteOpen ? kInk : Colors.white,
                      ),
                    ),
                    Text(
                      state.voteOpen ? '가장 좋다고 생각하는 의견 하나를 골라요' : '결과를 함께 볼게요',
                      style: TextStyle(
                        fontSize: 12,
                        color: state.voteOpen
                            ? kInk.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Candidate cards
        Expanded(
          child: groups.isEmpty
              ? const Center(
                  child: Text(
                    '교사가 투표 그룹을 승인하면\n여기에 표시됩니다.',
                    style: TextStyle(color: Colors.black38),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final group = groups[i];
                    final isSelected =
                        _pendingVoteId == group.groupId ||
                        _myVote == group.groupId;
                    final voteCount = counts[group.groupId] ?? 0;
                    final ratio = maxVotes > 0 ? voteCount / maxVotes : 0.0;
                    final canTap =
                        state.voteOpen && _myVote == null && !_isVoting;

                    return GestureDetector(
                      onTap: canTap
                          ? () => setState(() => _pendingVoteId = group.groupId)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 17),
                        decoration: BoxDecoration(
                          color: isSelected ? kGreen : kCardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected
                                ? kGreen
                                : const Color(0xFFE8E4DC),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? kYellow
                                        : Colors.grey.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? kYellow
                                          : Colors.grey.withValues(alpha: 0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Center(
                                          child: Icon(
                                            Icons.check,
                                            size: 13,
                                            color: kInk,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    group.title,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? Colors.white : kInk,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (group.ideaIds.length > 1) ...[
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(left: 34),
                                child: Text(
                                  '${group.ideaIds.length}개 의견',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.7)
                                        : kInk.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ],
                            if (!state.voteOpen) ...[
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 10,
                                  backgroundColor: isSelected
                                      ? Colors.white.withValues(alpha: 0.18)
                                      : kInk.withValues(alpha: 0.1),
                                  valueColor: AlwaysStoppedAnimation(
                                    isSelected ? kYellow : kGreen,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        // Bottom bar
        if (state.voteOpen)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
            decoration: BoxDecoration(
              color: kGround,
              border: Border(top: BorderSide(color: const Color(0xFFE8E4DC))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_myVote == null && _pendingVoteId != null) ...[
                  Text(
                    '내가 고른 의견: ${groups.firstWhere((g) => g.groupId == _pendingVoteId, orElse: () => groups.first).title}',
                    style: const TextStyle(fontSize: 12.5, color: kInk),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                ],
                if (_myVote != null) ...[
                  const Text(
                    '투표가 완료됐어요',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: _pendingVoteId != null && _myVote == null
                        ? _castVote
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: _pendingVoteId != null && _myVote == null
                            ? kGreen
                            : kInk.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: _isVoting
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              _myVote != null ? '투표 완료' : '투표하기',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17.5,
                                fontWeight: FontWeight.w700,
                                color: _pendingVoteId != null && _myVote == null
                                    ? Colors.white
                                    : kInk.withValues(alpha: 0.4),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '투표는 한 번만 할 수 있어요',
                  style: TextStyle(fontSize: 12, color: Colors.black38),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Exit dialog ───────────────────────────────────────────────────────────────

class _ExitDialog extends StatelessWidget {
  const _ExitDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kCardBg,
      insetPadding: EdgeInsets.symmetric(
        horizontal: dialogInsetH(context),
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: kYellow,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: kInk,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '수업에서 나갈까요?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: kInk,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '다시 코드를 넣어야 들어올 수 있어요',
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.black54,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // 320dp에서는 다이얼로그 내부 폭이 196dp밖에 안 되고
            // [나가기]가 고정으로 81dp를 먹어 [계속 참여하기] 글자가 깨졌다.
            // 럜딩 세션 선택 다이얼로그(Mercury-Layout-01)와 같은 처리 — 좀으면 세로 배치.
            if (context.isNarrow)
              Column(
                children: [
                  _ExitAction(
                    label: '계속 참여하기',
                    filled: true,
                    onTap: () => Navigator.pop(context, false),
                  ),
                  const SizedBox(height: 8),
                  _ExitAction(
                    label: '나가기',
                    filled: false,
                    onTap: () => Navigator.pop(context, true),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _ExitAction(
                      label: '계속 참여하기',
                      filled: true,
                      onTap: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _ExitAction(
                    label: '나가기',
                    filled: false,
                    onTap: () => Navigator.pop(context, true),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

enum _MicStatus { idle, recording, transcribing, pending, done }

/// 나가기 다이얼로그 버튼. 가로·세로 배치에서 같은 모양을 쓰기 위해 분리했다.
class _ExitAction extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ExitAction({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          color: filled ? kGreen : null,
          border: filled ? null : Border.all(color: kRed, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: filled ? Colors.white : kRed,
          ),
        ),
      ),
    );
  }
}
