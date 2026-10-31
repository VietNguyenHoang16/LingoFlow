import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoflow/pages/practice_page.dart';
import 'package:lingoflow/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _longExample =
    'The committee spent several hours debating whether the proposed amendment, '
    'which would have fundamentally changed how local councils fund public '
    'libraries, community centres and youth programmes across the whole region, '
    'should be put to a vote before the end of the current legislative session.';

Map<String, dynamic> _word({
  String word = 'amendment',
  String example = _longExample,
}) =>
    {
      'id': 11,
      'word': word,
      'meaning': 'sự sửa đổi, điều chỉnh (luật, văn bản)',
      'pronunciation': 'əˈmend.mənt',
      'full_details': '',
      'word_type': 'noun',
      'topic_tag': 'Politics',
      'common_synonyms': '',
      'ease_factor': 2.5,
      'interval_days': 3,
      'correct_streak': 2,
      'review_count': 4,
      'lapse_count': 0,
      'mastery_level': 1,
      'example_sentence': example,
      'example_translation': 'Uỷ ban đã dành nhiều giờ để tranh luận về bản sửa đổi.',
      'example_target': 'amendment',
    };

void main() {
  Future<void> answer(
    WidgetTester tester, {
    required Size size,
    String typed = 'amendmant',
    bool studyMode = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );

    final client = MockClient((request) async {
      return http.Response('{"data":null}', 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: PracticePage(
          listId: 1,
          listName: 'Luyện tập thử',
          userId: 1,
          studyMode: studyMode,
          preloadedWords: [_word()],
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), typed);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }, () => client);
  }

  testWidgets('ket qua hien trong 1 khung, khong phai cuon (390x844)', (
    tester,
  ) async {
    await answer(tester, size: const Size(390, 844));

    expect(find.textContaining('Đáp án: amendment'), findsOneWidget);
    expect(find.text('Bạn gõ: amendmant'), findsOneWidget);
    // Vi du dai bi gioi han 4 dong de khong day nut Tiep ra ngoai man hinh.
    expect(find.textContaining('legislative session'), findsOneWidget);

    // Khong co cuon: noi dung van nam trong 1 khung.
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scrollable.position.maxScrollExtent, 0);

    final btn = tester.getRect(find.widgetWithText(ElevatedButton, 'Hoàn thành'));
    expect(btn.bottom, lessThanOrEqualTo(844));
    expect(btn.top, greaterThan(0));
    expect(find.text('Nhấn Enter để tiếp tục'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ket qua van gon tren man hinh nho (320x568)', (tester) async {
    await answer(tester, size: const Size(320, 568), studyMode: true);

    expect(find.textContaining('Đáp án: amendment'), findsOneWidget);
    final btn = tester.getRect(find.widgetWithText(ElevatedButton, 'Hoàn thành'));
    expect(btn.bottom, lessThanOrEqualTo(568));
    expect(btn.top, greaterThan(0));
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scrollable.position.maxScrollExtent, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tra loi dung: hien Đúng rồi! + đáp án', (tester) async {
    await answer(tester, size: const Size(390, 844), typed: 'amendment');

    expect(find.text('Đúng rồi!'), findsOneWidget);
    expect(find.text('Bạn gõ: amendment'), findsNothing);
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scrollable.position.maxScrollExtent, 0);
    expect(tester.takeException(), isNull);
  });
}
