import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/widgets/flip_word_card.dart';

const _longWord = 'antidisestablishmentarianism supercalifragilistic';
const _longMeaning =
    'Nghia rat dai de kiem tra tran man hinh dien thoai nho voi nhieu chu lien tiep nhau khong ngat';
const _longExample =
    'This is a very long example sentence to verify that the back face does not overflow on small screens at all.';
const _longTranslation =
    'Ban dich rat dai de kiem tra ellipsis tren man hinh hep khong bi tran layout.';

/// Vi du dai nhu cau that (2 cau, nhieu menh de) — truoc day bi cat o 3 dong.
const _hugeExample =
    'The committee spent several hours debating whether the proposed amendment, '
    'which would have fundamentally changed how local councils fund public '
    'libraries, community centres and youth programmes across the whole region, '
    'should be put to a vote before the end of the current legislative session.';

/// Ban dich tuong ung cung dai — truoc day bi cat o 2 dong.
const _hugeTranslation =
    'Uy ban da danh nhieu gio de tranh luan lieu ban sua doi duoc de xuat, '
    'ban nay se thay doi co ban cach hoi dong dia phuong tai tro cho thu vien cong, '
    'trung tam cong dong va cac chuong trinh thanh thieu nien trong toan khu vuc, '
    'co nen duoc dua ra bieu quyet truoc khi ket thuc ky hop phap ly hien tai hay khong.';

Widget _card({
  required bool flipped,
  String example = _longExample,
  String? exampleTranslation = _longTranslation,
  String meaning = _longMeaning,
}) =>
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FlipWordCard(
            isFlipped: flipped,
            word: _longWord,
            pronunciation: 'pronunciation-very-long-test',
            meaning: meaning,
            wordType: 'noun',
            topicTag: 'chu de rat dai de test tran man hinh',
            metaLabel: 'Test List',
            createdLabel: '3 ngay truoc',
            example: example,
            exampleTranslation: exampleTranslation,
            exampleTarget: 'example',
            accent: const Color(0xFF6366F1),
            isDifficult: true,
            onTap: () {},
            onLongPress: () {},
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
  testWidgets('mat truoc FlipWordCard khong overflow o 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_card(flipped: false));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('antidisestablishmentarianism'), findsOneWidget);
  });

  testWidgets('mat sau FlipWordCard khong overflow o 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_card(flipped: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Nghia rat dai'), findsOneWidget);
    expect(find.textContaining('Ban dich rat dai'), findsOneWidget);
  });

  testWidgets('mat sau hien day du vi du dai, khong cat bot o 320px',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _card(flipped: true, example: _hugeExample, exampleTranslation: _hugeTranslation),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      _paragraphWith(tester, 'legislative session').didExceedMaxLines,
      isFalse,
      reason: 'Cau vi du dai phai hien thi du, khong bi ellipsis.',
    );
  });

  testWidgets('mat sau hien day du ban dich dai, khong cat bot o 320px',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _card(flipped: true, example: _hugeExample, exampleTranslation: _hugeTranslation),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      _paragraphWith(tester, 'ky hop phap ly hien tai').didExceedMaxLines,
      isFalse,
      reason: 'Ban dich dai phai hien thi du, khong bi ellipsis.',
    );
  });

  testWidgets('mat sau hien day du nghia dai, khong cat bot o 320px',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    const hugeMeaning =
        'Nghia cua tu nay rat dai, gom nhieu ve nghia khac nhau ma nguoi hoc can doc '
        'het de hieu dung ngu canh su dung, khong the cat bot o bon dong tren man '
        'hinh dien thoai nho vi se lam mat thong tin quan trong cua tu vung.';
    await tester.pumpWidget(_card(flipped: true, meaning: hugeMeaning));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      _paragraphWith(tester, 'mat thong tin quan trong').didExceedMaxLines,
      isFalse,
      reason: 'Nghia dai phai hien thi du, khong bi ellipsis.',
    );
  });
}
