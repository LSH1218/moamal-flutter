import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'repositories/firebase_moamal_repository.dart';
import 'services/auth_service.dart';
import 'services/deep_link_service.dart';
import 'services/prompt_config.dart';
import 'screens/common/landing_screen.dart';
import 'screens/teacher/teacher_home_screen.dart';
import 'screens/student/join_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 태블릿은 가로/세로 모두 허용, 폰은 세로 고정
  // (실제 기기 판단은 런타임에서 MediaQuery로 분기)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  KakaoSdk.init(nativeAppKey: '287dec7ec232fe4d45c04f8b06a14bdb');

  await Firebase.initializeApp();
  await PromptConfig.init();
  runApp(const MoamalApp());
}

class MoamalApp extends StatelessWidget {
  const MoamalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => FirebaseMoamalRepository()),
        Provider(create: (_) => DeepLinkService()),
      ],
      child: MaterialApp(
        title: '모아말',
        theme: buildAppTheme(),
        home: const _AppEntryPoint(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          // 시스템 폰트 크기를 최대 1.3배로 제한 — 카드 레이아웃 보호
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.of(context).textScaler.clamp(
                    minScaleFactor: 1.0,
                    maxScaleFactor: 1.3,
                  ),
            ),
            child: child!,
          );
        },
      ),
    );
  }
}

/// 앱 시작 시 딥링크 여부를 확인해 적절한 화면으로 진입.
class _AppEntryPoint extends StatefulWidget {
  const _AppEntryPoint();

  @override
  State<_AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<_AppEntryPoint> {
  late DeepLinkService _deepLinkService;
  StreamSubscription<String>? _linkSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    _deepLinkService = context.read<DeepLinkService>();

    // 앱이 이미 켜진 상태에서 QR을 스캔한 경우.
    // 아래 분기에서 return되어도 딥링크를 받을 수 있도록 먼저 구독한다.
    _linkSub = _deepLinkService.codeStream().listen((code) {
      if (mounted) _joinWithCode(code);
    });

    // 앱이 닫혀 있다가 QR로 열린 경우
    final initialCode = await _deepLinkService.getInitialCode();
    if (initialCode != null && mounted) {
      _joinWithCode(initialCode);
      return;
    }

    // 교사 세션 복귀: 앱 재시작 시 진행 중이던 수업으로 돌아감
    final prefs = await SharedPreferences.getInstance();
    final activeSession = prefs.getString('active_teacher_session');
    if (activeSession != null && mounted) {
      final auth = context.read<AuthService>();
      if (auth.currentUid == null) await auth.signInAnonymously();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TeacherHomeScreen(existingCode: activeSession),
        ),
      );
    }
  }

  /// 딥링크로 들어온 학생을 코드 직접 입력과 동일한 경로에 태운다.
  /// 세션 확인 → 이름·번호 입력 → 발표 화면.
  /// 바로 발표 화면으로 보내면 participants 등록이 빠져
  /// 교사 화면에 참여자로 잡히지 않는다.
  Future<void> _joinWithCode(String code) async {
    final auth = context.read<AuthService>();
    final repo = context.read<FirebaseMoamalRepository>();
    await auth.signInAnonymously();
    if (!mounted) return;
    final title = await repo.fetchSessionTitle(code);
    if (!mounted) return;
    if (title == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('세션을 찾을 수 없어요. 코드를 확인해 주세요.'),
        ),
      );
      return;
    }
    // 이미 다른 화면을 보고 있는 중에 딥링크가 오면 그 위에 계속 쌓인다.
    // 두 번 스캔하거나 공유 링크를 연달아 누르면 뒤로 가기 횟수가 쌓여 혼란스러워진다.
    // 스택을 루트까지 걷어낸 뒤 한 겹만 쌓는다 (Gemini-1-Deeplink-02).
    Navigator.popUntil(context, (route) => route.isFirst);
    // pushReplacement를 쓰면 랜딩이 스택에서 빠져 뒤로 가기가 블랙스크린이 된다.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentProfileScreen(
          sessionCode: code,
          sessionTitle: title,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const LandingScreen();
}