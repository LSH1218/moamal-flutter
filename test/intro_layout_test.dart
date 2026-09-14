import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moamal/screens/common/intro_screen.dart';

void main() {
  for (final width in [320.0, 390.0, 800.0, 1200.0]) {
    testWidgets('introduction fits $width px and keeps demo actions', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: IntroScreen()));
      expect(tester.takeException(), isNull);
      expect(find.text('수업 도구'), findsNothing);
      expect(find.text('학급회의 체험하기 →'), findsNWidgets(2));
      final first = find.ancestor(of: find.text('기능 검증'), matching: find.byType(Container)).first;
      final second = find.ancestor(of: find.text('현장 검증 · 예정'), matching: find.byType(Container)).first;
      if (width >= 800) {
        expect(tester.getSize(first).height, tester.getSize(second).height);
      }
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
