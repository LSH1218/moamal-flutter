import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import 'pending_approval_screen.dart';
import 'teacher_home_screen.dart';

enum _Provider { google, kakao, naver }

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  _Provider? _loading;

  Future<void> _signIn(_Provider provider) async {
    if (_loading != null) return;
    setState(() => _loading = provider);

    final auth = context.read<AuthService>();
    try {
      switch (provider) {
        case _Provider.google:
          await auth.signInWithGoogle();
        case _Provider.kakao:
          await auth.signInWithKakao();
        case _Provider.naver:
          await auth.signInWithNaver();
      }
      if (!mounted) return;

      final access = await auth.checkTeacherAccess();
      if (!mounted) return;

      if (access == TeacherAccessResult.approved) {
        final title = await _showTitleDialog();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TeacherHomeScreen(initialTitle: title),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  Future<String?> _showTitleDialog() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: context.isTablet
              ? MediaQuery.sizeOf(context).width * 0.25
              : 40.0,
          vertical: 24,
        ),
        title: const Text('수업 제목'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예) 3학년 2반 · 수학'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('건너뛰기'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('시작'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: kGround,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 48),
                      const _LogoSection(),
                      const SizedBox(height: 64),
                      Padding(
                        padding: EdgeInsets.fromLTRB(28, 0, 28, 24 + bottomPad),
                        child: _BottomSection(
                          loading: _loading,
                          onSignIn: _signIn,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 로고 섹션 ─────────────────────────────────────────────────────────────
class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 그린 필 위에 브랜드 색상 그대로 유지
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: kGreen,
            borderRadius: BorderRadius.circular(18),
          ),
          child: RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 46,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                height: 1,
              ),
              children: [
                TextSpan(text: '모아', style: TextStyle(color: Colors.white)),
                TextSpan(text: '말', style: TextStyle(color: kYellow)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          '선생님의 기록을 도우며,\n아이들의 목소리를 모읍니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Colors.black45,
            height: 1.75,
          ),
        ),
      ],
    );
  }
}

// ── 하단 섹션 ─────────────────────────────────────────────────────────────
class _BottomSection extends StatelessWidget {
  final _Provider? loading;
  final void Function(_Provider) onSignIn;

  const _BottomSection({
    required this.loading,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 교사 전용 안내 문구
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0DDD6)),
          ),
          child: const Text(
            '※ 본 기능은 교사 전용 서비스입니다.\n학생은 QR코드로 접속해 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black45,
              height: 1.55,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _SocialButton(
          label: 'Google로 계속하기',
          bgColor: Colors.white,
          textColor: const Color(0xFF191919),
          borderColor: const Color(0xFFDDDDDD),
          logo: const _GoogleGIcon(size: 20),
          isLoading: loading == _Provider.google,
          isDisabled: loading != null && loading != _Provider.google,
          onTap: () => onSignIn(_Provider.google),
        ),
        const SizedBox(height: 10),
        _SocialButton(
          label: '카카오로 계속하기',
          bgColor: const Color(0xFFFEE500),
          textColor: const Color(0xFF191919),
          logo: const _KakaoIcon(size: 20),
          isLoading: loading == _Provider.kakao,
          isDisabled: loading != null && loading != _Provider.kakao,
          onTap: () => onSignIn(_Provider.kakao),
        ),
        const SizedBox(height: 10),
        _SocialButton(
          label: '네이버로 계속하기',
          bgColor: const Color(0xFF03C75A),
          textColor: Colors.white,
          logo: const _NaverIcon(size: 20),
          isLoading: loading == _Provider.naver,
          isDisabled: loading != null && loading != _Provider.naver,
          onTap: () => onSignIn(_Provider.naver),
        ),
      ],
    );
  }
}

