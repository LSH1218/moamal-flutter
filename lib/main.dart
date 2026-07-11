import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'repositories/firebase_moamal_repository.dart';
import 'services/auth_service.dart';
import 'services/deep_link_service.dart';
import 'services/prompt_config.dart';
import 'screens/common/landing_screen.dart';
import 'screens/student/student_session_screen.dart';
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

    // 앱이 닫혀 있다가 QR로 열린 경우
    final initialCode = await _deepLinkService.getInitialCode();
    if (initialCode != null && mounted) {
      _joinWithCode(initialCode);
      return;
    }

    // 앱이 이미 켜진 상태에서 QR 스캔한 경우
    _linkSub = _deepLinkService.codeStream().listen((code) {
      if (mounted) _joinWithCode(code);
    });
  }

  Future<void> _joinWithCode(String code) async {
    final auth = context.read<AuthService>();
    await auth.signInAnonymously();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StudentSessionScreen(sessionCode: code),
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