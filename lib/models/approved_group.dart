import 'package:cloud_firestore/cloud_firestore.dart';

class ApprovedGroup {
  final String groupId;
  final String title;
  final List<String> ideaIds;
  final DateTime approvedAt;
  final String approvedBy;
  final int revision;

  const ApprovedGroup({
    required this.groupId,
    required this.title,
    required this.ideaIds,
    required this.approvedAt,
    required this.approvedBy,
    required this.revision,
  });

  factory ApprovedGroup.fromFirestore(String id, Map<String, dynamic> data) {
    return ApprovedGroup(
      groupId: id,
      title: data['title'] as String? ?? '',
      ideaIds: (data['idea_ids'] as List<dynamic>? ?? []).cast<String>(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      approvedBy: data['approvedBy'] as String? ?? '',
      revision: data['revision'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'groupId': groupId,
        'title': title,
        'idea_ids': ideaIds,
        'approvedAt': Timestamp.fromDate(approvedAt),
        'approvedBy': approvedBy,
        'revision': revision,
      };
}
