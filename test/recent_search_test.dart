import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoflow/pages/recent_page.dart';
import 'package:lingoflow/theme/app_theme.dart';
import 'package:lingoflow/widgets/flip_word_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> wordRow({
  required int id,
  required String word,
  required String meaning,
  String wordType = 'noun',
}) =>
    {
      'id': id,
      'word': word,
      'meaning': meaning,
      'pronunciation': 'ˈx',
      'full_details': '',
      'word_type': wordType,
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
      'example_sentence': '',
      'example_translation': '',
      'example_target': '',
      'created_at': '2026-10-20T10:00:00.000Z',
      'list_name': 'Noun',
      'list_id': 3,
    };

const _recentLimit = 20;

void main() {
  /// Danh sách "gần nhất" chỉ có 20 từ, còn searchWord quét toàn bộ (có zebra).
  Future<void> scenario(
    WidgetTester tester,
    Future<void> Function(List<Map<String, dynamic>> requests) check,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );

    final recent = [
      for (var i = 0; i < _recentLimit; i++)
        wordRow(id: i + 1, word: 'word$i', meaning: 'nghĩa $i'),
    ];
    final all = [
      ...recent,
      wordRow(id: 99, word: 'zebra', meaning: 'ngựa vằn'),
    ];

    final requests = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.url.host == 'api.dictionaryapi.dev') {
        return http.Response(
          jsonEncode([
            {
              'phonetics': [
                {'text': '/ˈziː.brə/', 'audio': ''},
              ],
              'meanings': [
                {
                  'partOfSpeech': 'noun',
                  'definitions': [
                    {'definition': 'An animal.', 'example': ''},
                  ],
                },
              ],
            },
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(body);
      final data = body['data'] as Map<String, dynamic>? ?? const {};
      switch (body['action']) {
        case 'getRecentWords':
          return http.Response(jsonEncode({'data': recent}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        case 'getDashboardStats':
          return http.Response(
            jsonEncode({
              'data': {
                'categoryStats': {},
                'reviewStats': {'dueToday': 0, 'grammarDue': 0, 'totalWords': 21},
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        case 'searchWord':
          final q = (data['query'] as String).toLowerCase();
          final matches = all
              .where((w) =>
                  (w['word'] as String).toLowerCase().contains(q) ||
                  (w['meaning'] as String).toLowerCase().contains(q))
              .toList();
          return http.Response(jsonEncode({'data': matches}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        case 'enrichWords':
          final words = (data['words'] as List).cast<String>();
          return http.Response(
            jsonEncode({
              'data': [
                for (final w in words)
                  {'word': w, 'meaning': 'nghĩa AI của $w', 'wordType': 'verb'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        case 'updateVocabularyWord':
          final target = (data['word'] ?? '').toString();
          // Giả lập DB: lần search sau trả về dữ liệu đã sửa.
          final index = all.indexWhere((w) => w['id'] == data['wordId']);
          if (index != -1) {
            all[index] = {
              ...all[index],
              'word': data['word'],
              'meaning': data['meaning'],
              'pronunciation': data['pronunciation'],
              'word_type': data['wordType'],
              'common_synonyms': data['commonSynonyms'],
            };
          }
          return http.Response(
            jsonEncode({
              'data': {
                'sentence': 'I saw a $target today.',
                'translation': 'Hôm nay tôi thấy $target.',
                'target': target,
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
      }
      return http.Response('{"data":null}', 200);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: RecentPage(userId: 1)),
      );
      await tester.pumpAndSettle();
      await check(requests);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => client);
  }

  /// Text trong card kết quả (ô tìm kiếm cũng chứa cùng chữ nên phải giới hạn).
  Finder cardWith(String text) => find.descendant(
        of: find.byType(FlipWordCard),
        matching: find.text(text),
      );

  Future<void> typeSearch(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField).first, query);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  testWidgets('tìm kiếm quét toàn bộ từ đã lưu, không chỉ 20 từ gần nhất', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      expect(find.text('word0'), findsOneWidget);
      expect(find.text('zebra'), findsNothing);

      await typeSearch(tester, 'zebra');

      expect(cardWith('zebra'), findsOneWidget);
      final search =
          requests.where((r) => r['action'] == 'searchWord').toList();
      expect(search, isNotEmpty);
      expect((search.first['data'] as Map)['query'], 'zebra');
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('tìm theo nghĩa cũng ra từ nằm ngoài 20 từ gần nhất', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      await typeSearch(tester, 'ngựa');

      expect(cardWith('zebra'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('sửa từ ngay trong kết quả tìm: AI lấy nghĩa + loại từ', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      await typeSearch(tester, 'zebra');
      expect(cardWith('zebra'), findsOneWidget);

      await tester.longPress(cardWith('zebra'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chinh sua / them nhan'));
      await tester.pumpAndSettle();
      expect(find.text('Chỉnh sửa từ'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Từ'), 'zebras');
      await tester.enterText(find.widgetWithText(TextField, 'Nghĩa'), '');
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();

      final enrich =
          requests.where((r) => r['action'] == 'enrichWords').toList();
      expect(enrich, isNotEmpty);
      expect(
        ((enrich.first['data'] as Map)['words'] as List),
        ['zebras'],
      );

      final update =
          requests.where((r) => r['action'] == 'updateVocabularyWord').toList();
      expect(update, hasLength(1));
      final data = update.single['data'] as Map<String, dynamic>;
      expect(data['word'], 'zebras');
      expect(data['meaning'], 'nghĩa AI của zebras');
      expect(data['wordType'], 'verb');
      expect(data['pronunciation'], 'ˈziː.brə');

      // Mặt trước card chỉ có từ; lật card mới thấy nghĩa mới.
      await tester.tap(cardWith('zebras'));
      await tester.pumpAndSettle();
      expect(find.text('nghĩa AI của zebras'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('chạm từ đầu rồi chạm từ cuối chọn cả khoảng', (tester) async {
    await scenario(tester, (requests) async {
      await tester.tap(find.byTooltip('Luyện tập'));
      await tester.pumpAndSettle();

      // Chạm đầu tiên chỉ chọn đúng một từ.
      await tester.tap(find.text('word0'));
      await tester.pumpAndSettle();
      expect(find.text('Luyện tập (1)'), findsOneWidget);

      // Chạm từ cuối -> chọn luôn cả khoảng ở giữa.
      await tester.tap(find.text('word2'));
      await tester.pumpAndSettle();
      expect(find.text('Luyện tập (3)'), findsOneWidget);

      // Chạm lại một từ đã chọn -> chỉ bỏ đúng từ đó.
      await tester.tap(find.text('word1'));
      await tester.pumpAndSettle();
      expect(find.text('Luyện tập (2)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
