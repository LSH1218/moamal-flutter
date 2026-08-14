import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/idea.dart';
import '../../models/session_state.dart';
import '../../repositories/firebase_moamal_repository.dart';
import '../../services/auth_service.dart';
import '../../services/whisper_stt_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/draft_sheet.dart';

class StudentSessionScreen extends StatefulWidget {
  final String sessionCode;

  const StudentSessionScreen({super.key, required this.sessionCode});

  @override
  State<StudentSessionScreen> createState() => _StudentSessionScreenState();
}

class _StudentSessionScreenState extends State<StudentSessionScreen> {
  late FirebaseMoamalRepository _repo;
  late AuthService _auth;
  final _sttClient = WhisperSttClient();
  String? _myVote;
  _MicStatus _micStatus = _MicStatus.idle;
  bool _isToggleMode = false;
  String? _lastTranscript;
  String _sessionTitle = '';

  // VAD
  StreamSubscription<double>? _amplitudeSub;
  DateTime? _lastSpeechTime;

  // Teacher force control
  StreamSubscription<bool>? _forceStartSub;
  StreamSubscription<bool>? _forceStopSub;
  // dBFS 기준: -40 이하를 침묵으로 판단. 교실 소음 환경에 따라 조정 필요.
  static const double _silenceThresholdDb = -40.0;
  static const int _silenceSec = 3;

  @override
  void initState() {
    super.initState();
    _repo = context.read<FirebaseMoamalRepository>();
    _auth = context.read<AuthService>();
    _listenForceStart();
    _listenForceStop();
  }

  void _listenForceStart() {
    final uid = _auth.currentUid;
    if (uid == null) return;
    _forceStartSub = _repo
        .listenToForceStart(widget.sessionCode, uid)
        .listen((forceStart) {
      if (forceStart && mounted) _handleForceStart(uid);
    });
  }

