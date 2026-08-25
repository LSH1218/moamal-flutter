import 'package:flutter/material.dart';
import '../models/group.dart';
import '../theme/app_theme.dart';

/// 교사 홈 요약 탭 그룹 카드.
/// kCardBg + 1px kBorder + left 4px kYellow, radius 14.
class GroupCard extends StatelessWidget {
  final Group group;
  final int ideaCount;

  const GroupCard({
    super.key,
    required this.group,
    required this.ideaCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: const BorderSide(color: kYellow, width: 4),
          top: BorderSide(color: kBorder),
          right: BorderSide(color: kBorder),
          bottom: BorderSide(color: kBorder),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    group.displayTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kInk,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$ideaCount건',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kGreen,
                  ),
                ),
              ],
            ),
            if (group.summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                group.summary,
                style: TextStyle(
                  fontSize: 12.5,
                  color: kInk.withValues(alpha: 0.55),
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
