import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoflow/pages/practice_page.dart';
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

  testWidgets('tick xong: kết quả hiện ngay, bàn phím giữ focus, tick nữa sang câu',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );

    final words = [
      _word(1, 'deploy', 'triển khai'),
      _word(2, 'resilient', 'kiên cường'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PracticePage(
          userId: 1,
          listName: 'Test',
          preloadedWords: words,
          studyMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField, skipOffstage: false), 'zzz');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Sai rồi'), findsOneWidget);
    // Ô nhập vẫn được giữ focus -> bàn phím không đóng, không phải chờ mở lại.
    final field = tester.widget<TextField>(
      find.byType(TextField, skipOffstage: false),
    );
    expect(field.focusNode!.hasFocus, isTrue);

    // Tick lần nữa là sang câu tiếp (không cần chạm nút Tiếp).
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('Sai rồi'), findsNothing);
  });

  testWidgets('tick xong: kết quả hiện trước khi lưu SRS xong (không chờ mạng)',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );

    final saveGate = Completer<http.Response>();

    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      switch (body['action']) {
        case 'getVocabularyWords':
          return http.Response(
            jsonEncode({'data': [_word(1, 'deploy', 'triển khai')]}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        case 'updateWordReview':
          return saveGate.future;
      }
      return http.Response('{"data":null}', 200);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const PracticePage(
            listId: 3,
            userId: 1,
            listName: 'Test',
            studyMode: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField, skipOffstage: false), 'deploy');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Server chưa trả lời nhưng kết quả đã hiện -> bấm tick không bị khựng.
      expect(find.text('Đúng rồi!'), findsOneWidget);

      saveGate.complete(http.Response('{"data":null}', 200));
      await tester.pumpAndSettle();
    }, () => client);
  });
}
