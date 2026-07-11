import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

const _endpoint = 'https://api.openai.com/v1/audio/transcriptions';
const _openAiKey =
    String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');

/// Java WhisperSttClient 1:1 이식.
/// 녹음: record 패키지 (Android + iOS)
/// 전사: OpenAI Whisper API (엔드포인트/파라미터 동일)
class WhisperSttClient {
  final _recorder = AudioRecorder();
  String? _tempPath;

  bool _recording = false;
  bool get isRecording => _recording;

  /// 녹음 시작. 마이크 권한 없으면 Exception.
  Future<void> startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw Exception('마이크 권한이 필요합니다.');
    }

    final dir = await getTemporaryDirectory();
    _tempPath =
        '${dir.path}/stt_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        bitRate: 64000,
      ),
      path: _tempPath!,
    );
    _recording = true;
  }

  /// 녹음 중지 후 Whisper API로 전사. 결과 텍스트 반환.
  Future<String> stopAndTranscribe() async {
    if (!_recording) throw Exception('녹음 중이 아닙니다.');

    final path = await _recorder.stop();
    _recording = false;

    if (path == null) throw Exception('녹음 파일을 찾을 수 없습니다.');

    final file = File(path);
    if (!await file.exists()) throw Exception('녹음 파일이 없습니다.');

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_endpoint))
        ..headers['Authorization'] = 'Bearer $_openAiKey'
        ..fields['model'] = 'whisper-1'
        ..fields['language'] = 'ko'
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: 'stt.m4a',
        ));

      final streamedResponse = await request.send();
      final raw = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode != 200) {
        throw Exception('API 오류 ${streamedResponse.statusCode}: $raw');
      }

      final json = jsonDecode(raw) as Map<String, dynamic>;
      final text = json['text'] as String?;
      if (text == null || text.isEmpty) throw Exception('응답 파싱 실패');
      return text.trim();
    } finally {
      await file.delete();
    }
  }

  /// 녹음 취소 (손 뗐을 때 너무 짧거나 에러 시)
  Future<void> cancel() async {
    if (_recording) {
      await _recorder.stop();
      _recording = false;
    }
    if (_tempPath != null) {
      final f = File(_tempPath!);
      if (await f.exists()) await f.delete();
      _tempPath = null;
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}
