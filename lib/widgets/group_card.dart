import 'package:flutter/material.dart';
import '../models/group.dart';
import '../theme/app_theme.dart';

/// 교사 홈 요약 탭 그룹 카드.
/// kCardBg + 1px kBorder(균일 색) + left 4px kYellow 강조띠, radius 14.
/// 강조띠는 Border 대신 ClipRRect+Stack으로 분리한다 — 면마다 다른 색 Border에
/// borderRadius를 같이 주면 paint 단계에서 예외가 나 카드 전체가 안 보이게 된다.
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
    // 좌측만 다른 색인 Border + borderRadius 조합은 paint 단계에서
    // "A borderRadius can only be given on borders with uniform colors."
    // 예외를 던진다. build 단계가 아니라 paint 단계 예외라 빨간 에러 화면 없이
    // 카드 전체가 그냥 안 그려진다 — 좌측 강조띠는 ClipRRect + Stack으로 분리한다.
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: kCardBg,
          border: Border.all(color: kBorder),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: kYellow),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 13, 14, 13),
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
          ],
        ),
      ),
      ),
    );
  }
}
