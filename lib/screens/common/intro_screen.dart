import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repositories/firebase_moamal_repository.dart';
import '../../services/auth_service.dart';
import '../../services/judge_demo_seeder.dart';
import '../../theme/app_theme.dart';
import '../teacher/teacher_home_screen.dart';
import 'landing_screen.dart';

/// 웹 방문자가 링크를 열었을 때 가장 먼저 보는 소개 화면(해커톤 심사용).
/// 스크롤형 한 페이지 — 첫 화면(above the fold)은 짧게, 아래로 갈수록
/// 설명이 깊어진다. 모바일 앱(kIsWeb=false)에서는 쓰이지 않는다.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  bool _isStarting = false;

  Future<void> _startDemo() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);
    try {
      final auth = context.read<AuthService>();
      final repo = context.read<FirebaseMoamalRepository>();
      final sessionCode = await seedJudgeDemoSession(auth: auth, repo: repo);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TeacherHomeScreen(existingCode: sessionCode),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('데모 시작 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _goToApp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LandingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGround,
      body: SingleChildScrollView(
        child: Column(
          // Column 기본값(center)은 자식에게 느슨한 폭 제약을 준다.
          // stretch로 각 섹션(Container(width: double.infinity))이 항상
          // 뷰포트 전체 폭을 확실히 받도록 고정한다.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroSection(isStarting: _isStarting, onStart: _startDemo),
            _FlowSection(),
            _AiSection(),
            _DifferentiationSection(),
            _ValidationSection(),
            _FinalCtaSection(isStarting: _isStarting, onStart: _startDemo),
            _FooterSection(onAppLink: _goToApp),
          ],
        ),
      ),
    );
  }
}

const _muted = Color(0xFF62665D);
const _softGreen = Color(0xFFE8EEE5);

Widget _copy(
  String text, {
  double size = 16,
  bool bold = false,
  Color color = kInk,
}) => Text(
  text,
  style: TextStyle(
    fontSize: size,
    fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
    color: color,
    height: 1.55,
  ),
);
Widget _stack(List<Widget> children, {double gap = 20}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    for (var i = 0; i < children.length; i++) ...[
      if (i > 0) SizedBox(height: gap),
      children[i],
    ],
  ],
);
Widget _card(
  List<Widget> children, {
  Color color = kCardBg,
  double padding = 24,
}) => Container(
  width: double.infinity,
  padding: EdgeInsets.all(padding),
  decoration: BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(18),
  ),
  child: _stack(children, gap: 12),
);

class _SectionShell extends StatelessWidget {
  final Color background;
  final Widget Function(bool mobile) builder;
  const _SectionShell({required this.background, required this.builder});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final mobile = c.maxWidth < 800;
      return ColoredBox(
        color: background,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: mobile ? 24 : 80,
                vertical: mobile ? 48 : 64,
              ),
              child: builder(mobile),
            ),
          ),
        ),
      );
    },
  );
}

class _Cards extends StatelessWidget {
  final List<Widget> children;
  final bool mobile;
  final double gap;
  const _Cards({required this.children, required this.mobile, this.gap = 20});
  @override
  Widget build(BuildContext context) => mobile
      ? _stack(children, gap: gap)
      : IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(child: children[i]),
              ],
            ],
          ),
        );
}

