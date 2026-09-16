import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/widgets/synonym_block.dart';

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('rong -> shrink (an han)', (tester) async {
    await tester.pumpWidget(wrap(const SynonymBlock(
      common: '',
      accent: Color(0xFF6366F1),
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Common'), findsNothing);
  });

  testWidgets('hien du 3 chip Common o 320px, khong ellipsis', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(const SynonymBlock(
      common: 'postpone · rearrange · defer',
      accent: Color(0xFF6366F1),
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Nguyen chu tung chip, khong bi cat giua tu (bug cu: postpone.rearra...).
    expect(find.text('postpone'), findsOneWidget);
    expect(find.text('rearrange'), findsOneWidget);
    expect(find.text('defer'), findsOneWidget);
  });

  testWidgets('Common >3 tu bi cat con 3', (tester) async {
    await tester.pumpWidget(wrap(const SynonymBlock(
      common: 'good, reliable, decent, stable, sound',
      accent: Color(0xFF6366F1),
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('good'), findsOneWidget);
    expect(find.text('reliable'), findsOneWidget);
    expect(find.text('decent'), findsOneWidget);
    expect(find.text('stable'), findsNothing);
    expect(find.text('sound'), findsNothing);
  });
}
