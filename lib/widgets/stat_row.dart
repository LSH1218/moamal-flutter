import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 교사 홈 통계 3칸.
/// 참여/발언 = kCardBg + kGreen 숫자, AI 그룹 = kGreen 면 + kYellow 숫자
class StatRow extends StatelessWidget {
  final int participantCount;
  final int ideaCount;
  final int groupCount;

  const StatRow({
    super.key,
    required this.participantCount,
    required this.ideaCount,
    required this.groupCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatTile(label: '참여', value: participantCount, isDark: false),
        const SizedBox(width: 8),
        _StatTile(label: '발언', value: ideaCount, isDark: false),
        const SizedBox(width: 8),
        _StatTile(label: 'AI 그룹', value: groupCount, isDark: true),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  final bool isDark;

  const _StatTile({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? kGreen : kCardBg;
    final numColor = isDark ? kYellow : kGreen;
    final labelColor = isDark ? Colors.white70 : kInk.withValues(alpha: 0.5);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: numColor,
                letterSpacing: -0.03 * 22,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
