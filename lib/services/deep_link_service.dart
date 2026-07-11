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
