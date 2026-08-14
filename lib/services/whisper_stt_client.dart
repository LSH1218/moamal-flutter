import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

const _defaultEndpoint =
    'https://transcribeaudio-xzj4mtcbda-du.a.run.app';
const _endpoint = String.fromEnvironment(
  'STT_PROXY_URL',
  defaultValue: _defaultEndpoint,
);

const _maxRetries = 3;
const _proxyTimeout = Duration(seconds: 30);

const _sttLanguage = 'ko';

/// 세션 제목에서 수업 유형(Layer 1)과 주제(Layer 2)를 조합해 Whisper prompt를 생성한다.
String buildWhisperPrompt(String sessionTitle) {
  final String context;
  if (sessionTitle.contains('토론') || sessionTitle.contains('토의')) {
    context = '초·중등 학생들의 토론 수업 음성입니다. 찬성, 반대, 주장, 근거, 반론 등의 단어가 사용됩니다.';
  } else if (sessionTitle.contains('발표') || sessionTitle.contains('조사')) {
    context = '학생들의 주제 발표 및 조사 내용 공유 음성입니다. 조사, 발표, 자료, 첫째, 결론 등의 단어가 사용됩니다.';
  } else if (sessionTitle.contains('회의')) {
    context = '학급 회의 음성입니다. 안건, 동의, 표결 등의 단어가 사용됩니다.';
  } else if (sessionTitle.contains('심포지엄')) {
    context = '학생 심포지엄 음성입니다. 연구, 발표, 질문, 답변 등의 단어가 사용됩니다.';
  } else {
    context = '초·중등 수업 현장의 학생 발화 음성입니다.';
  }
  final topic = sessionTitle.isNotEmpty ? ' 수업 주제: "$sessionTitle"' : '';
  return '$context$topic';
}

class WhisperSttClient {
  final _recorder = AudioRecorder();
  String? _tempPath;
  bool _recording = false;
  bool get isRecording => _recording;

  Future<void> startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) throw Exception('마이크 권한이 필요합니다.');

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

  /// 녹음 중지 후 Whisper 전사. 네트워크 실패 시 최대 3회 재시도.
  Future<String> stopAndTranscribe(String prompt) async {
    if (!_recording) throw Exception('녹음 중이 아닙니다.');

    final path = await _recorder.stop();
    _recording = false;
    _tempPath = null;

    if (path == null) throw Exception('녹음 파일을 찾을 수 없습니다.');

    final file = File(path);
    if (!await file.exists()) throw Exception('녹음 파일이 없습니다.');

    try {
      return await _transcribeWithRetry(file, prompt);
    } finally {
      // 성공·실패 무관하게 재시도 끝난 뒤 파일 삭제
      if (await file.exists()) await file.delete();
    }
  }

  Future<String> _transcribeWithRetry(File file, String prompt) async {
    Exception? lastError;

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      if (attempt > 0) {
        // 1초 → 2초 지수 백오프
        await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
      }

      try {
        return await _callProxy(file, prompt);
      } on _RetryableException catch (e) {
        lastError = Exception(e.message);
      } on Exception {
        rethrow; // 4xx 등 재시도 불가 에러는 즉시 상위로
      }
    }

    throw lastError ?? Exception('음성 변환에 실패했습니다.');
  }

  Future<String> _callProxy(File file, String prompt) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다.');

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception('인증 토큰을 가져오지 못했습니다.');
    }

    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'language': _sttLanguage,
      'prompt': prompt,
    });

    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'audio/mp4',
            },
            body: await file.readAsBytes(),
          )
          .timeout(_proxyTimeout);
    } on SocketException {
      throw _RetryableException('네트워크 연결을 확인해 주세요.');
    } on TimeoutException {
      throw _RetryableException('서버 응답이 너무 느립니다. 다시 시도합니다.');
    }

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final text = json['text'] as String?;
      return text?.trim() ?? '';
    }

    // 5xx: 서버 일시 오류 → 재시도
    if (response.statusCode >= 500) {
      throw _RetryableException('서버 오류 (${response.statusCode})');
    }

    // 4xx: 클라이언트 문제 → 즉시 실패
    throw Exception(_clientErrorMessage(response.statusCode));
  }

  String _clientErrorMessage(int statusCode) => switch (statusCode) {
        401 => '인증이 만료되었습니다. 다시 시도해 주세요.',
        413 => '녹음이 너무 깁니다. 짧게 나눠서 발표해 주세요.',
        415 => '지원하지 않는 오디오 형식입니다.',
        429 => '잠시 후 다시 시도해 주세요.',
        _ => '음성 변환에 실패했습니다. ($statusCode)',
      };

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

  /// 녹음 중 진폭(dBFS) 스트림. 200ms 간격. VAD에서 구독한다.
  Stream<double> get amplitudeStream => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 200))
      .map((a) => a.current);

  void dispose() {
    _recorder.dispose();
  }
}

class _RetryableException implements Exception {
  final String message;
  const _RetryableException(this.message);
}
