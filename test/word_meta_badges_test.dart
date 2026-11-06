import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/widgets/word_meta_badges.dart';

void main() {
  testWidgets('hien placeholder khi chua chon gi', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: WordMetaBadges(commonness: null, wordLevel: null)),
    ));
    expect(find.text('Trình độ'), findsOneWidget);
    expect(find.text('Thông dụng'), findsOneWidget);
  });

  testWidgets('hien gia tri khi da chon', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: WordMetaBadges(commonness: 8, wordLevel: 'B2')),
    ));
    expect(find.text('B2'), findsOneWidget);
    expect(find.text('8/10'), findsOneWidget);
  });

  testWidgets('cham chip goi callback tuong ung', (tester) async {
    var levelTaps = 0;
    var commonTaps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WordMetaBadges(
          commonness: null,
          wordLevel: null,
          onTapLevel: () => levelTaps++,
          onTapCommonness: () => commonTaps++,
        ),
      ),
    ));
    await tester.tap(find.text('Trình độ'));
    await tester.pump();
    await tester.tap(find.text('Thông dụng'));
    await tester.pump();
    expect(levelTaps, 1);
    expect(commonTaps, 1);
  });

  testWidgets('bang chon trinh do: chon muc moi -> tra gia tri', (tester) async {
    MetaPick<String>? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              result = await showLevelPicker(ctx, 'B2');
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('C1'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.value, 'C1');
  });

  testWidgets('bang chon trinh do: cham muc dang chon -> bo chon', (tester) async {
    MetaPick<String>? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              result = await showLevelPicker(ctx, 'B2');
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B2'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.value, isNull);
  });

  testWidgets('bang chon do thong dung: chon 7 -> tra 7', (tester) async {
    MetaPick<int>? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              result = await showCommonnessPicker(ctx, null);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.value, 7);
  });
}
