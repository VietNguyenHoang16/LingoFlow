import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/theme/app_theme.dart';
import 'package:lingoflow/widgets/review_example_panel.dart';

const _example =
    'Fame in the digital age is often ephemeral and disappears quickly.';
const _translation = 'Su noi tieng trong thoi dai so thuong chi thoang qua.';

Widget _panel({bool dark = false, String example = _example}) => MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReviewExamplePanel(
            word: 'Ephemeral',
            example: example,
            translation: _translation,
            target: 'ephemeral',
            accent: const Color(0xFF6366F1),
            onSpeak: () {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('hien cau + dich + tu khoa o 320px light', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_panel());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Fame in the digital age'), findsOneWidget);
    expect(find.textContaining('Su noi tieng'), findsOneWidget);
  });

  testWidgets('khong overflow o 320px dark', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_panel(dark: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('vi du rong tra ve shrink (an han)', (tester) async {
    await tester.pumpWidget(_panel(example: ''));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ReviewExamplePanel), findsOneWidget);
    expect(find.textContaining('Fame'), findsNothing);
  });

  testWidgets('cau EN du lon + dam de doc o light', (tester) async {
    await tester.pumpWidget(_panel());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final rich = tester.widget<RichText>(find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains('Fame in the digital age'),
    ));
    final root = rich.text as TextSpan;
    // Text.rich boc them 1 TextSpan ngoai (style mac dinh) -> style that
    // cua cau nam o span con dau tien.
    final inner = root.children!.firstWhere(
      (s) => s.toPlainText().contains('Fame'),
      orElse: () => root,
    ) as TextSpan;
    final base = inner.style!;
    expect(base.fontSize, 15);
    expect(base.fontWeight, FontWeight.w500);
    final keyword = inner.children!
        .whereType<TextSpan>()
        .firstWhere((s) => (s.text ?? '').toLowerCase().contains('ephemeral'));
    expect(keyword.style!.color, const Color(0xFF3730A3));
    expect(keyword.style!.fontWeight, FontWeight.w700);
  });
}