class _HeroSection extends StatelessWidget {
  final bool isStarting;
  final VoidCallback onStart;
  const _HeroSection({required this.isStarting, required this.onStart});
  @override
  Widget build(BuildContext context) => _SectionShell(
    background: kGreen,
    builder: (mobile) {
      final intro = _stack([
        _copy(
          '학생의 생각을,\n수업의 흐름으로',
          size: mobile ? 34 : 46,
          bold: true,
          color: kCardBg,
        ),
        _copy(
          '학생의 이야기를 듣는 동안에도\n교사는 의견을 정리하고, 논의를 이끌고,\n수업 내용을 기록해야 합니다.\n모아말은 이 일을 함께 돕는 수업 도구입니다.',
          size: mobile ? 15 : 17,
          color: kCardBg,
        ),
        _CtaButton(isStarting: isStarting, onTap: onStart),
        _copy('학급회의에서 시작해\n토론·심포지엄 수업까지 넓혀갑니다.', size: 13, color: kYellow),
      ]);
      final example = _card([
        _copy('이렇게 의견을 함께 살펴봐요', size: 17, bold: true, color: kGreen),
        _copy('예시 · 우리 반에서 바꾸고 싶은 것', size: 12, color: _muted),
        _card(
          [_copy('“쉬는 시간이 조금 더 길면 좋겠어요.”', size: 14)],
          color: kGround,
          padding: 12,
        ),
        _card(
          [_copy('“쉬는 시간에 친구와 더 놀고 싶어요.”', size: 14)],
          color: kGround,
          padding: 12,
        ),
        _copy('↓  비슷한 의견을 모으면', size: 13, bold: true, color: kGreen),
        _card(
          [
            _copy('쉬는 시간 늘리기', size: 18, bold: true, color: kGreen),
            _copy('원래 의견을 읽고 선생님이 확인해요.', size: 13, color: _muted),
          ],
          color: _softGreen,
          padding: 16,
        ),
        _copy('기능을 설명하기 위한 예시입니다.', size: 11, color: _muted),
      ], padding: mobile ? 20 : 28);
      return _stack([
        _copy('모아말', size: 26, bold: true, color: kYellow),
        mobile
            ? _stack([intro, example], gap: 32)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: intro),
                  const SizedBox(width: 48),
                  Expanded(child: example),
                ],
              ),
      ], gap: 36);
    },
  );
}

class _FlowSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _SectionShell(
    background: kGround,
    builder: (mobile) => _stack([
      _copy('수업은 이렇게 이어집니다', size: 12, bold: true, color: kGreen),
      _copy('의견을 모으고, 함께 살펴보고, 기록합니다', size: mobile ? 28 : 32, bold: true),
      _Cards(
        mobile: mobile,
        gap: 12,
        children: [
          for (var i = 0; i < 5; i++)
            _card(
              [
                _copy(
                  '0${i + 1}',
                  size: 12,
                  bold: true,
                  color: i == 2 ? kYellow : kGreen,
                ),
                _copy(
                  ['학생 의견', 'AI 정리', '교사 검토', '투표', '수업 기록'][i],
                  size: 18,
                  bold: true,
                  color: i == 2 ? kCardBg : kInk,
                ),
                _copy(
                  [
                    '말이나 글로 생각을 보냅니다.',
                    '비슷한 뜻의 의견을 묶습니다.',
                    '묶음을 살펴보고 후보를 승인합니다.',
                    '승인된 후보에 한 표를 보냅니다.',
                    '의견과 투표 결과를 함께 남깁니다.',
                  ][i],
                  size: 14,
                  color: i == 2 ? kCardBg : _muted,
                ),
              ],
              color: i == 2 ? kGreen : kCardBg,
              padding: 18,
            ),
        ],
      ),
      _copy(
        '어떤 의견을 함께 묶을지는 교사가 확인합니다.\n학생들이 처음에 한 말도 다시 볼 수 있습니다.',
        size: 15,
        bold: true,
        color: kGreen,
      ),
    ], gap: 28),
  );
}

class _AiSection extends StatelessWidget {
  const _AiSection();
  @override
  Widget build(BuildContext context) => _SectionShell(
    background: kCardBg,
    builder: (mobile) => _stack([
      _copy('수업을 돕는 AI', size: 12, bold: true, color: kGreen),
      _copy('AI가 돕는 세 가지 일', size: mobile ? 28 : 32, bold: true),
      _Cards(
        mobile: mobile,
        gap: 24,
        children: [
          for (var i = 0; i < 3; i++)
            _stack([
              SizedBox(
                width: 64,
                height: 64,
                child: CustomPaint(painter: _FeatureIcon(i)),
              ),
              _copy(
                ['말을 글로 옮기기', '비슷한 의견 묶기', '수업 내용 요약하기'][i],
                size: 19,
                bold: true,
                color: kGreen,
              ),
              _copy(
                [
                  '학생이 말한 내용을\n글로 받아씁니다.',
                  '표현이 달라도 뜻이 비슷한 의견을\nAI가 찾아 묶습니다.',
                  '어떤 의견이 나왔는지\nAI가 요약합니다.',
                ][i],
                size: 15,
                color: _muted,
              ),
            ], gap: 16),
        ],
      ),
      _card(
        [
          _copy('마지막 확인은 선생님이', size: 15, bold: true, color: kGreen),
          _copy(
            'AI가 잘못 묶었다면 의견을 다른 묶음으로 옮기거나 묶음의 이름을 바꿀 수 있습니다.',
            size: 14,
            color: _muted,
          ),
        ],
        color: kGround,
        padding: 20,
      ),
    ], gap: 28),
  );
}

