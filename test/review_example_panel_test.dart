import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/theme/app_theme.dart';
import 'package:lingoflow/widgets/review_example_panel.dart';

const _example =
    'Fame in the digital age is often ephemeral and disappears quickly.';
const _translation = 'Su noi tieng trong thoi dai so thuong chi thoang qua.';

/// Vi du dai nhu cau that (2 cau, nhieu menh de) — truoc day bi cat o 3 dong.
const _hugeExample =
    'Fame in the digital age is often ephemeral, which is why so many people '
    'who went viral overnight discover that the audience they built around a '
    'single moment of attention, however large it looked at the time, quietly '
    'moves on to the next thing within a matter of weeks.';

/// Ban dich tuong ung cung dai — truoc day bi cat o 2 dong.
const _hugeTranslation =
    'Su noi tieng trong thoi dai so thuong chi thoang qua, do la ly do nhieu nguoi '
    'noi tieng chi sau mot dem nhan ra rang khan gia ma ho gay dung quanh mot khoanh '
    'khac duoc chu y du co lon den dau roi cung lang le chuyen sang mot chu de khac '
    'chi trong vai tuan ngan.';

Widget _panel({
  bool dark = false,
  String example = _example,
  String? translation = _translation,
}) =>
    MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReviewExamplePanel(
            word: 'Ephemeral',
            example: example,
            translation: translation,
            target: 'ephemeral',
            accent: const Color(0xFF6366F1),
            onSpeak: () {},
          ),
        ),
      ),
    );

/// Doan van ban da render chua [needle] — dung de kiem tra co bi cat dong khong.
RenderParagraph _paragraphWith(WidgetTester tester, String needle) {
  final finder = find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().contains(needle),
  );
  expect(finder, findsOneWidget);
  return tester.renderObject<RenderParagraph>(finder);
}

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
    expect(keyword.style!.color, AppTheme.light.colorScheme.onSurface);
    expect(keyword.style!.fontWeight, FontWeight.w700);
  });

  testWidgets('hien day du vi du dai, khong cat bot o 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _panel(example: _hugeExample, translation: _hugeTranslation),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      _paragraphWith(tester, 'matter of weeks').didExceedMaxLines,
      isFalse,
      reason: 'Cau vi du dai phai hien thi du, khong bi ellipsis.',
    );
  });

  testWidgets('hien day du ban dich dai, khong cat bot o 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _panel(example: _hugeExample, translation: _hugeTranslation),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      _paragraphWith(tester, 'trong vai tuan ngan').didExceedMaxLines,
      isFalse,
      reason: 'Ban dich dai phai hien thi du, khong bi ellipsis.',
    );
  });
}
