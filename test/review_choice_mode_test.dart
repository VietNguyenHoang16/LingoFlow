import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoflow/pages/review_page.dart';
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
      'example_sentence': '',
      'example_translation': '',
      'example_target': '',
      'created_at': '2026-10-20T10:00:00.000Z',
      'set_name': 'Set',
      'list_id': 3,
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'review: doi sang chon nghia giu cau hien tai, chon sai hien dap an, Good luu SRS',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );

    final dueWords = [
      _word(1, 'apple', 'quả táo'),
      _word(2, 'banana', 'quả chuối'),
      _word(3, 'cherry', 'quả anh đào'),
    ];
    final indexWords = [
      ...dueWords,
      _word(10, 'date', 'quả chà là'),
      _word(11, 'egg', 'quả trứng'),
    ];
    final meaningOf = {
      'apple': 'quả táo',
      'banana': 'quả chuối',
      'cherry': 'quả anh đào',
    };

    final requests = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(body);
      final action = body['action'].toString();
      if (action == 'getWordIndex') {
        return http.Response(jsonEncode({'data': indexWords}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      if (action.startsWith('get')) {
        return http.Response(jsonEncode({'data': dueWords}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response('{"data":null}', 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const ReviewPage(userId: 7, listId: 3),
        ),
      );
      await tester.pumpAndSettle();

      // Mac dinh: che do chon nghia (nhin tu -> chon nghia).
      expect(find.text('Nghĩa của từ này là gì?'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      // Buoc "nhin va nghi": chua hien lua chon nao.
      expect(find.text('Xem lựa chọn'), findsOneWidget);
      expect(find.text('quả táo'), findsNothing);

      // Mot nhip nua de fallback wordIndex ve xong.
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem lựa chọn'));
      await tester.pumpAndSettle();

      String currentWord() => ['apple', 'banana', 'cherry']
          .firstWhere((w) => find.text(w).evaluate().isNotEmpty);
      final q1 = currentWord();

      // Nhiu lay tu list tong (wordIndex = toan bo tu) va chon ngau nhien ->
      // 4 lua chon (1 dung + 3 nhiu), bo nhiu co the khac nhau moi lan.
      final allMeanings = [
        'quả táo',
        'quả chuối',
        'quả anh đào',
        'quả chà là',
        'quả trứng',
      ];
      final shownOptions =
          allMeanings.where((m) => find.text(m).evaluate().isNotEmpty).toList();
      expect(shownOptions.length, 4);

      // Doi qua lai giua 2 che do: cau hoi khong doi.
      await tester.tap(find.text('Gõ từ'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(find.text('Chọn nghĩa'));
      await tester.pumpAndSettle();
      expect(currentWord(), q1);
      // Quay lai che do chon nghia -> ve buoc "nhin va nghi" (an lua chon).
      expect(find.text('Xem lựa chọn'), findsOneWidget);

      await tester.tap(find.text('Xem lựa chọn'));
      await tester.pumpAndSettle();

      // Chon SAI -> the lat, hien dap an dung + nut cham SRS.
      // Nhiu ngau nhien moi lan -> chon 1 nghia dang hien khac dap an dung.
      final wrong = allMeanings
          .where((m) => find.text(m).evaluate().isNotEmpty)
          .firstWhere((m) => m != meaningOf[q1]);
      await tester.tap(find.text(wrong));
      await tester.pumpAndSettle();
      expect(find.text('How well did you know it?'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      expect(find.text(meaningOf[q1]!), findsOneWidget);

      // Cham Good -> luu SRS + sang cau 2, van o che do chon nghia.
      await tester.tap(find.text('Good'));
      await tester.pumpAndSettle();
      expect(
        requests.where((r) => r['action'] == 'updateWordReview'),
        isNotEmpty,
      );
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Nghĩa của từ này là gì?'), findsOneWidget);

      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('review: "Không biết" lật thẻ ngay, bấm Tiếp tính Hard',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );

    final dueWords = [
      _word(1, 'apple', 'quả táo'),
      _word(2, 'banana', 'quả chuối'),
      _word(3, 'cherry', 'quả anh đào'),
    ];
    final indexWords = [
      ...dueWords,
      _word(10, 'date', 'quả chà là'),
      _word(11, 'egg', 'quả trứng'),
    ];

    final requests = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(body);
      final action = body['action'].toString();
      if (action == 'getWordIndex') {
        return http.Response(jsonEncode({'data': indexWords}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      if (action.startsWith('get')) {
        return http.Response(jsonEncode({'data': dueWords}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response('{"data":null}', 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const ReviewPage(userId: 7, listId: 3),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      // Chưa trả lời: có nút "Không biết" ngay ở bước nhìn và nghĩ.
      expect(find.text('Không biết'), findsOneWidget);
      expect(find.text('Xem lựa chọn'), findsOneWidget);
      // "Không biết" phải đứng trước nút mở lựa chọn.
      expect(
        tester.getTopLeft(find.text('Không biết')).dy,
        lessThan(tester.getTopLeft(find.text('Xem lựa chọn')).dy),
      );

      await tester.tap(find.text('Không biết'));
      await tester.pumpAndSettle();

      // Lật thẻ hiện thông tin từ, chỉ còn 1 nút Tiếp (đã tính Hard).
      expect(find.text('Không biết · tính là Hard'), findsOneWidget);
      expect(find.text('Tiếp'), findsOneWidget);
      expect(find.text('How well did you know it?'), findsNothing);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);

      await tester.tap(find.text('Tiếp'));
      await tester.pumpAndSettle();

      final updates =
          requests.where((r) => r['action'] == 'updateWordReview').toList();
      expect(updates, isNotEmpty);
      expect((updates.first['data'] as Map)['lastRating'], 3);
      // Sang câu 2, vẫn ở chế độ chọn nghĩa.
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Nghĩa của từ này là gì?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
