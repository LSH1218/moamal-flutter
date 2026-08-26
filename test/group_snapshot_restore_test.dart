import 'package:flutter_test/flutter_test.dart';
import 'package:moamal/models/group.dart';
import 'package:moamal/models/group_snapshot.dart';
import 'package:moamal/models/idea.dart';
import 'package:moamal/services/gemini_grouping_engine.dart';

Idea _idea(String id, String text) =>
    Idea(id: id, speaker: '학생', text: text, source: 'stt');

void main() {
  group('GeminiGroupingEngine.restoreSnapshot (Mercury-Session-02)', () {
    late GeminiGroupingEngine engine;

    setUp(() => engine = GeminiGroupingEngine(onUpdate: () {}));

    test('스냅샷을 복원하면 그룹 구성과 교사 수정 제목이 유지된다', () {
      final ideas = [_idea('i1', '김치'), _idea('i2', '김치찌개'), _idea('i3', '불고기')];
      final snapshot = [
        const GroupSnapshotEntry(
            groupId: 'g1', aiTitle: '김치와 김치요리', ideaIds: ['i1', 'i2']),
        const GroupSnapshotEntry(
            groupId: 'g2', aiTitle: '불고기 대중성', ideaIds: ['i3']),
      ];

      expect(engine.restoreSnapshot(snapshot, ideas), isTrue);

      final groups = engine.cachedGroups!;
      expect(groups.length, 2);
      expect(groups[0].id, 'g1');
      expect(groups[0].aiTitle, '김치와 김치요리');
      expect(groups[0].ideas.map((i) => i.id), ['i1', 'i2']);
      expect(groups[1].aiTitle, '불고기 대중성');
    });

    test('복원된 의견은 재그룹화 대상이 아니다 — makeGroups가 캐시를 그대로 반환', () {
      final ideas = [_idea('i1', '김치'), _idea('i2', '김치찌개')];
      engine.restoreSnapshot(
        [
          const GroupSnapshotEntry(
              groupId: 'g1', aiTitle: '김치와 김치요리', ideaIds: ['i1', 'i2'])
        ],
        ideas,
      );

      final result = engine.makeGroups(ideas);
      expect(result.length, 1);
      expect(result.first.aiTitle, '김치와 김치요리');
    });

    test('이미 그룹이 있으면 복원하지 않는다 — 진행 중 구성을 덮지 않는다', () {
      final ideas = [_idea('i1', '김치')];
      engine.restoreSnapshot(
        [const GroupSnapshotEntry(groupId: 'g1', aiTitle: '첫 복원', ideaIds: ['i1'])],
        ideas,
      );
      final second = engine.restoreSnapshot(
        [const GroupSnapshotEntry(groupId: 'g9', aiTitle: '나중 것', ideaIds: ['i1'])],
        ideas,
      );

      expect(second, isFalse);
      expect(engine.cachedGroups!.first.aiTitle, '첫 복원');
    });

    test('원문이 사라진 그룹은 복원하지 않는다 — ideas가 단일 진실', () {
      final ideas = [_idea('i1', '김치')];
      final ok = engine.restoreSnapshot(
        [
          const GroupSnapshotEntry(groupId: 'g1', aiTitle: '남은 그룹', ideaIds: ['i1']),
          const GroupSnapshotEntry(
              groupId: 'g2', aiTitle: '삭제된 그룹', ideaIds: ['gone']),
        ],
        ideas,
      );

      expect(ok, isTrue);
      expect(engine.cachedGroups!.length, 1);
      expect(engine.cachedGroups!.first.id, 'g1');
    });

    test('빈 스냅샷은 복원하지 않는다 — 신규 세션은 AI 그룹화로 간다', () {
      expect(engine.restoreSnapshot(const [], [_idea('i1', '김치')]), isFalse);
      expect(engine.cachedGroups, isNull);
    });

    test('그룹 변경 시 onGroupsChanged로 저장 대상이 전달된다', () {
      List<Group>? persisted;
      engine.onGroupsChanged = (g) => persisted = g;

      engine.restoreSnapshot(
        [
          const GroupSnapshotEntry(groupId: 'g1', aiTitle: 'A', ideaIds: ['i1']),
          const GroupSnapshotEntry(groupId: 'g2', aiTitle: 'B', ideaIds: ['i2']),
        ],
        [_idea('i1', '김치'), _idea('i2', '불고기')],
      );
      engine.mergeGroups('g1', ['g2'], '합친 그룹');

      expect(persisted, isNotNull);
      expect(persisted!.length, 1);
      expect(persisted!.first.aiTitle, '합친 그룹');
      expect(persisted!.first.ideas.length, 2);
    });
  });
}
