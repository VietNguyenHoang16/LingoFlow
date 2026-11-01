import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/pages/flashcard_practice_page.dart';
import 'package:lingoflow/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _word(int id, String word, String meaning) => {
      'id': id,
      'word': word,
      'meaning': meaning,
      'pronunciation': 'ˈtest',
      'full_details': '',
      'word_type': 'noun',
      'topic_tag': '',
      'common_synonyms': '',
      'is_mastered': false,
      'is_difficult': false,
      'review_count': 0,
      'correct_streak': 0,
      'ease_factor': 2.5,
      'interval_days': 0,
      'next_review_date': null,
      'last_reviewed_at': null,
      'mastery_level': 0,
      'lapse_count': 0,
      'collocations': '',
      'example_sentence': 'Example.',
      'example_translation': 'Ví dụ.',
      'example_target': word,
      'created_at': '2026-10-20T10:00:00.000Z',
      'list_name': 'Noun',
      'list_id': 3,
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('chưa biết hiện thông tin, tiếp quay lại thẻ, đã biết thì xong',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FlashcardPracticePage(
          userId: 1,
          listName: 'Test',
          preloadedWords: [_word(1, 'deploy', 'triển khai')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('deploy'), findsOneWidget);
    expect(find.text('triển khai'), findsNothing);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(find.text('Chưa biết'), findsOneWidget);
    expect(find.text('Đã biết'), findsOneWidget);

    await tester.tap(find.text('Chưa biết'));
    await tester.pumpAndSettle();

    expect(find.text('triển khai'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(find.text('Tiếp'), findsOneWidget);
    expect(find.text('Chưa biết'), findsNothing);

    await tester.tap(find.text('Tiếp'));
    await tester.pumpAndSettle();

    expect(find.text('triển khai'), findsNothing);
    expect(find.text('Chưa biết'), findsOneWidget);
    expect(find.text('Tiếp'), findsNothing);

    await tester.tap(find.text('Đã biết'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Đã biết hết 1 từ!'), findsOneWidget);
    expect(find.text('Làm lại'), findsOneWidget);
  });

  testWidgets('không overflow ở màn hình nhỏ 320x568', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FlashcardPracticePage(
          userId: 1,
          listName: 'Test',
          preloadedWords: [_word(1, 'deploy', 'triển khai')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

    await tester.tap(find.text('Chưa biết'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
  });
}
