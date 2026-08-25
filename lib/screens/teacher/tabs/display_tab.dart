import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../models/group.dart';
import '../../../models/meeting_report.dart';
import '../../../models/session_state.dart';
import '../../../services/deep_link_service.dart';
import '../../../services/gemini_grouping_engine.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/responsive.dart';
import '../../../widgets/group_card.dart';
import '../../../widgets/stat_row.dart';

/// 빔프로젝터용 공용 화면
class DisplayTab extends StatelessWidget {
  final SessionState session;
  final List<Group> groups;
  final GeminiGroupingEngine groupingEngine;
  final MeetingReport? meetingReport;

  const DisplayTab({
    super.key,
    required this.session,
    required this.groups,
    required this.groupingEngine,
    this.meetingReport,
  });

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final gid in session.votes.values) {
      counts[gid] = (counts[gid] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        StatRow(
          participantCount: session.participants.length,
          ideaCount: session.ideas.length,
          groupCount: groups.length,
        ),
        const SizedBox(height: 12),
        _entryPanel(),
        const SizedBox(height: 12),
        _groupsPanel(counts),
        const SizedBox(height: 12),
        _votesPanel(counts),
      ],
    );
  }

  Widget _entryPanel() {
    return _Panel(
      title: '입장하기',
      child: Column(
        children: [
          Text(
            session.sessionCode,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: kGreen,
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Builder(builder: (context) {
            final size =
                (MediaQuery.sizeOf(context).width * 0.38).clamp(140.0, 220.0);
            return QrImageView(
              data: DeepLinkService.buildJoinUri(session.sessionCode),
              version: QrVersions.auto,
              size: size,
            );
          }),
          const SizedBox(height: 10),
          const Text(
            '이 코드를 입력하거나 QR을 스캔해 참여하세요.',
            style: TextStyle(color: Colors.black38, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _groupsPanel(Map<String, int> counts) {
    return _Panel(
      title: '의견 묶음',
      child: groups.isEmpty
          ? const Text(
              '아직 등록된 의견이 없습니다.',
              style: TextStyle(color: Colors.black38),
            )
          : Column(
              children: groups
                  .asMap()
                  .entries
                  .map(
                    (e) => GroupCard(
                      group: e.value,
                      ideaCount: e.value.ideas.length,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _votesPanel(Map<String, int> counts) {
    final maxVotes = counts.values.isEmpty
        ? 1
        : counts.values.reduce((a, b) => a > b ? a : b);

    return _Panel(
      title: session.voteOpen ? '투표 진행 중' : '투표 결과',
      child: groups.isEmpty
          ? const Text(
              '아직 의견이 없습니다.',
              style: TextStyle(color: Colors.black38),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: groups.asMap().entries.map((e) {
                final g = e.value;
                final c = counts[g.id] ?? 0;
                final ratio = maxVotes > 0 ? c / maxVotes : 0.0;
                final isTop = e.key == 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isTop)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: kYellow,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '1위',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: kInk,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              groupingEngine.makeGroupTitle(g),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: kInk,
                              ),
                            ),
                          ),
                          Text(
                            '$c표',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: kGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 10,
                          backgroundColor: const Color(0xFFE0DDD6),
                          valueColor: AlwaysStoppedAnimation(
                            isTop ? kYellow : kGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;

  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: kInk,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
