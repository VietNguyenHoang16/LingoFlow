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

  testWidgets('doi che do giua session: giu nguyen bo tu, hien thi dang chon nghia',
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

      // Mac dinh: che do go tu.
      expect(find.text('Từ tiếng Anh của nghĩa này là gì?'), findsOneWidget);

      // Toggle sang chon nghia.
      await tester.tap(find.text('Chọn nghĩa'));
      await tester.pumpAndSettle();

      expect(find.text('Nghĩa của từ này là gì?'), findsOneWidget);

      // Bo tu giu nguyen: chi tu hien tai hien dang cau hoi (cac tu con lai
      // chi xuat hien nghia cua chung o dang lua chon, khong xuat hien tu).
      final shownWords = ['deploy', 'resilient', 'abandon']
          .where((w) => find.text(w).evaluate().isNotEmpty)
          .toList();
      expect(shownWords.length, 1);

      // 3 nghia (1 dung + 2 nhieu cung bo) deu la lua chon.
      expect(find.text('triển khai'), findsOneWidget);
      expect(find.text('kiên cường'), findsOneWidget);
      expect(find.text('bỏ rơi'), findsOneWidget);

      // Chuyen nguoc ve go tu: o nhap lai hien, cung mot tu.
      await tester.tap(find.text('Gõ từ'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Từ tiếng Anh của nghĩa này là gì?'), findsOneWidget);

      expect(tester.takeException(), isNull);
    }, () => client);
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

      await tester.tap(find.text('Chọn nghĩa'));
      await tester.pumpAndSettle();

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

      await tester.tap(find.text('Chọn nghĩa'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      // 2 tu session -> 2 lua chon; fallback wordIndex bo thanh 4 lua chon.
      // (userId: 2 de tranh cache wordIndex static cua cac test truoc.)
      expect(find.text('nghĩa A'), findsOneWidget);

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
}