// Vector geometry retained from the approved Figma icon artwork.
class _FeatureIcon extends CustomPainter {
  final int index;
  const _FeatureIcon(this.index);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64, size.height / 64);
    final p = Paint()
      ..color = kGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void path(Path path) => canvas.drawPath(path, p);
    if (index == 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(25, 13, 14, 25),
          const Radius.circular(7),
        ),
        p,
      );
      path(
        Path()
          ..moveTo(20, 30)
          ..lineTo(20, 32)
          ..cubicTo(20, 48, 44, 48, 44, 32)
          ..lineTo(44, 30),
      );
      path(
        Path()
          ..moveTo(32, 44)
          ..lineTo(32, 51)
          ..moveTo(26, 51)
          ..lineTo(38, 51),
      );
      p.color = const Color(0xFFA5BB9B);
      path(
        Path()
          ..moveTo(13, 25)
          ..lineTo(13, 35)
          ..moveTo(51, 25)
          ..lineTo(51, 35),
      );
    } else if (index == 1) {
      path(
        Path()
          ..moveTo(13, 15)
          ..lineTo(38, 15)
          ..quadraticBezierTo(43, 15, 43, 20)
          ..lineTo(43, 33)
          ..quadraticBezierTo(43, 38, 38, 38)
          ..lineTo(24, 38)
          ..lineTo(16, 44)
          ..lineTo(16, 38)
          ..lineTo(13, 38)
          ..quadraticBezierTo(8, 38, 8, 33)
          ..lineTo(8, 20)
          ..quadraticBezierTo(8, 15, 13, 15)
          ..close(),
      );
      path(
        Path()
          ..moveTo(43, 25)
          ..lineTo(50, 25)
          ..quadraticBezierTo(55, 25, 55, 30)
          ..lineTo(55, 43)
          ..quadraticBezierTo(55, 48, 50, 48)
          ..lineTo(48, 48)
          ..lineTo(48, 54)
          ..lineTo(40, 48)
          ..lineTo(30, 48)
          ..quadraticBezierTo(25, 48, 25, 43)
          ..lineTo(25, 38)
          ..moveTo(18, 25)
          ..lineTo(33, 25)
          ..moveTo(18, 31)
          ..lineTo(27, 31),
      );
    } else {
      path(
        Path()
          ..moveTo(19, 10)
          ..lineTo(39, 10)
          ..lineTo(48, 19)
          ..lineTo(48, 53)
          ..lineTo(19, 53)
          ..close()
          ..moveTo(38, 10)
          ..lineTo(38, 21)
          ..lineTo(48, 21)
          ..moveTo(26, 29)
          ..lineTo(40, 29)
          ..moveTo(26, 36)
          ..lineTo(34, 36),
      );
      canvas.drawCircle(const Offset(43, 46), 11, Paint()..color = kYellow);
      canvas.drawCircle(const Offset(43, 46), 11, p);
      path(
        Path()
          ..moveTo(38, 46)
          ..lineTo(41, 49)
          ..lineTo(47, 42),
      );
    }
  }

  @override
  bool shouldRepaint(_FeatureIcon oldDelegate) => oldDelegate.index != index;
}

class _DifferentiationSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _SectionShell(
    background: kGround,
    builder: (mobile) => _stack([
      _copy('모아말이 가려는 방향', size: 12, bold: true, color: kGreen),
      _copy('학급회의에서 시작해,\n토론과 심포지엄으로', size: mobile ? 28 : 36, bold: true),
      _copy(
        '모아말은 교사와 나눈 수업 이야기에서 출발했습니다.\n학생의 의견을 모으는 일부터 수업 기록까지\n한곳에서 다룰 수 있으면 좋겠다는 생각이었습니다.',
        color: _muted,
      ),
      _Cards(
        mobile: mobile,
        children: [
          for (var i = 0; i < 3; i++)
            _card([
              _copy(
                i == 0 ? '현재 · 첫 단계' : '앞으로의 방향',
                size: 12,
                bold: true,
                color: kGreen,
              ),
              _copy(['학급회의', '토론 수업', '심포지엄 수업'][i], size: 22, bold: true),
              _copy(
                [
                  '의견을 모으고 함께 결정하는\n첫 단계의 기능을 만들었습니다.',
                  '서로 다른 입장과 근거를\n비교하는 수업으로 넓혀갑니다.',
                  '발표와 질문이 오가는\n수업도 돕고자 합니다.',
                ][i],
                size: 14,
                color: _muted,
              ),
            ]),
        ],
      ),
    ], gap: 28),
  );
}

