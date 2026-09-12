import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/widgets/quick_meaning_edit.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('nhap nghia moi + done -> tra ve string moi', (tester) async {
    String? got;
    var closed = false;
    await tester.pumpWidget(wrap(Builder(
      builder: (ctx) => FilledButton(
        onPressed: () async {
          got = await showQuickMeaningEdit(
            context: ctx,
            word: 'apple',
            meaning: 'quả táo',
          );
          closed = true;
        },
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Sửa nghĩa nhanh "apple"'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'quả lê');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(got, 'quả lê');
  });

  testWidgets('nhap rong + Luu -> hien loi, khong dong', (tester) async {
    String? got = 'initial';
    var closed = false;
    await tester.pumpWidget(wrap(Builder(
      builder: (ctx) => FilledButton(
        onPressed: () async {
          got = await showQuickMeaningEdit(
            context: ctx,
            word: 'apple',
            meaning: 'quả táo',
          );
          closed = true;
        },
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pump();

    expect(find.text('Vui lòng nhập nghĩa'), findsOneWidget);
    expect(closed, isFalse);
    expect(find.text('Sửa nghĩa nhanh "apple"'), findsOneWidget);
    expect(got, 'initial');
  });
}
