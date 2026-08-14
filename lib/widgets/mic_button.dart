import 'package:flutter/material.dart';
import '../services/whisper_stt_client.dart';
import '../theme/app_theme.dart';

/// 누르는 동안 녹음, 떼면 Whisper로 전사.
/// 기본 상태 = Yellow CTA, 녹음 중 = 빨간색, 전사 중 = 비활성
class MicButton extends StatefulWidget {
  final WhisperSttClient sttClient;
  final void Function(String text) onResult;
  final void Function(String message) onError;
  final String prompt;

  const MicButton({
    super.key,
    required this.sttClient,
    required this.onResult,
    required this.onError,
    this.prompt = '',
  });

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> {
  _Status _status = _Status.idle;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg, icon) = switch (_status) {
      _Status.idle => (
          '길게 눌러 발표',
          kYellow,
          kInk,
          Icons.mic_none,
        ),
      _Status.recording => (
          '녹음 중 · 떼면 전송',
          const Color(0xFFD32F2F),
          Colors.white,
          Icons.mic,
        ),
      _Status.transcribing => (
          '변환 중...',
          const Color(0xFFBDBDBD),
          Colors.white,
          Icons.hourglass_top,
        ),
    };

    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopAndTranscribe(),
      onLongPressCancel: () => _cancel(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    if (_status != _Status.idle) return;
    try {
      await widget.sttClient.startRecording();
      if (mounted) setState(() => _status = _Status.recording);
    } catch (e) {
      widget.onError(e.toString());
    }
  }

  Future<void> _stopAndTranscribe() async {
    if (_status != _Status.recording) return;
    setState(() => _status = _Status.transcribing);
    try {
      final text = await widget.sttClient.stopAndTranscribe(widget.prompt);
      if (text.isNotEmpty) widget.onResult(text);
    } catch (e) {
      widget.onError(e.toString());
    } finally {
      if (mounted) setState(() => _status = _Status.idle);
    }
  }

  Future<void> _cancel() async {
    if (_status == _Status.recording) {
      await widget.sttClient.cancel();
      if (mounted) setState(() => _status = _Status.idle);
      widget.onError('너무 짧게 눌렀습니다. 다시 시도해 주세요.');
    }
  }
}

enum _Status { idle, recording, transcribing }
