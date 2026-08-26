import 'package:flutter_test/flutter_test.dart';
import 'package:moamal/models/session_meta.dart';

SessionMeta _meta({DateTime? createdAt, DateTime? endedAt}) => SessionMeta(
      sessionCode: 'ABC123',
      createdAt: createdAt,
      endedAt: endedAt,
    );

void main() {
  group('SessionMeta.canResumeAt — 복귀는 당일만 (2026-08-26 대표 결정)', () {
    final now = DateTime(2026, 8, 27, 10, 0);

    test('같은 날 만들어졌고 끝나지 않았으면 복귀', () {
      expect(_meta(createdAt: DateTime(2026, 8, 27, 9, 0)).canResumeAt(now),
          isTrue);
    });

    test('어제 만든 세션은 복귀하지 않는다', () {
      // 8/26 15:00 세션 → 8/27 10:00 실행. 예전엔 복귀해서 "1140:23"이 표시됐다.
      expect(_meta(createdAt: DateTime(2026, 8, 26, 15, 0)).canResumeAt(now),
          isFalse);
    });

    test('같은 날이라도 끝난 세션은 복귀하지 않는다', () {
      expect(
        _meta(
          createdAt: DateTime(2026, 8, 27, 9, 0),
          endedAt: DateTime(2026, 8, 27, 9, 50),
        ).canResumeAt(now),
        isFalse,
      );
    });

    test('createdAt이 없는 구 세션은 복귀하지 않는다 — 판단 근거가 없으면 안전한 쪽', () {
      expect(_meta().canResumeAt(now), isFalse);
    });

    test('자정 직후에도 어제 세션으로 넘어가지 않는다', () {
      final justAfterMidnight = DateTime(2026, 8, 27, 0, 5);
      expect(
        _meta(createdAt: DateTime(2026, 8, 26, 23, 55))
            .canResumeAt(justAfterMidnight),
        isFalse,
      );
    });
  });
}
