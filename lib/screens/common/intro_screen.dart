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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데모 시작 실패: $e')),
        );
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
                TextSpan(text: '모아', style: TextStyle(color: Colors.white)),
                TextSpan(text: '말', style: TextStyle(color: kYellow)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '학생의 말을, 수업의 결정으로.',
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
            '학급회의에서 학생 의견은 나옵니다.\n'
            '하지만 여러 의견을 정리하고, 결정으로 연결하고,\n'
            '기록으로 남기는 과정은 여전히 교사가 직접 처리해야 합니다.',
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
            '학생 발화 → AI 구조화 → 교사 검토 → 투표 → 기록',
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

  static const _steps = ['말하기', 'AI 구조화', '교사 검토', '투표', '기록'];

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      background: kGround,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '의견을 받는 것에서 끝나지 않습니다',
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
            '학생의 발화를 실시간 텍스트로 바꾸고,\n'
            '비슷한 의견을 하나의 구조로 정리합니다.\n'
            '교사가 직접 검토·수정·승인한 뒤\n'
            '투표와 기록까지 하나의 흐름으로 이어집니다.',
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
              'AI는 결정을 대신하지 않습니다.\nAI는 정리하고, 교사가 판단합니다.',
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
    (
      Icons.mic,
      'STT',
      '학생 발화를 텍스트로 변환',
    ),
    (
      Icons.hub_outlined,
      'LLM 구조화',
      '의미가 비슷한 의견을 그룹화',
    ),
    (
      Icons.summarize_outlined,
      '리포트 생성',
      '수업 종료 후 논의 흐름을 정리',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      background: kCardBg,
      child: Column(
        children: [
          const Text(
            'AI는 이렇게 사용합니다',
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
            '잘못 묶인 의견은 교사가 다시 옮길 수 있고, 원문은 항상 확인할 수 있습니다.\n'
            '그룹 확정은 교사 검토와 승인을 거쳐야 합니다.',
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
            '기능이 아니라, 흐름입니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: kInk,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '의견 수집, AI 구조화, 교사 검토, 투표, 참여 기록을\n'
            '하나의 학급회의 세션 안에서 이어지게 설계했습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, color: kInk, height: 1.7),
          ),
          const SizedBox(height: 14),
          Text(
            '모아말은 개별 기능의 추가보다\n'
            '학생의 의견이 수업의 결정과 기록으로 이어지는 과정에 초점을 둡니다.',
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
            '현재 검증 상태',
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
            label: '구현·검증 완료',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '학생 의견 제출 → AI 구조화 → 교사 승인 → 투표 → 결과 기록',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kInk.withValues(alpha: 0.7),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '내부 QA와 실기기 테스트로 핵심 흐름을 확인했습니다.',
                  style: TextStyle(fontSize: 13.5, color: kInk, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _ValidationBlock(
            icon: Icons.hourglass_bottom,
            iconColor: kInk.withValues(alpha: 0.4),
            label: '다음 검증',
            child: const Text(
              '실제 교실 파일럿을 통해\n'
              '· 교사의 업무시간이 실제로 감소하는지\n'
              '· 다시 사용할 만큼 유용한지\n'
              '를 확인할 예정입니다.',
              style: TextStyle(fontSize: 13.5, color: kInk, height: 1.6),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            '문제 정의는 TALIS 2024, 교육부 자료, 교사 인터뷰를 참고했습니다.\n'
            '통계는 참여형 수업의 배경 맥락이며, 의견 정리 부담을 직접\n'
            '측정한 수치는 아닙니다.',
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
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: child,
        ),
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
            '지금 바로 확인해보세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '2~3분이면 모아말의 전체 흐름을 직접 볼 수 있습니다.',
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
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: kInk,
                ),
              )
            : Text(
                '데모 체험하기',
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
