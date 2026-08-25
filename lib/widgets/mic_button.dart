import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/whisper_stt_client.dart';
import '../theme/app_theme.dart';

/// 원형 마이크 버튼 — 4상태 + 탭 토글 / PTT 이중 인터랙션.
///
/// 탭: 대기→녹음 / 녹음(탭모드)→전사
/// 길게 누르기: 누른 동안 녹음, 손 떼면 전사
///
/// onResult(text, isPtt): isPtt=true면 교사 초안 시트, false면 즉시 기록/제출
class MicButton extends StatefulWidget {
  final WhisperSttClient sttClient;
  final void Function(String text, bool isPtt) onResult;
  final void Function(String message) onError;
  final String prompt;
  final double size;
  final bool forceStopped;
  final bool isDraftOpen;

  const MicButton({
    super.key,
    required this.sttClient,
    required this.onResult,
    required this.onError,
    this.prompt = '',
    this.size = 72,
    this.forceStopped = false,
    this.isDraftOpen = false,
  });

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> with TickerProviderStateMixin {
  _InternalState _state = _InternalState.idle;
  bool _isPtt = false;

  late final AnimationController _rippleCtrl;
  late final Animation<double> _rippleScale;
  late final Animation<double> _rippleOpacity;

  @override
  void initState() {
    super.initState();
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _rippleScale = Tween<double>(begin: 1.0, end: 1.9).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut),
    );
    _rippleOpacity = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(MicButton old) {
    super.didUpdateWidget(old);
    if (widget.isDraftOpen && !old.isDraftOpen) {
      HapticFeedback.lightImpact();
      Future.delayed(const Duration(milliseconds: 130), HapticFeedback.lightImpact);
    }
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    super.dispose();
  }

  bool get _isInteractable =>
      !widget.forceStopped &&
      !widget.isDraftOpen &&
      _state != _InternalState.transcribing;

  void _handleTap() {
    if (!_isInteractable) return;
    if (_state == _InternalState.idle) {
      _isPtt = false;
      _startRecording();
    } else if (_state == _InternalState.recording && !_isPtt) {
      _stopAndTranscribe();
    }
  }

  void _handleLongPressStart(LongPressStartDetails _) {
    if (!_isInteractable) return;
    if (_state != _InternalState.idle) return;
    _isPtt = true;
    _startRecording();
  }

  void _handleLongPressEnd(LongPressEndDetails _) {
    if (_state == _InternalState.recording && _isPtt) {
      _stopAndTranscribe();
    }
  }

  Future<void> _startRecording() async {
    try {
      await widget.sttClient.startRecording();
      if (!mounted) return;
      setState(() => _state = _InternalState.recording);
      _rippleCtrl.repeat();
      HapticFeedback.lightImpact();
    } catch (e) {
      widget.onError(e.toString());
    }
  }

  Future<void> _stopAndTranscribe() async {
    _rippleCtrl.stop();
    _rippleCtrl.reset();
    final wasPtt = _isPtt;
    setState(() => _state = _InternalState.transcribing);
    try {
      final text = await widget.sttClient.stopAndTranscribe(widget.prompt);
      if (text.isNotEmpty) widget.onResult(text, wasPtt);
    } catch (e) {
      widget.onError(e.toString());
    } finally {
      if (mounted) setState(() => _state = _InternalState.idle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = widget.forceStopped
        ? _Visual.forceStopped
        : widget.isDraftOpen
            ? _Visual.draft
            : switch (_state) {
                _InternalState.idle => _Visual.idle,
                _InternalState.recording => _Visual.recording,
                _InternalState.transcribing => _Visual.transcribing,
              };

    final size = widget.size;

    return GestureDetector(
      onTap: _handleTap,
      onLongPressStart: _handleLongPressStart,
      onLongPressEnd: _handleLongPressEnd,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (visual == _Visual.recording)
              AnimatedBuilder(
                animation: _rippleCtrl,
                builder: (_, __) => Container(
                  width: size * _rippleScale.value,
                  height: size * _rippleScale.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kRed.withValues(alpha: _rippleOpacity.value),
                  ),
                ),
              ),
            _MainCircle(visual: visual, size: size),
          ],
        ),
      ),
    );
  }
}

class _MainCircle extends StatelessWidget {
  final _Visual visual;
  final double size;

  const _MainCircle({required this.visual, required this.size});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, hasDraftRing) = switch (visual) {
      _Visual.idle => (kYellow, kInk, false),
      _Visual.recording => (kRed, Colors.white, false),
      _Visual.transcribing => (kBlue, Colors.white, false),
      _Visual.draft => (kYellow, kInk, true),
      _Visual.forceStopped => (kDisabled, Colors.white, false),
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: hasDraftRing ? Border.all(color: kInk, width: 3) : null,
      ),
      child: visual == _Visual.transcribing
          ? Center(
              child: SizedBox(
                width: size * 0.36,
                height: size * 0.36,
                child: CircularProgressIndicator(
                  color: fg,
                  strokeWidth: 2.5,
                ),
              ),
            )
          : Icon(
              switch (visual) {
                _Visual.idle => Icons.mic_none,
                _Visual.recording => Icons.mic,
                _Visual.draft => Icons.check,
                _Visual.forceStopped => Icons.mic_off,
                _ => Icons.mic_none,
              },
              color: fg,
              size: size * 0.38,
            ),
    );
  }
}

enum _InternalState { idle, recording, transcribing }

enum _Visual { idle, recording, transcribing, draft, forceStopped }