  Future<void> _handleForceStart(String uid) async {
    await _repo.clearForceStart(widget.sessionCode, uid);
    if (_micStatus != _MicStatus.idle) return;
    _isToggleMode = true;
    await _startRecording();
    if (_micStatus == _MicStatus.recording) _startVAD();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선생님이 녹음을 시작했어요.')),
      );
    }
  }

  void _listenForceStop() {
    final uid = _auth.currentUid;
    if (uid == null) return;
    _forceStopSub = _repo
        .listenToForceStop(widget.sessionCode, uid)
        .listen((forceStop) {
      if (forceStop && mounted) _handleForceStop(uid);
    });
  }

  Future<void> _handleForceStop(String uid) async {
    _stopVAD();
    if (_micStatus == _MicStatus.recording) {
      await _sttClient.cancel();
      if (mounted) setState(() => _micStatus = _MicStatus.idle);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선생님이 녹음을 마쳤어요.')),
      );
    }
    await _repo.clearForceStop(widget.sessionCode, uid);
  }

  @override
  void dispose() {
    _stopVAD();
    _forceStartSub?.cancel();
    _forceStopSub?.cancel();
    _repo.stopListening();
    _sttClient.dispose();
    super.dispose();
  }

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
      final text = await _sttClient.stopAndTranscribe(buildWhisperPrompt(_sessionTitle));
      if (mounted) {
        setState(() => _micStatus = _MicStatus.idle);
        if (text.isNotEmpty) await _showDraftSheet(text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
        setState(() => _micStatus = _MicStatus.idle);
      }
    }
  }

  Future<void> _showDraftSheet(String sttText) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: sheetConstraints(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraftSheet(
        initialText: sttText,
        onSubmit: (text) {
          Navigator.pop(ctx);
          setState(() => _lastTranscript = text);
          _submitIdea(text);
        },
        onReRecord: () => Navigator.pop(ctx),
      ),
    );
  }

  Future<void> _cancelRecording() async {
    if (_micStatus == _MicStatus.recording) {
      await _sttClient.cancel();
      if (mounted) {
        setState(() => _micStatus = _MicStatus.idle);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('너무 짧게 눌렀습니다.')),
        );
      }
    }
  }

  // ── VAD ───────────────────────────────────────────────────────────────

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

  // ── 제스처 핸들러 ──────────────────────────────────────────────────────

  /// 탭: idle이면 토글 녹음 시작 + VAD 구독, 토글 녹음 중이면 VAD 해제 후 종료
  Future<void> _onTap() async {
    if (_micStatus == _MicStatus.idle) {
      _isToggleMode = true;
      await _startRecording();
      if (_micStatus == _MicStatus.recording) _startVAD();
    } else if (_micStatus == _MicStatus.recording && _isToggleMode) {
      _stopVAD();
      await _stopAndTranscribe();
    }
  }

  /// 길게 누름 시작: idle일 때만 PTT 녹음 시작
  Future<void> _onLongPressStart() async {
    if (_micStatus != _MicStatus.idle) return;
    _isToggleMode = false;
    await _startRecording();
  }

  /// 길게 누름 종료: PTT 모드일 때만 종료
  Future<void> _onLongPressEnd() async {
    if (_micStatus != _MicStatus.recording || _isToggleMode) return;
    await _stopAndTranscribe();
  }

  /// 길게 누름 취소: PTT 모드일 때만 취소
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('의견이 전송되었습니다.')),
      );
    }
  }

  Future<void> _castVote(String groupId) async {
    final uid = _auth.currentUid!;
    await _repo.castVote(widget.sessionCode, uid, groupId);
    setState(() => _myVote = groupId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SessionState>(
      stream: _repo.listenToSession(widget.sessionCode),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: kGround,
            body: Center(child: CircularProgressIndicator(color: kGreen)),
          );
        }
        final state = snapshot.data!;
        _sessionTitle = state.title;
        final isCompact = context.isCompact;

        return Scaffold(
          backgroundColor: kGround,
          appBar: _buildAppBar(state, isCompact),
          body: isCompact
              ? _CompactBody(
                  state: state,
                  myVote: _myVote,
                  micStatus: _micStatus,
                  isToggleMode: _isToggleMode,
                  lastTranscript: _lastTranscript,
                  onMicTap: _onTap,
                  onMicLongPressStart: _onLongPressStart,
                  onMicLongPressEnd: _onLongPressEnd,
                  onMicLongPressCancel: _onLongPressCancel,
                  onVote: _castVote,
                )
              : _MediumBody(
                  state: state,
                  myVote: _myVote,
                  micStatus: _micStatus,
                  isToggleMode: _isToggleMode,
                  lastTranscript: _lastTranscript,
                  onMicTap: _onTap,
                  onMicLongPressStart: _onLongPressStart,
                  onMicLongPressEnd: _onLongPressEnd,
                  onMicLongPressCancel: _onLongPressCancel,
                  onVote: _castVote,
                ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(SessionState state, bool isCompact) {
    return AppBar(
      backgroundColor: kGreen,
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.title,
            style:
                const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            _micStatus == _MicStatus.recording
                ? '녹음 중'
                : _micStatus == _MicStatus.transcribing
                    ? '변환 중...'
                    : '발표 대기 중',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
      actions: isCompact
          ? null
          : [
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.circle, size: 8, color: Colors.white),
                    SizedBox(width: 5),
                    Text('LIVE',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
              ),
            ],
    );
  }
}

// ── Compact: 발표하기 카드 + 투표 카드 ──────────────────────────────────
class _CompactBody extends StatelessWidget {
  final SessionState state;
  final String? myVote;
  final _MicStatus micStatus;
  final bool isToggleMode;
  final String? lastTranscript;
  final VoidCallback onMicTap;
  final VoidCallback onMicLongPressStart;
  final VoidCallback onMicLongPressEnd;
  final VoidCallback onMicLongPressCancel;
  final void Function(String) onVote;

  const _CompactBody({
    required this.state,
    required this.myVote,
    required this.micStatus,
    required this.isToggleMode,
    required this.lastTranscript,
    required this.onMicTap,
    required this.onMicLongPressStart,
    required this.onMicLongPressEnd,
    required this.onMicLongPressCancel,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
          child: _SpeakCard(
            micStatus: micStatus,
            isToggleMode: isToggleMode,
            lastTranscript: lastTranscript,
            onTap: onMicTap,
            onLongPressStart: onMicLongPressStart,
            onLongPressEnd: onMicLongPressEnd,
            onLongPressCancel: onMicLongPressCancel,
          ),
        ),
        if (state.voteOpen) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 20, 14, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '투표 참여',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: kInk),
              ),
            ),
          ),
          Expanded(
            child: _VoteList(
              state: state,
              myVote: myVote,
              onVote: onVote,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
            ),
          ),
        ] else
          const Spacer(),
      ],
    );
  }
}

// ── Medium: 발표(왼) + 투표(오) ───────────────────────────────────────────
class _MediumBody extends StatelessWidget {
  final SessionState state;
  final String? myVote;
  final _MicStatus micStatus;
  final bool isToggleMode;
  final String? lastTranscript;
  final VoidCallback onMicTap;
  final VoidCallback onMicLongPressStart;
  final VoidCallback onMicLongPressEnd;
  final VoidCallback onMicLongPressCancel;
  final void Function(String) onVote;

