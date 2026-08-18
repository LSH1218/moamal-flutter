import 'package:flutter/material.dart';
import '../models/group.dart';
import '../theme/app_theme.dart';

// 묶음 인덱스별 left-border 컬러
Color _borderColor(int index) {
  return switch (index) {
    0 => kYellow,
    1 => kGreen,
    _ => kGreen.withValues(alpha: 0.5),
  };
}

class GroupCard extends StatelessWidget {
  final int index;
  final Group group;
  final int voteCount;
  final bool editable;
  final String? titleOverride;

  const GroupCard({
    super.key,
    required this.index,
    required this.group,
    required this.voteCount,
    required this.editable,
    this.titleOverride,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = _borderColor(index);
    final isTop = index == 0 && voteCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
          top: BorderSide(color: const Color(0xFFE0DDD6)),
          right: BorderSide(color: const Color(0xFFE0DDD6)),
          bottom: BorderSide(color: const Color(0xFFE0DDD6)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${index + 1}. ${titleOverride ?? group.displayTitle}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: kInk,
                    ),
                  ),
                ),
                if (voteCount > 0) ...[
                  if (isTop)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: kYellow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$voteCount표',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: kInk,
                        ),
                      ),
                    )
                  else
                    Text(
                      '$voteCount표',
                      style: const TextStyle(
                        fontSize: 13,
                        color: kGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ],
            ),
            if (group.summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                group.summary,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 8),
            // 발언 수 칩
            Row(
              children: [
                _chip(
                  Icons.people_outline,
                  '${group.ideas.length}명',
                ),
                const SizedBox(width: 6),
                ...group.ideas
                    .expand((idea) => idea.text.split(' '))
                    .where((w) => w.length > 1)
                    .take(3)
                    .toSet()
                    .map((kw) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _chip(null, kw),
                        )),
              ],
            ),
            if (editable && group.ideas.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ...group.ideas.map(
                (idea) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '· ${idea.text}  — ${idea.speaker}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData? icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kGround,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kInk.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Colors.black45),
            const SizedBox(width: 3),
          ],
          Text(label, style: const TextStyle(fontSize: 11, color: kInk)),
        ],
      ),
    );
  }
}
