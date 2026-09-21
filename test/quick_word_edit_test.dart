import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/widgets/quick_word_edit.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget opener(void Function(WordEditResult?) onResult) => wrap(Builder(
      builder: (ctx) => FilledButton(
        onPressed: () async {
          onResult(
            await showQuickWordEdit(
              context: ctx,
              word: 'apple',
              meaning: 'quả táo',
            ),
          );
        },
        child: const Text('open'),
      ),
    ));

void main() {
  testWidgets('dieu truoc tu + nghia, sua roi Luu -> tra ve ket qua moi', (
    tester,
  ) async {
    WordEditResult? got;
    await tester.pumpWidget(opener((r) => got = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Sửa từ & nghĩa'), findsOneWidget);
    expect(find.text('apple'), findsOneWidget);
    expect(find.text('quả táo'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'apples');
    await tester.enterText(find.byType(TextField).last, 'những quả táo');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    expect(got?.word, 'apples');
    expect(got?.meaning, 'những quả táo');
    expect(find.text('Sửa từ & nghĩa'), findsNothing);
  });

  testWidgets('nhap rong -> hien loi ca 2 o va khong dong', (tester) async {
    WordEditResult? got;
    var closed = false;
    await tester.pumpWidget(opener((r) {
      got = r;
      closed = true;
    }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '');
    await tester.enterText(find.byType(TextField).last, '');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pump();

    expect(find.text('Vui lòng nhập từ'), findsOneWidget);
    expect(find.text('Vui lòng nhập nghĩa'), findsOneWidget);
    expect(find.text('Sửa từ & nghĩa'), findsOneWidget);
    expect(closed, isFalse);
    expect(got, isNull);
  });

  testWidgets('Huy -> dong va tra ve null (khong doi du lieu)', (tester) async {
    WordEditResult? got;
    var closed = false;
    await tester.pumpWidget(opener((r) {
      got = r;
      closed = true;
    }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'apples');
    await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(got, isNull);
  });

  testWidgets('khong doi gi + phim Done -> tra ve null (khong luu thua)', (
    tester,
  ) async {
    WordEditResult? got;
    await tester.pumpWidget(opener((r) => got = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Focus o Nghia roi bam Done tren ban phim -> di qua onSubmitted.
    await tester.tap(find.byType(TextField).last);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(got, isNull);
    expect(find.text('Sửa từ & nghĩa'), findsNothing);
  });
}