  const _MediumBody({
    required this.state,
    required this.myVote,
    required this.micStatus,
    required this.isToggleMode,
    required this.lastTranscript,
    required this.onMicTap,
    required this.onMicLongPressStart,
    required this.onMicLongPressEnd,
    required this.onMicLongPressCancel,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    return Row(
      children: [
        // 왼쪽: 내 발표
        SizedBox(
          width: w * 0.5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 10, 20),
            child: Column(
              children: [
                Expanded(
                  child: _SpeakCard(
                    micStatus: micStatus,
                    isToggleMode: isToggleMode,
                    lastTranscript: lastTranscript,
                    onTap: onMicTap,
                    onLongPressStart: onMicLongPressStart,
                    onLongPressEnd: onMicLongPressEnd,
                    onLongPressCancel: onMicLongPressCancel,
                  ),
                ),
                const SizedBox(height: 10),
                _WaitingInfo(ideaCount: state.ideas.length),
              ],
            ),
          ),
        ),
        Container(width: 1, color: const Color(0xFFE0DDD6)),
        // 오른쪽: 투표
        Expanded(
          child: state.voteOpen
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 24, 20, 10),
                      child: Text(
                        '지금 투표',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: kInk,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _VoteList(
                        state: state,
                        myVote: myVote,
                        onVote: onVote,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      ),
                    ),
                  ],
                )
              : const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      '교사가 투표를 시작하면\n여기에 표시됩니다.',
                      style: TextStyle(
                          fontSize: 14, color: Colors.black38),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── 발표하기 카드 ─────────────────────────────────────────────────────────
class _SpeakCard extends StatelessWidget {
  final _MicStatus micStatus;
  final bool isToggleMode;
  final String? lastTranscript;
  final VoidCallback onTap;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;
  final VoidCallback onLongPressCancel;

  const _SpeakCard({
    required this.micStatus,
    required this.isToggleMode,
    required this.lastTranscript,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    required this.onLongPressCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isRecording = micStatus == _MicStatus.recording;
    final isTranscribing = micStatus == _MicStatus.transcribing;

    final bg = isRecording
        ? const Color(0xFFD32F2F)
        : isTranscribing
            ? kGreen.withValues(alpha: 0.7)
            : kGreen;

    final statusText = isRecording
        ? (isToggleMode ? '녹음 중 · 다시 탭하면 전송' : '녹음 중 · 손을 떼면 전송')
        : isTranscribing
            ? '변환 중...'
            : '탭하거나 길게 눌러 말하기';

    return GestureDetector(
      onTap: isTranscribing ? null : onTap,
      onLongPressStart: isTranscribing ? null : (_) => onLongPressStart(),
      onLongPressEnd: isTranscribing ? null : (_) => onLongPressEnd(),
      onLongPressCancel: isTranscribing ? null : onLongPressCancel,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isRecording ? Icons.mic : Icons.mic_none,
              size: 52,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 14),
            const Text(
              '발표하기',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
            if (lastTranscript != null && !isRecording) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"$lastTranscript"',
                  style: const TextStyle(
                      fontSize: 13, color: Colors.white, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 대기 중인 발표자 수 ───────────────────────────────────────────────────
class _WaitingInfo extends StatelessWidget {
  final int ideaCount;

  const _WaitingInfo({required this.ideaCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0DDD6)),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black54),
          children: [
            const TextSpan(text: '대기 중인 발표자 '),
            TextSpan(
              text: '$ideaCount명',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: kGreen),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── 투표 카드 목록 (승인된 그룹 기반) ────────────────────────────────────
class _VoteList extends StatelessWidget {
  final SessionState state;
  final String? myVote;
  final void Function(String) onVote;
  final EdgeInsets padding;

  const _VoteList({
    required this.state,
    required this.myVote,
    required this.onVote,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final groups = state.approvedGroups;

    if (groups.isEmpty) {
      return const Center(
        child: Text(
          '교사가 투표 그룹을 승인하면\n여기에 표시됩니다.',
          style: TextStyle(color: Colors.black38),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      padding: padding,
      itemCount: groups.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final group = groups[index];
        final isSelected = myVote == group.groupId;

        return GestureDetector(
          onTap: () => onVote(group.groupId),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isSelected ? kGreen : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? kGreen : const Color(0xFFE0DDD6),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  group.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : kInk,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (group.ideaIds.length > 1) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${group.ideaIds.length}개 의견',
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.black38,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _MicStatus { idle, recording, transcribing }
