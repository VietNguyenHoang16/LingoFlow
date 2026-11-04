import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoflow/pages/review_page.dart';
import 'package:lingoflow/theme/app_theme.dart';
import 'package:lingoflow/widgets/meaning_choice_card.dart';
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

final _dueWords = [
  _word(1, 'apple', 'quả táo'),
  _word(2, 'banana', 'quả chuối'),
  _word(3, 'cherry', 'quả anh đào'),
];
const _correctMeanings = ['quả táo', 'quả chuối', 'quả anh đào'];

MockClient _buildClient(List<Map<String, dynamic>> requests) {
  final indexWords = [
    ..._dueWords,
    _word(10, 'date', 'quả chà là'),
    _word(11, 'egg', 'quả trứng'),
    _word(12, 'fig', 'quả sung'),
  ];
  return MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    requests.add(body);
    final action = body['action'].toString();
    if (action == 'getWordIndex') {
      return http.Response(jsonEncode({'data': indexWords}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    if (action.startsWith('get')) {
      return http.Response(jsonEncode({'data': _dueWords}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    return http.Response('{"data":null}', 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
  });
}

Future<void> _pumpReview(
  WidgetTester tester, {
  required int userId,
  required AnswerInputMode initialMode,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('flutter_tts'),
    (call) async => 1,
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: ReviewPage(userId: userId, listId: 3, initialMode: initialMode),
    ),
  );
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

/// Cac dap an dang hien tren the (bo qua chip so 1-4), theo dung thu tu.
List<String> _shownOptions(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(MeaningChoiceCard),
        matching: find.byType(Text),
      ),
    )
    .map((t) => t.data ?? '')
    .where((t) => t.isNotEmpty && int.tryParse(t) == null)
    .toList();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('chon nghia: phim 1-4 chon dap an tuong ung', (tester) async {
    final requests = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await _pumpReview(
        tester,
        userId: 11,
        initialMode: AnswerInputMode.choice,
      );

      expect(find.text('Nghĩa của từ này là gì?'), findsOneWidget);
      final options = _shownOptions(tester);
      expect(options.length, 4);

      // Bam "2" -> chon dung lua chon thu 2 (index 1).
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pumpAndSettle();

      // Da lo the dap an + hien 4 nut cham SRS (nhu khi bam chuot).
      expect(find.text('How well did you know it?'), findsOneWidget);
      // Ket qua dung/sai khop voi lua chon thu 2.
      final choseCorrect = _correctMeanings.contains(options[1]);
      expect(
        choseCorrect
            ? find.byIcon(Icons.check_circle_rounded)
            : find.byIcon(Icons.cancel_rounded),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }, () => _buildClient(requests));
  });

  testWidgets('chon nghia: phim 1 sau khi hien dap an = cham Again',
      (tester) async {
    final requests = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await _pumpReview(
        tester,
        userId: 13,
        initialMode: AnswerInputMode.choice,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pumpAndSettle();
      expect(find.text('How well did you know it?'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pumpAndSettle();

      final saved =
          requests.where((r) => r['action'] == 'updateWordReview').toList();
      expect(saved, isNotEmpty);
      final data = saved.last['data'] as Map<String, dynamic>;
      expect(data['correctStreak'], 0);
      expect((data['lapseCount'] as num).toInt(), 1);
      expect(tester.takeException(), isNull);
    }, () => _buildClient(requests));
  });

  testWidgets('go tu: phim 1 sau khi hien dap an van cham Again', (tester) async {
    final requests = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await _pumpReview(
        tester,
        userId: 14,
        initialMode: AnswerInputMode.typing,
      );

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'apple');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('How well did you know it?'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pumpAndSettle();

      final saved =
          requests.where((r) => r['action'] == 'updateWordReview').toList();
      expect(saved, isNotEmpty);
      final data = saved.last['data'] as Map<String, dynamic>;
      expect(data['correctStreak'], 0);
      expect((data['lapseCount'] as num).toInt(), 1);
      // Cho timer 300ms cua _handleAnswerFocusChange chay het truoc khi ket thuc
      // (neu khong Flutter bao "Timer is still pending").
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    }, () => _buildClient(requests));
  });
}
