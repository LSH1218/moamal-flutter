import 'group.dart';

/// 교사가 정리한 그룹 구성의 저장 단위.
///
/// `Group`은 `Idea` 본문을 통째로 들고 있지만 스냅샷은 **id만** 보관한다.
/// 원문은 `ideas` 하위 컬렉션이 단일 진실이고, 스냅샷은 "어떤 의견이 어느 그룹에
/// 속하는가"라는 배치 정보만 책임진다 (approvedGroups의 `idea_ids`와 같은 계약).
class GroupSnapshotEntry {
  final String groupId;
  final String? aiTitle;
  final List<String> ideaIds;

  const GroupSnapshotEntry({
    required this.groupId,
    required this.aiTitle,
    required this.ideaIds,
  });

  factory GroupSnapshotEntry.fromGroup(Group g) => GroupSnapshotEntry(
        groupId: g.id,
        aiTitle: g.aiTitle,
        ideaIds: g.ideas.map((i) => i.id).toList(),
      );

  factory GroupSnapshotEntry.fromMap(Map<String, dynamic> data) =>
      GroupSnapshotEntry(
        groupId: data['groupId'] as String? ?? '',
        aiTitle: data['aiTitle'] as String?,
        ideaIds:
            (data['ideaIds'] as List<dynamic>? ?? const []).cast<String>(),
      );

  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        'aiTitle': aiTitle,
        'ideaIds': ideaIds,
      };
}
