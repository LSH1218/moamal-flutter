import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 교사 홈 하단 독.
/// kGreen 배경, 5개 버튼 인라인: [공유][정리][마이크][학생][수업기록]
class TeacherDock extends StatelessWidget {
  final Widget micButton;
  final int unclassifiedCount;
  final String micHint;
  final VoidCallback onShare;
  final VoidCallback onSummary;
  final VoidCallback onStudents;
  final VoidCallback onEnd;

  const TeacherDock({
    super.key,
    required this.micButton,
    required this.unclassifiedCount,
    required this.micHint,
    required this.onShare,
    required this.onSummary,
    required this.onStudents,
    required this.onEnd,
  });

  static const double _dockPaddingBottom = 20;
  static const double _dockPaddingTop = 14;
  static const double _slotSize = 54;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return _DockBar(
      bottomInset: bottomInset,
      micButton: micButton,
      unclassifiedCount: unclassifiedCount,
      micHint: micHint,
      onShare: onShare,
      onSummary: onSummary,
      onStudents: onStudents,
      onEnd: onEnd,
    );
  }
}

class _DockBar extends StatelessWidget {
  final double bottomInset;
  final Widget micButton;
  final int unclassifiedCount;
  final String micHint;
  final VoidCallback onShare;
  final VoidCallback onSummary;
  final VoidCallback onStudents;
  final VoidCallback onEnd;

  const _DockBar({
    required this.bottomInset,
    required this.micButton,
    required this.unclassifiedCount,
    required this.micHint,
    required this.onShare,
    required this.onSummary,
    required this.onStudents,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kGreen,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              TeacherDock._dockPaddingTop,
              12,
              0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _DockSlot(
                  icon: Icons.qr_code_2,
                  label: '공유',
                  onTap: onShare,
                ),
                _DockSlotBadge(
                  icon: Icons.format_list_bulleted,
                  label: '정리',
                  badgeCount: unclassifiedCount,
                  onTap: onSummary,
                ),
                micButton,
                _DockSlot(
                  icon: Icons.people_outline,
                  label: '학생',
                  onTap: onStudents,
                ),
                // 실제 세션 종료는 뒤로가기 → 다이얼로그 경로다. 이 버튼은 리포트 화면으로
                // 이동만 한다(§16) — 라벨·아이콘·색을 '종료'가 아니라 '수업기록'에 맞춘다.
                _DockSlot(
                  icon: Icons.assignment_outlined,
                  label: '수업기록',
                  onTap: onEnd,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            micHint,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: TeacherDock._dockPaddingBottom + bottomInset),
        ],
      ),
    );
  }
}

class _DockSlot extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DockSlot({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: TeacherDock._slotSize,
        height: TeacherDock._slotSize,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockSlotBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badgeCount;
  final VoidCallback onTap;

  const _DockSlotBadge({
    required this.icon,
    required this.label,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: TeacherDock._slotSize,
        height: TeacherDock._slotSize,
        child: Stack(
          children: [
            Container(
              width: TeacherDock._slotSize,
              height: TeacherDock._slotSize,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    color: kRed,
                    shape: BoxShape.circle,
                    border: Border.all(color: kGreen, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
