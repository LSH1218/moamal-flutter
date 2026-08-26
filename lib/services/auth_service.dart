import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';

enum TeacherAccessResult { approved, pending }

const _allowedDomains = {
  'korea.kr',
  'sen.go.kr', 'ice.go.kr', 'pen.go.kr', 'dge.go.kr', 'gen.go.kr',
  'dje.go.kr', 'wse.go.kr', 'sje.go.kr', 'goe.go.kr', 'gwe.go.kr',
  'cbe.go.kr', 'cne.go.kr', 'jbe.go.kr', 'jne.go.kr', 'gbe.kr',
  'gne.go.kr', 'jje.go.kr',
};

const _allowedSuffixes = ['.es.kr', '.ms.kr', '.hs.kr', '.sc.kr'];

const _kakaoVerifyUrl =
    'https://asia-northeast3-moamal-1e601.cloudfunctions.net/kakaoVerify';
const _naverVerifyUrl =
    'https://asia-northeast3-moamal-1e601.cloudfunctions.net/naverVerify';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  String? get currentUid => _auth.currentUser?.uid;
  bool get isSignedIn => _auth.currentUser != null;

  /// 교사: Google 로그인
  Future<String> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google 로그인 취소됨');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    return result.user!.uid;
  }

  /// 교사: 카카오 로그인
  /// 카카오톡 앱이 설치되어 있으면 앱 로그인, 없으면 웹 계정 로그인으로 자동 전환
  Future<String> signInWithKakao() async {
    OAuthToken token;
    if (await isKakaoTalkInstalled()) {
      try {
        token = await UserApi.instance.loginWithKakaoTalk();
      } catch (_) {
        // 카카오톡 앱 로그인 실패 시 웹 로그인으로 폴백
        token = await UserApi.instance.loginWithKakaoAccount();
      }
    } else {
      token = await UserApi.instance.loginWithKakaoAccount();
    }

    return _exchangeCustomToken(
      url: _kakaoVerifyUrl,
      accessToken: token.accessToken,
      provider: '카카오',
    );
  }

  /// 교사: 네이버 로그인
  /// 네이버 앱/웹 로그인은 flutter_naver_login 패키지가 자동으로 처리
  Future<String> signInWithNaver() async {
    final result = await FlutterNaverLogin.logIn();

    if (result.status != NaverLoginStatus.loggedIn) {
      throw Exception(
        result.status == NaverLoginStatus.error
            ? '네이버 로그인 실패: ${result.errorMessage}'
            : '네이버 로그인 취소됨',
      );
    }

    final accessToken = result.accessToken?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('네이버 액세스 토큰을 받지 못했습니다');
    }

    return _exchangeCustomToken(
      url: _naverVerifyUrl,
      accessToken: accessToken,
      provider: '네이버',
    );
  }

  /// accessToken을 Cloud Function에 전달해 Firebase Custom Token으로 교환 후 로그인
  Future<String> _exchangeCustomToken({
    required String url,
    required String accessToken,
    required String provider,
  }) async {
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'accessToken': accessToken}),
    );

    if (response.statusCode != 200) {
      throw Exception('$provider 서버 인증 실패 (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final customToken = data['customToken'] as String?;
    if (customToken == null || customToken.isEmpty) {
      throw Exception('$provider Custom Token을 받지 못했습니다');
    }

    final credential = await _auth.signInWithCustomToken(customToken);
    return credential.user!.uid;
  }

  /// 교사 접근 권한 확인
  /// 도메인 자동 승인 → 화이트리스트 확인 순서로 검사
  Future<TeacherAccessResult> checkTeacherAccess() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('로그인 상태가 아닙니다');

    final email = user.email?.toLowerCase();

    if (email != null && email.contains('@')) {
      final domain = email.split('@').last.toLowerCase();
      if (_allowedDomains.contains(domain)) return TeacherAccessResult.approved;
      if (RegExp(r'^.+\.(es|ms|hs|sc)\.kr$').hasMatch(domain)) {
        return TeacherAccessResult.approved;
      }
    }

    final db = FirebaseFirestore.instance;

    if (email != null && email.isNotEmpty) {
      final doc = await db.collection('whitelisted_teachers').doc(email).get();
      if (doc.exists) return TeacherAccessResult.approved;
    }

    final uidDoc =
        await db.collection('whitelisted_teachers').doc(user.uid).get();
    if (uidDoc.exists) return TeacherAccessResult.approved;

    return TeacherAccessResult.pending;
  }

  /// 학생: 익명 로그인.
  ///
  /// 항상 익명 세션을 보장한다 (Common-Auth-01). 기존에 남아 있던 로그인이
  /// 이미 익명이면 그대로 재사용하지만(같은 학생 재입장 시 참여 기록이 이어짐),
  /// 실제 계정(교사가 로그인한 구글·카카오·네이버 등)이면 잘못된 신분으로
  /// 입장하게 되므로 그 세션만 지우고 새 익명 세션을 발급한다.
  ///
  /// 여기서는 `FirebaseAuth.signOut()`만 호출한다 — 학생 입장은 수업 시작
  /// 직후 빠르게 통과해야 하는 구간이라, 구글/카카오/네이버 SDK까지 함께
  /// 끊는 전체 로그아웃(`signOut()`)은 불필요한 네트워크 호출과 지연·실패
  /// 위험을 더한다. 기기에 남은 외부 로그인 상태 자체는 건드리지 않는다.
  Future<String> signInAnonymously() async {
    final current = _auth.currentUser;
    if (current != null) {
      if (current.isAnonymous) return current.uid;
      await _auth.signOut();
    }
    final result = await _auth.signInAnonymously();
    return result.user!.uid;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    if (await FlutterNaverLogin.isLoggedIn()) await FlutterNaverLogin.logOut();
    await _auth.signOut();
  }

  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;
}
