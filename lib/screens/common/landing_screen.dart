import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../teacher/sign_in_screen.dart';
import '../teacher/teacher_home_screen.dart';
import '../student/join_screen.dart';

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
  final bool isTablet;

  const _TeacherPanel({
    required this.onLogoTap,
    required this.onStart,
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
            final showRecent = constraints.maxHeight >= 360;
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
              Row(
                children: List.generate(6, (i) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i > 0 ? 6 : 0),
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
                  );
                }),
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
