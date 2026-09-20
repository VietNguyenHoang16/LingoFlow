import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/services/answer_comparison.dart';
import 'package:lingoflow/widgets/answer_diff_text.dart';

const TextStyle _base = TextStyle(
  fontFamily: 'Plus Jakarta Sans',
  fontSize: 30,
  fontWeight: FontWeight.w800,
  color: Colors.white,
);
const Color _mismatch = Color(0xFFFFD54F);

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF6366F1),
        body: Center(
          child: SizedBox(width: 240, child: child),
        ),
      ),
    );

RichText _richWith(WidgetTester tester, String plain) => tester
    .widgetList<RichText>(find.byType(RichText))
    .firstWhere((w) => w.text.toPlainText() == plain);

/// Text.rich bọc thêm 1 TextSpan ngoài (style mặc định) -> đi xuống span con
/// đầu tiên để lấy đúng các span do widget sinh ra.
List<TextSpan> _childSpans(RichText rich) {
  var span = rich.text as TextSpan;
  while (span.children?.length == 1 &&
      span.children!.first is TextSpan &&
      ((span.children!.first as TextSpan).children?.isNotEmpty ?? false)) {
    span = span.children!.first as TextSpan;
  }
  return (span.children ?? const []).whereType<TextSpan>().toList();
}

void main() {
  testWidgets('ky tu thieu duoc to mau + gach chan, cac chu khac giu style goc',
      (tester) async {
    final diff = diffAnswer(typed: 'aple', expected: 'apple');
    await tester.pumpWidget(_wrap(AnswerDiffText(
      text: 'apple',
      marks: diff.expectedMarks,
      baseStyle: _base,
      mismatchColor: _mismatch,
      maxLines: 1,
    )));
    await tester.pumpAndSettle();

    final rich = _richWith(tester, 'apple');
    final spans = _childSpans(rich);
    // Gom span theo trang thai: 'ap' (keep) + 'p' (missing) + 'le' (keep).
    expect(spans.length, 3);

    final missing = spans[1];
    expect(missing.text, 'p');
    expect(missing.style!.color, _mismatch);
    expect(missing.style!.decoration, TextDecoration.underline);
    expect(missing.style!.decorationColor, _mismatch);

    final kept = spans[0];
    expect(kept.text, 'ap');
    expect(kept.style!.color, Colors.white);
    expect(kept.style!.decoration, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ky tu go thua bi gach ngang tren chuoi da go', (tester) async {
    final diff = diffAnswer(typed: 'appple', expected: 'apple');
    await tester.pumpWidget(_wrap(AnswerDiffText(
      text: 'appple',
      marks: diff.typedMarks,
      baseStyle: _base,
      mismatchColor: _mismatch,
      maxLines: 1,
    )));
    await tester.pumpAndSettle();

    final extra = _childSpans(_richWith(tester, 'appple'))
        .firstWhere((s) => (s.text ?? '').contains('p') &&
            s.style?.decoration == TextDecoration.lineThrough);
    expect(extra.style!.color, _mismatch);
    expect(extra.style!.decorationColor, _mismatch);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ky tu go sai dung kieu gach theo tham so', (tester) async {
    final diff = diffAnswer(typed: 'cut', expected: 'cat');
    await tester.pumpWidget(_wrap(AnswerDiffText(
      text: 'cut',
      marks: diff.typedMarks,
      baseStyle: _base,
      mismatchColor: _mismatch,
      replacedDecoration: TextDecoration.lineThrough,
      maxLines: 1,
    )));
    await tester.pumpAndSettle();

    final replaced = _childSpans(_richWith(tester, 'cut'))
        .firstWhere((s) => s.text == 'u');
    expect(replaced.style!.decoration, TextDecoration.lineThrough);
    expect(tester.takeException(), isNull);
  });

  testWidgets('khong co dau lech -> render Text thuong', (tester) async {
    final diff = diffAnswer(typed: 'apple', expected: 'apple');
    await tester.pumpWidget(_wrap(AnswerDiffText(
      text: 'apple',
      marks: diff.expectedMarks,
      baseStyle: _base,
      mismatchColor: _mismatch,
      maxLines: 1,
    )));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate((w) => w is Text && w.textSpan == null),
      findsOneWidget,
    );
    expect(find.text('apple'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('marks rong hoac lech chuoi -> fallback an toan', (tester) async {
    final bad = diffAnswer(typed: 'aple', expected: 'apple').expectedMarks;
    await tester.pumpWidget(_wrap(AnswerDiffText(
      text: 'banana',
      marks: bad,
      baseStyle: _base,
      mismatchColor: _mismatch,
      maxLines: 1,
    )));
    await tester.pumpAndSettle();
    expect(find.text('banana'), findsOneWidget);

    await tester.pumpWidget(_wrap(AnswerDiffText(
      text: 'banana',
      marks: const <CharMark>[],
      baseStyle: _base,
      mismatchColor: _mismatch,
      maxLines: 1,
    )));
    await tester.pumpAndSettle();
    expect(find.text('banana'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Text && w.textSpan == null),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tu dai khong overflow o 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const longWord = 'antidisestablishmentarianism';
    final diff = diffAnswer(typed: 'antidisestablishmentarianis', expected: longWord);
    await tester.pumpWidget(_wrap(AnswerDiffText(
      text: longWord,
      marks: diff.expectedMarks,
      baseStyle: _base,
      mismatchColor: _mismatch,
      maxLines: 2,
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AnswerDiffText), findsOneWidget);
  });
}