class _ValidationSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _SectionShell(
    background: kCardBg,
    builder: (mobile) => _stack([
      _copy('현재의 모아말', size: 12, bold: true, color: kGreen),
      _copy('확인한 것과\n앞으로 확인할 것', size: mobile ? 28 : 32, bold: true),
      _Cards(
        mobile: mobile,
        children: [
          _card([
            _copy('기능 검증', size: 12, bold: true, color: kGreen),
            _copy('만들고 테스트했습니다', size: 19, bold: true),
            _copy(
              '안드로이드 휴대폰과 가상 기기를 연결해 교사 한 명과 학생 한 명이 의견을 주고받고 투표하는 과정을 테스트했습니다.\n\n수업 기록을 만들고 내보내는 기능도 확인했습니다.',
              size: 15,
              color: _muted,
            ),
          ], color: _softGreen),
          _card([
            _copy('현장 검증 · 예정', size: 12, bold: true, color: kGreen),
            _copy('실제 수업에서 확인하려 합니다', size: 19, bold: true),
            _copy(
              '여러 학생이 함께 써도 원활하게 작동하는지, 교사의 정리 시간이 줄어드는지, 다음 수업에도 쓰고 싶은 도구인지는 앞으로 확인할 과제입니다.',
              size: 15,
              color: _muted,
            ),
          ], color: kGround),
        ],
      ),
      _copy(
        '교사 인터뷰 1건과 TALIS 2024, 교육부 자료를 참고했습니다.\n참고 자료는 수업 환경을 이해하기 위한 것으로, 모아말의 효과를 측정한 결과는 아닙니다.',
        size: 12,
        color: _muted,
      ),
    ], gap: 28),
  );
}

class _FinalCtaSection extends StatelessWidget {
  final bool isStarting;
  final VoidCallback onStart;
  const _FinalCtaSection({required this.isStarting, required this.onStart});
  @override
  Widget build(BuildContext context) => _SectionShell(
    background: kGreen,
    builder: (mobile) => _stack([
      _copy('직접 살펴보세요', size: 12, bold: true, color: kYellow),
      _copy(
        '아이들의 의견이\n수업 기록으로 남기까지',
        size: mobile ? 29 : 38,
        bold: true,
        color: kCardBg,
      ),
      _copy(
        '예시 학생 5명과 의견 8개가 준비돼 있습니다.\n의견을 살펴보고, 후보를 승인하고,\n학생 입장에서 한 표를 넣어보세요.',
        color: kCardBg,
      ),
      _CtaButton(isStarting: isStarting, onTap: onStart),
      _copy('체험용 예시 데이터입니다.\n실제 학생이 접속한 수업은 아닙니다.', size: 13, color: kCardBg),
    ], gap: 24),
  );
}

class _FooterSection extends StatelessWidget {
  final VoidCallback onAppLink;
  const _FooterSection({required this.onAppLink});
  @override
  Widget build(BuildContext context) => _SectionShell(
    background: kGround,
    builder: (_) => _stack([
      _copy('모아말', size: 20, bold: true, color: kGreen),
      TextButton(
        onPressed: onAppLink,
        child: const Text('선생님 또는 학생으로 바로 들어가기 →'),
      ),
    ], gap: 12),
  );
}

class _CtaButton extends StatelessWidget {
  final bool isStarting;
  final VoidCallback onTap;
  const _CtaButton({required this.isStarting, required this.onTap});
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: isStarting ? null : onTap,
    style: FilledButton.styleFrom(
      backgroundColor: kYellow,
      foregroundColor: kInk,
      disabledBackgroundColor: kYellow,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      shape: const StadiumBorder(),
    ),
    child: isStarting
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: kInk),
          )
        : const Text(
            '학급회의 체험하기 →',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
  );
}
