import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moamal/screens/common/intro_screen.dart';

void main() {
  for (final width in [320.0, 390.0, 800.0, 1000.0, 1200.0, 1440.0]) {
    testWidgets('introduction fits $width px and keeps demo actions', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: IntroScreen()));
      expect(tester.takeException(), isNull);
      expect(find.text('수업 도구'), findsNothing);
      expect(find.text('학급회의 체험하기 →'), findsNWidgets(2));
      final first = find
          .ancestor(of: find.text('기능 검증'), matching: find.byType(Container))
          .first;
      final second = find
          .ancestor(
            of: find.text('현장 검증 · 예정'),
            matching: find.byType(Container),
          )
          .first;
      if (width >= 1000) {
        expect(tester.getSize(first).height, tester.getSize(second).height);
      }
      for (final element in find.byType(Text).evaluate()) {
        final textBox = element.renderObject;
        if (textBox is! RenderBox) continue;
        RenderBox? card;
        element.visitAncestorElements((ancestor) {
          final widget = ancestor.widget;
          if (widget is Container && widget.decoration is BoxDecoration) {
            card = ancestor.renderObject as RenderBox?;
            return false;
          }
          return true;
        });
        if (card != null) {
          final bottom = textBox
              .localToGlobal(Offset(0, textBox.size.height))
              .dy;
          final cardBottom = card!
              .localToGlobal(Offset(0, card!.size.height))
              .dy;
          expect(
            bottom,
            lessThanOrEqualTo(cardBottom - 11),
            reason: 'Text must retain bottom padding inside its card',
          );
        }
      }
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -6000),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
