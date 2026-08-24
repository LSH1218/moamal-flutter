import 'package:cloud_firestore/cloud_firestore.dart';

class MergeLogSourceGroup {
  final String groupId;
  final String title;
  final List<String> ideaIds;
  final bool wasApproved;
  final DateTime? approvedAt;
  final String? approvedBy;
  final int? revision;

  const MergeLogSourceGroup({
    required this.groupId,
    required this.title,
    required this.ideaIds,
    required this.wasApproved,
    this.approvedAt,
    this.approvedBy,
    this.revision,
  });

  Map<String, dynamic> toFirestore() => {
        'groupId': groupId,
        'title': title,
        'idea_ids': ideaIds,
        'wasApproved': wasApproved,
        'approvedAt':
            approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
        'approvedBy': approvedBy,
        'revision': revision,
      };

  factory MergeLogSourceGroup.fromMap(Map<String, dynamic> m) =>
      MergeLogSourceGroup(
        groupId: m['groupId'] as String,
        title: m['title'] as String? ?? '',
        ideaIds: (m['idea_ids'] as List<dynamic>? ?? []).cast<String>(),
        wasApproved: m['wasApproved'] as bool? ?? false,
        approvedAt: (m['approvedAt'] as Timestamp?)?.toDate(),
        approvedBy: m['approvedBy'] as String?,
        revision: m['revision'] as int?,
      );
}

class MergeLog {
  final String logId;
  final DateTime mergedAt;
  final List<MergeLogSourceGroup> sourceGroups;
  final String resultGroupId;
  final bool undone;

  const MergeLog({
    required this.logId,
    required this.mergedAt,
    required this.sourceGroups,
    required this.resultGroupId,
    required this.undone,
  });

  MergeLog copyWith({bool? undone}) => MergeLog(
        logId: logId,
        mergedAt: mergedAt,
        sourceGroups: sourceGroups,
        resultGroupId: resultGroupId,
        undone: undone ?? this.undone,
      );

  Map<String, dynamic> toFirestore() => {
        'logId': logId,
        'mergedAt': Timestamp.fromDate(mergedAt),
        'sourceGroups': sourceGroups.map((s) => s.toFirestore()).toList(),
        'resultGroupId': resultGroupId,
        'undone': undone,
      };

  factory MergeLog.fromFirestore(String id, Map<String, dynamic> data) =>
      MergeLog(
        logId: id,
        mergedAt:
            (data['mergedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        sourceGroups: (data['sourceGroups'] as List<dynamic>? ?? [])
            .map((e) =>
                MergeLogSourceGroup.fromMap(e as Map<String, dynamic>))
            .toList(),
        resultGroupId: data['resultGroupId'] as String? ?? '',
        undone: data['undone'] as bool? ?? false,
      );
}
