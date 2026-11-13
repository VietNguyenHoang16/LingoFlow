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
      'is_favorite': false,
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

  testWidgets('che do go tu duoc chon truoc khi vao va khong doi duoc',
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
      _word(3, 'abandon', 'bỏ rơi'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PracticePage(
          userId: 1,
          listName: 'Test',
          preloadedWords: words,
          studyMode: true,
          initialMode: AnswerInputMode.typing,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Từ tiếng Anh của nghĩa này là gì?'), findsOneWidget);
    // Khong con toggle doi che do trong session.
    expect(find.text('Gõ từ'), findsNothing);
    expect(find.text('Chọn nghĩa'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chon sai -> Sai roi; chon dung -> Dung roi; tieu tien va cau hoi giu nguyen',
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
      _word(3, 'abandon', 'bỏ rơi'),
    ];
    final meaningOf = {for (final w in words) w['word'] as String: w['meaning'] as String};

    final client = MockClient((request) async {
      return http.Response(jsonEncode({'data': []}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

    await http.runWithClient(() async {
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

      // Mac dinh da la chon nghia, khong can doi che do.
      String currentWord() => ['deploy', 'resilient', 'abandon']
          .firstWhere((w) => find.text(w).evaluate().isNotEmpty);

      // Câu 1: chon sai.
      final q1 = currentWord();
      final wrongMeaning = ['triển khai', 'kiên cường', 'bỏ rơi']
          .firstWhere((m) => m != meaningOf[q1]);
      await tester.tap(find.text(wrongMeaning));
      await tester.pumpAndSettle();
      expect(find.text('Sai rồi'), findsOneWidget);

      await tester.tap(find.text('Tiếp'));
      await tester.pumpAndSettle();

      // Câu 2: van o che do chon nghia, tieu tien 2/3.
      expect(find.text('Nghĩa của từ này là gì?'), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);

      // Cau moi: 4 lua chon hien ngay.
      expect(find.text('Xem lựa chọn'), findsNothing);

      final q2 = currentWord();
      expect(q2, isNot(q1));
      await tester.tap(find.text(meaningOf[q2]!));
      await tester.pumpAndSettle();
      expect(find.text('Đúng rồi!'), findsOneWidget);

      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('SRS mode: fallback wordIndex bo nhieu nghia + luu updateWordReview',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );

    final sessionWords = [
      _word(1, 'deploy', 'triển khai'),
      _word(2, 'resilient', 'kiên cường'),
    ];
    final indexWords = [
      _word(10, 'alpha', 'nghĩa A'),
      _word(11, 'beta', 'nghĩa B'),
      _word(12, 'gamma', 'nghĩa C'),
      _word(13, 'delta', 'nghĩa D'),
    ];

    final requests = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(body);
      switch (body['action']) {
        case 'getVocabularyWords':
          return http.Response(jsonEncode({'data': sessionWords}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        case 'wordIndex':
        case 'getWordIndex':
          return http.Response(jsonEncode({'data': indexWords}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response('{"data":null}', 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const PracticePage(
            listId: 3,
            userId: 2,
            listName: 'Test',
            studyMode: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      // Mac dinh la chon nghia: nhiu lay tu list tong (wordIndex) va chon ngau
      // nhien -> 4 lua chon (1 dung + 3 nhiu), bo nhiu thay doi moi lan.
      // (userId: 2 de tranh cache wordIndex static.)
      final allMeanings = [
        'triển khai',
        'kiên cường',
        'nghĩa A',
        'nghĩa B',
        'nghĩa C',
        'nghĩa D',
      ];
      final shownOptions =
          allMeanings.where((m) => find.text(m).evaluate().isNotEmpty).toList();
      expect(shownOptions.length, 4);

      final current = ['deploy', 'resilient']
          .firstWhere((w) => find.text(w).evaluate().isNotEmpty);
      final meaningOf = {'deploy': 'triển khai', 'resilient': 'kiên cường'};
      await tester.tap(find.text(meaningOf[current]!));
      await tester.pumpAndSettle();

      expect(find.text('Đúng rồi!'), findsOneWidget);
      expect(
        requests.where((r) => r['action'] == 'updateWordReview'),
        isNotEmpty,
      );
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('Luyện tập: "Không biết" lật thẻ ngay rồi Tiếp sang câu sau',
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
      _word(3, 'abandon', 'bỏ rơi'),
    ];

    final client = MockClient((request) async {
      return http.Response(jsonEncode({'data': []}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

    await http.runWithClient(() async {
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

      expect(find.text('Không biết'), findsOneWidget);

      await tester.tap(find.text('Không biết'));
      await tester.pumpAndSettle();

      // Lật thẻ hiện đáp án và nút Tiếp ngay, không cần chọn đáp án.
      expect(find.text('Sai rồi'), findsOneWidget);
      expect(find.text('Tiếp'), findsOneWidget);

      await tester.tap(find.text('Tiếp'));
      await tester.pumpAndSettle();
      expect(find.text('Nghĩa của từ này là gì?'), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('Luyện tập SRS: "Không biết" tính Hard (lastRating=3)',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );

    final sessionWords = [
      _word(1, 'deploy', 'triển khai'),
      _word(2, 'resilient', 'kiên cường'),
    ];
    final indexWords = [
      _word(10, 'alpha', 'nghĩa A'),
      _word(11, 'beta', 'nghĩa B'),
      _word(12, 'gamma', 'nghĩa C'),
      _word(13, 'delta', 'nghĩa D'),
    ];

    final requests = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(body);
      switch (body['action']) {
        case 'getVocabularyWords':
          return http.Response(jsonEncode({'data': sessionWords}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        case 'wordIndex':
        case 'getWordIndex':
          return http.Response(jsonEncode({'data': indexWords}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response('{"data":null}', 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const PracticePage(
            listId: 3,
            userId: 2,
            listName: 'Test',
            studyMode: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(find.text('Không biết'), findsOneWidget);
      await tester.tap(find.text('Không biết'));
      await tester.pumpAndSettle();

      final updates =
          requests.where((r) => r['action'] == 'updateWordReview').toList();
      expect(updates, isNotEmpty);
      expect((updates.first['data'] as Map)['lastRating'], 3);
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
