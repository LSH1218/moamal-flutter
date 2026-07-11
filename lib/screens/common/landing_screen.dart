import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../teacher/teacher_home_screen.dart';
import '../student/join_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: kGround,
      body: Column(
        children: [
          const _GreenHeader(),
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

  Future<void> _signInAsTeacher(BuildContext context) async {
    final auth = context.read<AuthService>();
    try {
      await auth.signInWithGoogle();
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TeacherHomeScreen()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 실패: $e')),
        );
      }
    }
  }

  void _joinAsStudent(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const JoinScreen()),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: w * 0.45,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 28, 16, 28),
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
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
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
