import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/widgets/flip_word_card.dart';

const _longWord = 'antidisestablishmentarianism supercalifragilistic';
const _longMeaning =
    'Nghia rat dai de kiem tra tran man hinh dien thoai nho voi nhieu chu lien tiep nhau khong ngat';
const _longExample =
    'This is a very long example sentence to verify that the back face does not overflow on small screens at all.';
const _longTranslation =
    'Ban dich rat dai de kiem tra ellipsis tren man hinh hep khong bi tran layout.';

Widget _card({required bool flipped}) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FlipWordCard(
            isFlipped: flipped,
            word: _longWord,
            pronunciation: 'pronunciation-very-long-test',
            meaning: _longMeaning,
            wordType: 'noun',
            topicTag: 'chu de rat dai de test tran man hinh',
            metaLabel: 'Test List',
            createdLabel: '3 ngay truoc',
            example: _longExample,
            exampleTranslation: _longTranslation,
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
}
