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

/// 섹션 공통 — 가운데 정렬 + 최대 폭 제한(넓은 데스크톱 화면에서도 안 퍼지게).
class _SectionShell extends StatelessWidget {
  final Widget child;
  final Color background;
  final EdgeInsets padding;

  const _SectionShell({
    required this.child,
    required this.background,
    this.padding = const EdgeInsets.fromLTRB(24, 56, 24, 56),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

// ── 1. Hero — 10초 안에 이해 ─────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final bool isStarting;
  final VoidCallback onStart;

  const _HeroSection({required this.isStarting, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      background: kGreen,
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.02 * 28,
              ),
              children: [
                TextSpan(
                  text: '모아',
                  style: TextStyle(color: Colors.white),
                ),
                TextSpan(
                  text: '말',
                  style: TextStyle(color: kYellow),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '학생의 생각을, 수업의 흐름으로',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '학생의 이야기를 듣는 동안에도\n'
            '교사는 의견을 정리하고, 논의를 이끌고,\n'
            '수업 내용을 기록해야 합니다.\n'
            '모아말은 이 일을 함께 돕는 수업 도구입니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.7,
            ),
          ),
          const SizedBox(height: 32),
          _CtaButton(isStarting: isStarting, onTap: onStart, big: true),
          const SizedBox(height: 22),
          Text(
            '지금은 학급회의로 시작합니다.\n'
            '토론·심포지엄 수업까지 넓혀가려 합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: kYellow.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. 그래서 뭘 하는데? ───────────────────────────────────────────────────

class _FlowSection extends StatelessWidget {
  const _FlowSection();

  static const _steps = ['학생 의견', 'AI 정리', '교사 검토', '투표', '수업 기록'];

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      background: kGround,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '의견을 모으고, 함께 살펴보고, 기록합니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: kInk,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < _steps.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: kInk.withValues(alpha: 0.35),
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: kBorder),
                  ),
                  child: Text(
                    _steps[i],
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: kInk,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            '학생이 말하면 글로 옮기고, 비슷한 의견을 묶습니다.\n'
            '교사는 묶인 의견을 살펴보고 수정한 뒤\n'
            '투표에 올릴 후보를 승인합니다.\n'
            '학생들의 의견과 투표 결과는 수업 기록으로 남깁니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, color: kInk, height: 1.7),
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            decoration: BoxDecoration(
              color: kGreen.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kGreen.withValues(alpha: 0.18)),
            ),
            child: const Text(
              '어떤 의견을 함께 묶을지는 교사가 확인합니다.\n'
              '학생들이 처음에 한 말도 다시 볼 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: kGreen,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 3. AI 활용 방식 ────────────────────────────────────────────────────────

class _AiSection extends StatelessWidget {
  const _AiSection();

  static const _items = [
    (Icons.mic, '말을 글로 옮기기', '학생이 말한 내용을 음성인식으로 받아씁니다.'),
    (Icons.hub_outlined, '비슷한 의견 묶기', '표현이 달라도 뜻이 비슷한 의견을 AI가 찾아 묶습니다.'),
    (Icons.summarize_outlined, '수업 내용 요약하기', '어떤 의견이 나왔는지 AI가 요약합니다.'),
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      background: kCardBg,
      child: Column(
        children: [
          const Text(
            'AI가 돕는 세 가지 일',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: kInk,
            ),
          ),
          const SizedBox(height: 26),
          for (final item in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: kYellow.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.$1, color: kInk, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$2,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.$3,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: kInk.withValues(alpha: 0.65),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'AI가 잘못 묶었다면 의견을 다른 묶음으로 옮기거나\n'
            '묶음의 이름을 바꿀 수 있습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: kInk.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 4. 차별점 ─────────────────────────────────────────────────────────────

class _DifferentiationSection extends StatelessWidget {
  const _DifferentiationSection();

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      background: kGround,
      child: Column(
        children: [
          const Text(
            '학급회의에서 시작해, 토론과 심포지엄으로',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: kInk,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '모아말은 교사와 나눈 수업 이야기에서 출발했습니다.\n'
            '학생의 의견을 모으는 일부터 수업 기록까지\n'
            '한곳에서 다룰 수 있으면 좋겠다는 생각이었습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, color: kInk, height: 1.7),
          ),
          const SizedBox(height: 14),
          Text(
            '첫 단계로 학급회의에 필요한 기능을 만들었습니다.\n'
            '앞으로는 서로 다른 입장과 근거를 비교하는 토론,\n'
            '발표와 질문이 오가는 심포지엄 수업도 돕고자 합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: kInk.withValues(alpha: 0.5),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 5. 검증 상태 ──────────────────────────────────────────────────────────

class _ValidationSection extends StatelessWidget {
  const _ValidationSection();

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      background: kCardBg,
      child: Column(
        children: [
          const Text(
            '지금까지 확인한 것과 앞으로 확인할 것',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: kInk,
            ),
          ),
          const SizedBox(height: 22),
          _ValidationBlock(
            icon: Icons.check_circle,
            iconColor: kGreen,
            label: '만들고 테스트했습니다',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '의견 보내기 → AI 정리 → 교사 승인 → 투표 → 수업 기록',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kInk.withValues(alpha: 0.7),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '안드로이드 휴대폰과 가상 기기를 연결해, 교사 한 명과 학생 한 명이 '
                  '의견을 주고받고 투표하는 과정을 테스트했습니다. '
                  '수업 기록을 만들고 내보내는 기능도 확인했습니다.',
                  style: TextStyle(fontSize: 13.5, color: kInk, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _ValidationBlock(
            icon: Icons.hourglass_bottom,
            iconColor: kInk.withValues(alpha: 0.4),
            label: '실제 수업에서 확인하려 합니다',
            child: const Text(
              '여러 학생이 함께 써도 원활하게 작동하는지, '
              '교사의 정리 시간이 줄어드는지, '
              '다음 수업에도 쓰고 싶은 도구인지는 앞으로 확인할 과제입니다.',
              style: TextStyle(fontSize: 13.5, color: kInk, height: 1.6),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            '교사 인터뷰 1건과 TALIS 2024, 교육부 자료를 참고했습니다.\n'
            '참고 자료는 수업 환경을 이해하기 위한 것으로,\n'
            '모아말의 효과를 측정한 결과는 아닙니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: kInk.withValues(alpha: 0.4),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidationBlock extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget child;

  const _ValidationBlock({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: kInk,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.only(left: 26), child: child),
      ],
    );
  }
}

// ── 6. 최종 CTA ───────────────────────────────────────────────────────────

class _FinalCtaSection extends StatelessWidget {
  final bool isStarting;
  final VoidCallback onStart;

  const _FinalCtaSection({required this.isStarting, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      background: kGreen,
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 64),
      child: Column(
        children: [
          const Text(
            '예시 의견으로 직접 살펴보세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '예시 학생 5명과 의견 8개가 준비돼 있습니다.\n'
            '의견을 살펴보고, 후보를 승인하고, 수업 요약을 만들어보세요.\n'
            '실제 학생이 접속한 수업은 아닙니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 24),
          _CtaButton(isStarting: isStarting, onTap: onStart, big: true),
        ],
      ),
    );
  }
}

class _FooterSection extends StatelessWidget {
  final VoidCallback onAppLink;

  const _FooterSection({required this.onAppLink});

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      background: kGround,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Center(
        child: GestureDetector(
          onTap: onAppLink,
          child: Text(
            '선생님 또는 학생으로 바로 들어가기',
            style: TextStyle(
              fontSize: 12.5,
              color: kInk.withValues(alpha: 0.4),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    );
  }
}

// ── 공용 CTA 버튼 ────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final bool isStarting;
  final VoidCallback onTap;
  final bool big;

  const _CtaButton({
    required this.isStarting,
    required this.onTap,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isStarting ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: big ? 17 : 14,
          horizontal: big ? 36 : 26,
        ),
        decoration: BoxDecoration(
          color: kYellow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: isStarting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: kInk),
              )
            : Text(
                '학급회의 체험하기',
                style: TextStyle(
                  fontSize: big ? 16.5 : 15,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                ),
              ),
      ),
    );
  }
}
