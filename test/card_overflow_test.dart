import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/widgets/topic_tag_badge.dart';
import 'package:lingoflow/widgets/word_type_badge.dart';

const _longTag = 'chu de rat dai de test tran man hinh dien thoai nho';
const _longWord = 'antidisestablishmentarianism supercalifragilistic';

/// Cau truc hang meta giong Recent (_buildWordCardFront): chip loai tu +
/// ngay tao + nhan, tren man hinh hep 320px.
Widget recentMetaRow() => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320 - 32, // tru padding the
          child: Row(
            children: [
              WordTypeBadge(typeKey: 'noun', compact: true),
              const SizedBox(width: 8),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.schedule_rounded, size: 14),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text('3 ngay truoc',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Flexible(child: TopicTagBadge(tag: _longTag)),
            ],
          ),
        ),
      ),
    );

/// Cau truc hang the truoc giong Category/VocabularySet: chu Expanded + nhan.
Widget frontRow() => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320 - 32,
          child: Row(
            children: const [
              Expanded(
                child: Text(_longWord, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              SizedBox(width: 6),
              Flexible(child: TopicTagBadge(tag: _longTag)),
            ],
          ),
        ),
      ),
    );

void main() {
  testWidgets('hang meta Recent khong overflow o 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(recentMetaRow());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('hang the truoc khong overflow o 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(frontRow());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('badge tu co gian chu khong tran', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          child: TopicTagBadge(tag: _longTag),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Chu dai bi ellipsis trong chip.
    final text = tester.widget<Text>(find.textContaining('chu de'));
    expect(text.overflow, TextOverflow.ellipsis);
  });
}
