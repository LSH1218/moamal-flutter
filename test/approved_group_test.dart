import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moamal/models/approved_group.dart';

void main() {
  group('ApprovedGroup', () {
    final approvedAt = DateTime(2026, 7, 17, 9, 0, 0);

    final sample = ApprovedGroup(
      groupId: 'group-1',
      title: '김치',
      ideaIds: ['idea-a', 'idea-b', 'idea-c'],
      approvedAt: approvedAt,
      approvedBy: 'uid-teacher',
      revision: 1,
    );

    test('필드가 그대로 보존된다', () {
      expect(sample.groupId, 'group-1');
      expect(sample.title, '김치');
      expect(sample.ideaIds, ['idea-a', 'idea-b', 'idea-c']);
      expect(sample.approvedAt, approvedAt);
      expect(sample.approvedBy, 'uid-teacher');
      expect(sample.revision, 1);
    });

    test('toFirestore() 키가 계약과 일치한다', () {
      final map = sample.toFirestore();
      expect(map['groupId'], 'group-1');
      expect(map['title'], '김치');
      expect(map['idea_ids'], ['idea-a', 'idea-b', 'idea-c']);
      expect(map['approvedBy'], 'uid-teacher');
      expect(map['revision'], 1);
      expect(map['approvedAt'], isA<Timestamp>());
    });

    test('fromFirestore() 왕복 직렬화 — idea_ids와 groupId 보존', () {
      final map = sample.toFirestore();
      final restored = ApprovedGroup.fromFirestore('group-1', map);

      expect(restored.groupId, sample.groupId);
      expect(restored.title, sample.title);
      expect(restored.ideaIds, sample.ideaIds);
      expect(restored.approvedBy, sample.approvedBy);
      expect(restored.revision, sample.revision);
      // approvedAt은 Timestamp 왕복 후 초 단위 정밀도
      expect(restored.approvedAt.millisecondsSinceEpoch,
          closeTo(approvedAt.millisecondsSinceEpoch, 1000));
    });

    test('fromFirestore() 누락 필드에 안전한 기본값을 사용한다', () {
      final empty = ApprovedGroup.fromFirestore('g', {});
      expect(empty.groupId, 'g');
      expect(empty.title, '');
      expect(empty.ideaIds, isEmpty);
      expect(empty.approvedBy, '');
      expect(empty.revision, 1);
    });

    test('idea_ids의 모든 ID가 원문 ideas 컬렉션을 참조할 수 있다', () {
      const originalIds = {'idea-a', 'idea-b', 'idea-c', 'idea-d'};
      final missing =
          sample.ideaIds.where((id) => !originalIds.contains(id)).toList();
      expect(missing, isEmpty,
          reason: 'idea_ids에 원문 ideas에 없는 ID가 있으면 안 된다');
    });
  });
}