// ── 소셜 로그인 버튼 ──────────────────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;
  final Color? borderColor;
  final Widget logo;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.logo,
    required this.isLoading,
    required this.isDisabled,
    required this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: isDisabled,
      child: AnimatedOpacity(
        opacity: isDisabled ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: isLoading ? null : onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: Colors.black.withValues(alpha: 0.08),
            highlightColor: Colors.black.withValues(alpha: 0.04),
            child: Container(
              height: 52,
              decoration: borderColor != null
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor!, width: 1.5),
                    )
                  : null,
              alignment: Alignment.center,
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: textColor,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        logo,
                        const SizedBox(width: 10),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Google G 아이콘 (CustomPainter) ───────────────────────────────────────
class _GoogleGIcon extends StatelessWidget {
  final double size;
  const _GoogleGIcon({this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final sw = size.width * 0.27;      // 획 굵기
    final ar = size.width / 2 - sw / 2; // 호 반지름
    final rect = Rect.fromCircle(center: c, radius: ar);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.butt;

    // Green: 30° → 90° (하단 우측 → 하단)
    p.color = const Color(0xFF34A853);
    canvas.drawArc(rect, _r(30), _r(60), false, p);

    // Yellow: 90° → 180° (하단 → 좌측)
    p.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, _r(90), _r(90), false, p);

    // Red: 180° → 330° (좌측 → 상단 → 우상단)
    p.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, _r(180), _r(150), false, p);

    // 330° → 30° 구간 = G 개구부 (아무것도 그리지 않음)

    // Blue 수평 바: 중심에서 오른쪽 끝까지 (G의 가로획)
    final barHalf = sw / 2;
    canvas.drawRect(
      Rect.fromLTRB(c.dx, c.dy - barHalf, size.width, c.dy + barHalf),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..style = PaintingStyle.fill,
    );
  }

  static double _r(double deg) => deg * math.pi / 180;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── 카카오 아이콘 (말풍선 실루엣) ─────────────────────────────────────────
class _KakaoIcon extends StatelessWidget {
  final double size;
  const _KakaoIcon({this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _KakaoPainter()),
    );
  }
}

class _KakaoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color = const Color(0xFF191919)
      ..style = PaintingStyle.fill;

    // 타원형 말풍선 몸체
    final bubbleH = h * 0.78;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, bubbleH / 2),
        width: w,
        height: bubbleH,
      ),
      p,
    );

    // 하단 꼬리 삼각형
    final tail = Path()
      ..moveTo(w * 0.34, bubbleH * 0.88)
      ..lineTo(w * 0.20, h)
      ..lineTo(w * 0.54, bubbleH * 0.92)
      ..close();
    canvas.drawPath(tail, p);

    // 눈 두 개 (노란 점)
    final eyeP = Paint()
      ..color = const Color(0xFFFEE500)
      ..style = PaintingStyle.fill;
    final eyeR = w * 0.07;
    canvas.drawCircle(Offset(w * 0.34, bubbleH * 0.42), eyeR, eyeP);
    canvas.drawCircle(Offset(w * 0.66, bubbleH * 0.42), eyeR, eyeP);

    // 입 호
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.50, bubbleH * 0.50),
        width: w * 0.40,
        height: w * 0.20,
      ),
      0,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFFFEE500)
        ..style = PaintingStyle.stroke
        ..strokeWidth = eyeR * 1.1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── 네이버 N 아이콘 (CustomPainter) ──────────────────────────────────────
class _NaverIcon extends StatelessWidget {
  final double size;
  const _NaverIcon({this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _NaverNPainter()),
    );
  }
}

class _NaverNPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final sw = w * 0.22;
    final pad = sw / 2;
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;

    canvas.drawLine(Offset(pad, pad), Offset(pad, h - pad), p);         // 왼쪽 세로
    canvas.drawLine(Offset(pad, pad), Offset(w - pad, h - pad), p);    // 대각선
    canvas.drawLine(Offset(w - pad, pad), Offset(w - pad, h - pad), p); // 오른쪽 세로
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
