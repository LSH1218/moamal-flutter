import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/idea.dart';
import '../../models/participant.dart';
import '../../models/session_state.dart';
import '../../repositories/firebase_moamal_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../teacher/sign_in_screen.dart';
import '../teacher/teacher_home_screen.dart';
import '../student/join_screen.dart';

/// 해커톤 심사용 데모 시드 의견 — "우리 반에서 바꾸고 싶은 것은?" 학급회의 시나리오.
const _demoTitle = '우리 반에서 바꾸고 싶은 것은 무엇인가요?';

/// (번호, 이름) — 참여자 목록과 발언자 표시(speaker)를 동시에 채운다.
/// authorUid는 보안 규칙상 실제 로그인 사용자(교사)로 고정되지만, speaker는
/// 그냥 표시용 문자열이라 자유롭게 학생별로 다르게 줄 수 있다.
const _demoStudents = [
  (1, '김민서'),
  (2, '이도윤'),
  (3, '박서연'),
  (4, '최지훈'),
  (5, '정하은'),
];

/// 시드 의견 — 위 학생 순서를 순환하며 speaker로 배정된다.
const _demoIdeas = [
  '쉬는 시간을 늘렸으면 좋겠어요.',
  '쉬는 시간이 너무 짧아요.',
  '급식 메뉴가 다양했으면 좋겠어요.',
  '교실에 책을 더 많이 놔주세요.',
  '체육시간을 늘려주세요.',
  '쉬는 시간을 5분 더 주세요.',
  '급식에 디저트가 있었으면 해요.',
  '독서 시간을 따로 만들어주세요.',
];

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  int _tapCount = 0;
  Timer? _tapTimer;

  void _onLogoTap() {
    _tapTimer?.cancel();
    _tapCount++;
    if (_tapCount >= 3) {
      _tapCount = 0;
      _showSupervisorPad();
    } else {
      _tapTimer = Timer(const Duration(milliseconds: 800), () {
        _tapCount = 0;
      });
    }
  }

  Future<void> _showSupervisorPad() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _PinDialog(),
    );
    if (ok == true && mounted) {
      final auth = context.read<AuthService>();
      await auth.signInAnonymously();
      if (!mounted) return;

      final mode = await _showSessionModeDialog(context);
      if (!mounted || mode == null) return;

      if (mode == 'resume') {
        final code = await _showCodeInputDialog(context);
        if (!mounted || code == null || code.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeacherHomeScreen(existingCode: code.toUpperCase()),
          ),
        );
      } else {
        final title = await _showTitleDialog(context);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeacherHomeScreen(initialTitle: title),
          ),
        );
      }
    }
  }

  Future<String?> _showSessionModeDialog(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: dialogInsetH(ctx),
          vertical: 24,
        ),
        title: const Text('세션 선택'),
        // 좁은 폭에서 actions 가로 배치가 넘쳐 라벨이 잘렸다 → 전체 폭 세로 버튼
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('새 수업을 시작하거나 기존 세션 코드로 진입할 수 있어요.'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'new'),
              child: const Text('새 세션 시작'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'resume'),
              child: const Text('기존 세션 재개'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showCodeInputDialog(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        insetPadding: EdgeInsets.symmetric(
          horizontal: dialogInsetH(ctx),
          vertical: 24,
        ),
        title: const Text('세션 코드 입력'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: '예) JO1F8Z'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('진입'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showTitleDialog(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        insetPadding: EdgeInsets.symmetric(
          horizontal: dialogInsetH(ctx),
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

  bool _isStartingDemo = false;

  /// 심사위원용 데모 진입 — PIN·Google 로그인 없이 익명 로그인 + 새 세션 +
  /// 시드 의견으로 즉시 시작한다. 웹 전용(kIsWeb)이며 모바일 앱 흐름은
  /// 그대로 둔다.
  Future<void> _startJudgeDemo(BuildContext context) async {
    if (_isStartingDemo) return;
    setState(() => _isStartingDemo = true);
    try {
      final auth = context.read<AuthService>();
      final repo = context.read<FirebaseMoamalRepository>();
      await auth.signInAnonymously();
      if (!context.mounted) return;

      final session = SessionState.initial().copyWith(
        title: _demoTitle,
        ownerUid: auth.currentUid,
      );
      await repo.publishSession(session);

      // 참가자 목록 — 세션 소유자(교사)는 다른 uid로도 participants 문서를
      // 만들 수 있다(firestore.rules: isOwner(sessionCode)). "참여 0명"으로
      // 보이지 않도록 데모용 학생 5명을 실제 참가자로 등록한다.
      for (var i = 0; i < _demoStudents.length; i++) {
        final (number, name) = _demoStudents[i];
        await repo.joinSession(
          session.sessionCode,
          Participant(
            uid: 'demo-student-$i',
            number: number,
            name: name,
            joinedAt: DateTime.now(),
          ),
        );
      }

      // 의견 — authorUid는 보안 규칙상 실제 로그인한 교사 uid로 고정되지만,
      // speaker는 표시용 문자열이라 학생 이름을 순환 배정해 발언자가
      // 다양하게 보이도록 한다(원문 목록·리포트 인용에 그대로 쓰인다).
      for (var i = 0; i < _demoIdeas.length; i++) {
        final (number, name) = _demoStudents[i % _demoStudents.length];
        await repo.submitIdea(
          session.sessionCode,
          Idea(
            id: const Uuid().v4(),
            speaker: '$number번 $name',
            text: _demoIdeas[i],
            source: 'text',
          ),
        );
      }

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TeacherHomeScreen(existingCode: session.sessionCode),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데모 시작 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingDemo = false);
    }
  }

  void _signInAsTeacher(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
    );
  }

  void _joinAsStudent(BuildContext context, {bool autoScan = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JoinScreen(autoScan: autoScan)),
    );
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    final teacherPanel = _TeacherPanel(
      onLogoTap: _onLogoTap,
      onStart: () => _signInAsTeacher(context),
      onJudgeDemo: kIsWeb ? () => _startJudgeDemo(context) : null,
      isDemoStarting: _isStartingDemo,
      isTablet: isTablet,
    );
    final studentPanel = _StudentPanel(
      onCodeEntry: () => _joinAsStudent(context),
      onQr: () => _joinAsStudent(context, autoScan: true),
      isTablet: isTablet,
    );

    return Scaffold(
      body: isTablet
          ? Row(children: [
              Expanded(flex: 55, child: teacherPanel),
              Expanded(flex: 45, child: studentPanel),
            ])
          : Column(children: [
              Expanded(flex: 55, child: teacherPanel),
              Expanded(flex: 45, child: studentPanel),
            ]),
    );
  }
}

// ── 교사 영역 ─────────────────────────────────────────────────────────────
class _TeacherPanel extends StatelessWidget {
  final VoidCallback onLogoTap;
  final VoidCallback onStart;
  final VoidCallback? onJudgeDemo;
  final bool isDemoStarting;
  final bool isTablet;

  const _TeacherPanel({
    required this.onLogoTap,
    required this.onStart,
    required this.onJudgeDemo,
    required this.isDemoStarting,
    required this.isTablet,
  });

  static const _sessions = [
    _Session('3학년 2반 · 학급회의', '오늘 · 23분 · 학생 28명'),
    _Session('3학년 2반 · 토론 수업', '오늘 · 41분 · 학생 26명'),
    _Session('2학년 1반 · 심포지엄', '2일 전 · 38분 · 학생 30명'),
  ];

  @override
  Widget build(BuildContext context) {
    final displaySize = isTablet ? 82.0 : 56.0;

    return Container(
      color: kGreen,
      child: SafeArea(
        bottom: false,
        right: isTablet ? false : true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 데모 버튼(웹 전용)이 있으면 중앙 콘텐츠가 더 길어지므로
            // "최근 수업"과 겹치지 않도록 기준선을 더 높게 잡는다.
            final showRecent =
                constraints.maxHeight >= (onJudgeDemo != null ? 400 : 360);
            return Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 로고 행
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: onLogoTap,
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.03 * 22,
                            ),
                            children: [
                              const TextSpan(
                                text: '모아',
                                style: TextStyle(color: Colors.white),
                              ),
                              const TextSpan(
                                text: '말',
                                style: TextStyle(color: kYellow),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '수업을 기록하고, 한눈에',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                  // 중앙 콘텐츠
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '교사',
                          style: TextStyle(
                            fontSize: displaySize,
                            fontWeight: FontWeight.w900,
                            color: kYellow,
                            letterSpacing: -0.05 * displaySize,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '수업을 열고 학생 의견을\n실시간으로 모읍니다',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.75),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: onStart,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 15,
                              horizontal: 24,
                            ),
                            decoration: BoxDecoration(
                              color: kYellow,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.mic, color: kInk, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  '수업 시작',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: kInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (onJudgeDemo != null) ...[
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: isDemoStarting ? null : onJudgeDemo,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isDemoStarting)
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: kYellow,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.play_circle_outline,
                                    color: kYellow,
                                    size: 16,
                                  ),
                                const SizedBox(width: 6),
                                Text(
                                  isDemoStarting ? '데모 준비 중…' : '심사위원이신가요? 데모 바로 시작',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: kYellow.withValues(alpha: 0.9),
                                    decoration: TextDecoration.underline,
                                    decorationColor:
                                        kYellow.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 최근 수업 가로 스크롤 (높이 360px 이상일 때만 표시)
                  if (showRecent)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '최근 수업',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 84,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _sessions.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) => _RecentCard(session: _sessions[i]),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Session {
  final String title;
  final String sub;
  const _Session(this.title, this.sub);
}

class _RecentCard extends StatelessWidget {
  final _Session session;
  const _RecentCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 152,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        border: Border.all(
          color: kYellow.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Text(
              session.sub,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.55),
              ),
              maxLines: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '요약 보기 ↗',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kYellow,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 학생 영역 ─────────────────────────────────────────────────────────────
class _StudentPanel extends StatelessWidget {
  final VoidCallback onCodeEntry;
  final VoidCallback onQr;
  final bool isTablet;

  const _StudentPanel({
    required this.onCodeEntry,
    required this.onQr,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final displaySize = isTablet ? 72.0 : 52.0;
    final btnPadding = isTablet ? 22.0 : 18.0;

    return Container(
      color: kGround,
      child: SafeArea(
        top: false,
        left: isTablet ? false : true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '학생',
                style: TextStyle(
                  fontSize: displaySize,
                  fontWeight: FontWeight.w900,
                  color: kGreen,
                  letterSpacing: -0.05 * displaySize,
                  height: 1,
                ),
              ),
              const SizedBox(height: 14),
              // 코드 6칸 미리보기
              // 간격은 Expanded 안쪽 Padding이 아니라 형제 SizedBox로 줘야 한다 —
              // 안쪽 Padding 방식은 패딩이 없는 첫 칸만 더 넓게 그려진다.
              Row(
                children: [
                  for (int i = 0; i < 6; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1 / 1.15,
                        child: Container(
                          decoration: BoxDecoration(
                            color: kCardBg,
                            border: Border.all(
                              color: kBorderDark,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              // 액션 버튼 행
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onCodeEntry,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: btnPadding),
                        decoration: BoxDecoration(
                          color: kGreen,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '코드 입력',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: onQr,
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        color: kCardBg,
                        border: Border.all(color: kGreen, width: 1.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner,
                        color: kGreen,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '선생님이 보여준 코드나 QR로 들어가요',
                style: TextStyle(
                  fontSize: 12,
                  color: kInk.withValues(alpha: 0.45),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 슈퍼바이저 PIN 키패드 (기존 유지) ────────────────────────────────────
class _PinDialog extends StatefulWidget {
  const _PinDialog();

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  static const _correctPin = '1218';
  String _input = '';
  bool _error = false;

  void _press(String digit) {
    if (_input.length >= 4) return;
    setState(() {
      _input += digit;
      _error = false;
    });
    if (_input.length == 4) {
      if (_input == _correctPin) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _error = true;
          _input = '';
        });
      }
    }
  }

  void _delete() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: dialogInsetH(context, tabletFactor: 0.3),
        vertical: 24,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '슈퍼바이저',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _input.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _error
                        ? Colors.red
                        : filled
                            ? kGreen
                            : Colors.black12,
                  ),
                );
              }),
            ),
            if (_error) ...[
              const SizedBox(height: 8),
              const Text('잘못된 코드입니다',
                  style: TextStyle(fontSize: 12, color: Colors.red)),
            ],
            const SizedBox(height: 24),
            _buildPad(),
          ],
        ),
      ),
    );
  }

  Widget _buildPad() {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    const gap = 3.0;
    return LayoutBuilder(
      builder: (context, c) {
        // 고정 60dp는 320dp 기기에서 6dp 초과했다 → 폭에서 역산하고 44dp(터치 최소)까지만 축소
        final keyW =
            (c.maxWidth / 3 - gap * 2 - 0.5).clamp(44.0, 60.0).toDouble();
        final keyH = (keyW * 0.84).clamp(44.0, 50.0).toDouble();
        return Column(
          children: rows.map((row) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((label) {
                if (label.isEmpty) {
                  return SizedBox(width: keyW + gap * 2, height: keyH);
                }
                return GestureDetector(
                  onTap: () => label == '⌫' ? _delete() : _press(label),
                  child: Container(
                    width: keyW,
                    height: keyH,
                    margin: const EdgeInsets.all(gap),
                    decoration: BoxDecoration(
                      color: label == '⌫'
                          ? Colors.transparent
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: label == '⌫' ? 18 : 20,
                        fontWeight: FontWeight.w500,
                        color: kInk,
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          }).toList(),
        );
      },
    );
  }
}
