import 'dart:async';
import 'package:app_links/app_links.dart';

/// moamal://join/XXXXXX 형식 딥링크를 처리.
/// Java resolveDeepLink() 동일 로직.
class DeepLinkService {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// 앱 시작 시 초기 링크(이미 열린 링크)를 반환.
  /// QR 스캔으로 앱이 새로 열린 경우.
  Future<String?> getInitialCode() async {
    try {
      final uri = await _appLinks.getInitialLink();
      return _parseCode(uri);
    } catch (_) {
      return null;
    }
  }

  /// 앱이 이미 실행 중일 때 들어오는 링크를 스트림으로 수신.
  /// onNewIntent 케이스.
  Stream<String> codeStream() {
    return _appLinks.uriLinkStream
        .map(_parseCode)
        .where((code) => code != null)
        .cast<String>();
  }

  void dispose() {
    _sub?.cancel();
  }

  /// 세션 코드 → QR·공유에 쓸 딥링크 문자열.
  /// QR에 평문 코드만 넣으면 폰 기본 카메라로 찍어도 앱이 열리지 않는다 (Mercury-Share-01).
  static String buildJoinUri(String code) => 'moamal://join/$code';

  /// QR 스캔 원문 → 세션 코드.
  /// 딥링크와 평문 6자리를 모두 받는다 — 이전에 배포된 QR도 계속 동작해야 한다.
  static String? parseScanned(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final fromUri = _parseCode(Uri.tryParse(text));
    if (fromUri != null) return fromUri;
    final plain = text.toUpperCase();
    if (plain.length == 6) return plain;
    return null;
  }

  /// moamal://join/XXXXXX → 'XXXXXX' (대문자)
  /// 형식이 맞지 않으면 null.
  static String? _parseCode(Uri? uri) {
    if (uri == null) return null;
    if (uri.scheme != 'moamal') return null;
    if (uri.host != 'join') return null;
    final segment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    if (segment.isEmpty) return null;
    return segment.toUpperCase();
  }
}
