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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TeacherHomeScreen(existingCode: code.toUpperCase()),
          ),
        );
      } else {
        final title = await _showTitleDialog(context);
        if (!mounted) return;
        Navigator.pushReplacement(
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
        title: const Text('세션 선택'),
        content: const Text('새 수업을 시작하거나 기존 세션 코드로 진입할 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'resume'),
            child: const Text('기존 세션 재개'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'new'),
            child: const Text('새 세션 시작'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showCodeInputDialog(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
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

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = context.isCompact;

    return Scaffold(
      backgroundColor: kGround,
      body: Column(
        children: [
          GestureDetector(
            onTap: _onLogoTap,
            child: const _GreenHeader(),
          ),
          Expanded(
            child: isCompact
                ? _CompactBody(
                    onTeacher: () => _signInAsTeacher(context),
                    onStudent: () => _joinAsStudent(context),
                  )
                : _MediumBody(
                    onTeacher: () => _signInAsTeacher(context),
                    onStudent: () => _joinAsStudent(context),
                  ),
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

  Future<String?> _showTitleDialog(BuildContext context) {
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

  void _joinAsStudent(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const JoinScreen()),
    );
  }
}

// ── 슈퍼바이저 PIN 키패드 ─────────────────────────────────────────────────
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
        horizontal: context.isTablet
            ? MediaQuery.sizeOf(context).width * 0.3
            : 40.0,
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
    return Column(
      children: rows.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((label) {
            if (label.isEmpty) return const SizedBox(width: 60, height: 50);
            return GestureDetector(
              onTap: () => label == '⌫' ? _delete() : _press(label),
              child: Container(
                width: 60,
                height: 50,
                margin: const EdgeInsets.all(3),
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
  }
}

// ── Green 헤더 ────────────────────────────────────────────────────────────
class _GreenHeader extends StatelessWidget {
  const _GreenHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kGreen,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                      children: [
                        TextSpan(
                            text: '모아', style: TextStyle(color: Colors.white)),
                        TextSpan(
                            text: '말', style: TextStyle(color: kYellow)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '수업을 기록하고, 한눈에',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Compact: 역할 2-col + 최근 수업 세로 ─────────────────────────────────
class _CompactBody extends StatelessWidget {
  final VoidCallback onTeacher;
  final VoidCallback onStudent;

  const _CompactBody({required this.onTeacher, required this.onStudent});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _RoleCard(
                  label: '교사',
                  sub: '수업 시작',
                  icon: Icons.mic_none,
                  isPrimary: true,
                  onTap: onTeacher,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RoleCard(
                  label: '학생',
                  sub: '참여 입장',
                  icon: Icons.back_hand_outlined,
                  isPrimary: false,
                  onTap: onStudent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            '최근 수업',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: kInk),
          ),
          const SizedBox(height: 10),
          const _RecentSessionList(),
        ],
      ),
    );
  }
}

// ── Medium: 역할 세로(왼쪽) + 최근 수업(오른쪽) ──────────────────────────
class _MediumBody extends StatelessWidget {
  final VoidCallback onTeacher;
  final VoidCallback onStudent;

  const _MediumBody({required this.onTeacher, required this.onStudent});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: w * 0.45,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(28, 28, 16, 28 + bottomPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '역할 선택',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black38),
                ),
                const SizedBox(height: 14),
                _RoleCard(
                  label: '교사로 시작',
                  sub: '수업 시작 & 요약 관리',
                  icon: Icons.mic_none,
                  isPrimary: true,
                  onTap: onTeacher,
                ),
                const SizedBox(height: 12),
                _RoleCard(
                  label: '학생으로 참여',
                  sub: '코드 입력 후 발표·투표',
                  icon: Icons.back_hand_outlined,
                  isPrimary: false,
                  onTap: onStudent,
                ),
              ],
            ),
          ),
        ),
        Container(width: 1, color: const Color(0xFFE0DDD6)),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 28, 24, 28 + bottomPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '최근 수업',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black38),
                ),
                SizedBox(height: 14),
                _RecentSessionList(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── 역할 카드 ─────────────────────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  final String label;
  final String sub;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _RoleCard({
    required this.label,
    required this.sub,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isPrimary ? kGreen : Colors.white;
    final fg = isPrimary ? Colors.white : kInk;
    final subFg = isPrimary ? Colors.white70 : Colors.black38;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: isPrimary
              ? null
              : Border.all(color: const Color(0xFFE0DDD6), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: fg),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: fg),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Text(
              sub,
              style: TextStyle(fontSize: 12, color: subFg),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 최근 수업 목록 ────────────────────────────────────────────────────────
class _RecentSessionList extends StatelessWidget {
  const _RecentSessionList();

  static const _items = [
    _SessionMeta('3학년 2반 · 수학', '오늘 · 23분 · 학생 28명'),
    _SessionMeta('3학년 2반 · 국어', '오늘 · 41분 · 학생 26명'),
    _SessionMeta('2학년 1반 · 과학', '2일 전 · 38분 · 학생 30명'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RecentSessionItem(meta: item),
              ))
          .toList(),
    );
  }
}

class _SessionMeta {
  final String title;
  final String sub;
  const _SessionMeta(this.title, this.sub);
}

class _RecentSessionItem extends StatelessWidget {
  final _SessionMeta meta;

  const _RecentSessionItem({required this.meta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E4DC)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: kInk,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  meta.sub,
                  style: const TextStyle(fontSize: 12, color: Colors.black38),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kYellow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  '요약',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: kInk,
                  ),
                ),
                SizedBox(width: 3),
                Icon(Icons.north_east, size: 12, color: kInk),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
