import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/widgets/example_card.dart';

/// Vi du dai nhu cau that (2 cau, nhieu menh de) — truoc day bi cat o 2 dong.
const _hugeExample =
    'The committee spent several hours debating whether the proposed amendment, '
    'which would have fundamentally changed how local councils fund public '
    'libraries, community centres and youth programmes across the whole region, '
    'should be put to a vote before the end of the current legislative session.';

/// Ban dich tuong ung cung dai — truoc day bi cat o 1 dong.
const _hugeTranslation =
    'Uy ban da danh nhieu gio de tranh luan lieu ban sua doi duoc de xuat, '
    'ban nay se thay doi co ban cach hoi dong dia phuong tai tro cho thu vien cong, '
    'trung tam cong dong va cac chuong trinh thanh thieu nien trong toan khu vuc, '
    'co nen duoc dua ra bieu quyet truoc khi ket thuc ky hop phap ly hien tai hay khong.';

Widget _card({String example = _hugeExample, String? translation = _hugeTranslation}) =>
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ExampleCard(
            example: example,
            pos: 'noun',
            translation: translation,
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
  testWidgets('hien day du vi du dai, khong cat bot o 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_card());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      _paragraphWith(tester, 'legislative session').didExceedMaxLines,
      isFalse,
      reason: 'Cau vi du dai phai hien thi du, khong bi ellipsis.',
    );
  });

  testWidgets('hien day du ban dich dai, khong cat bot o 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_card());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      _paragraphWith(tester, 'ky hop phap ly hien tai').didExceedMaxLines,
      isFalse,
      reason: 'Ban dich dai phai hien thi du, khong bi ellipsis.',
    );
  });

  testWidgets('an han khi vi du rong', (tester) async {
    await tester.pumpWidget(_card(example: ''));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Vi du'), findsNothing);
  });
}
