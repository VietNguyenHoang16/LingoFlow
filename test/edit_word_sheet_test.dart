import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/widgets/edit_word_sheet.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('mo sheet, chon chip, nhap lieu, Luu khong crash', (tester) async {
    EditWordResult? got;
    await tester.pumpWidget(wrap(Builder(
      builder: (ctx) => FilledButton(
        onPressed: () async {
          got = await showEditWordSheet(
            context: ctx,
            word: 'apple',
            meaning: 'qua tao',
            pronunciation: '',
            fullDetails: '',
            wordType: 'noun',
            topicTag: 'gym',
          );
        },
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Chỉnh sửa từ'), findsOneWidget);

    // Chon chip loai tu (rebuild sheet qua setSheetState).
    await tester.tap(find.text('V').first);
    await tester.pump();

    // Mo Chi tiet.
    await tester.tap(find.text('Chi tiết (tùy chọn)'));
    await tester.pumpAndSettle();

    // Sua nhan roi Luu.
    await tester.enterText(find.widgetWithText(TextField, 'vd: gym'), 'sport');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    expect(got, isNotNull);
    expect(got!.word, 'apple');
    expect(got!.topicTag, 'sport');
  });

  testWidgets('bao loi inline khi tu trong, sua lai roi Luu duoc', (tester) async {
    EditWordResult? got;
    await tester.pumpWidget(wrap(Builder(
      builder: (ctx) => FilledButton(
        onPressed: () async {
          got = await showEditWordSheet(
            context: ctx,
            word: 'apple',
            meaning: 'qua tao',
            pronunciation: '',
            fullDetails: '',
            wordType: '',
            topicTag: '',
            showWordType: false,
            showDetails: false,
          );
        },
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Xoa trang o Tu roi Luu -> hien loi inline, sheet khong dong.
    await tester.enterText(find.widgetWithText(TextField, 'Từ'), '');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pump();
    expect(find.text('Vui lòng nhập từ'), findsOneWidget);

    // Nhap lai roi Luu -> dong sheet, co ket qua.
    await tester.enterText(find.widgetWithText(TextField, 'Từ'), 'pear');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(got, isNotNull);
    expect(got!.word, 'pear');
  });
}
