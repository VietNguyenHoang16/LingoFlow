import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocab/widgets/word_type_badge.dart';

void main() {
  testWidgets('WordTypeBadge shows full English label and icon by default',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WordTypeBadge(typeKey: 'noun'),
        ),
      ),
    );

    // Full English label (not compact short label)
    expect(find.text('Nouns'), findsOneWidget);
    expect(find.text('N'), findsNothing);

    // Icon is shown by default
    expect(find.byType(Icon), findsWidgets);
  });

  testWidgets('WordTypeBadge hides icon when showIcon is false',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WordTypeBadge(typeKey: 'verb', showIcon: false),
        ),
      ),
    );

    // Full English label still shown
    expect(find.text('Verbs'), findsOneWidget);

    // No icon rendered
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('WordTypeBadge renders nothing for empty type',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WordTypeBadge(typeKey: '', showIcon: false),
        ),
      ),
    );

    expect(find.byType(Icon), findsNothing);
    expect(tester.widgetList(find.byType(Text)).isEmpty, isTrue);
  });

  testWidgets('WordTypeBadge on colored surface uses bright background',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: WordTypeBadge(
            typeKey: 'noun',
            showIcon: false,
            onColoredSurface: true,
          ),
        ),
      ),
    );

    // Label still shown
    expect(find.text('Nouns'), findsOneWidget);

    // Background uses onPrimary (bright) tint, not the word-type color tint
    final container = tester.widgetList(find.byType(Container)).firstWhere((w) {
      final decoration = (w as Container).decoration;
      return decoration is BoxDecoration && decoration.color != null;
    }) as Container;
    final decoration = container.decoration as BoxDecoration;
    final onPrimary = ThemeData.light().colorScheme.onPrimary;
    expect(decoration.color!.alpha, greaterThan(0));
    expect(decoration.color, isNot(equals(Colors.blue)));
    // The bright background should be derived from onPrimary, not transparent type color
    expect(decoration.color!.red, equals(onPrimary.red));
  });
}
