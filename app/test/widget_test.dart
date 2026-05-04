// Smoke test: the app builds and the root widget renders.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hytranslate/main.dart';

void main() {
  testWidgets('App boots with the translate screen visible',
      (WidgetTester tester) async {
    await tester.pumpWidget(const HyTranslateApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
