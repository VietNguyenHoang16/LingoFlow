import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoflow/pages/mode_migration_page.dart';
import 'package:lingoflow/pages/passive_review_page.dart';
import 'package:lingoflow/pages/recent_page.dart';
import 'package:lingoflow/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> word({
  required int id,
  required String word,
  required String meaning,
  String mode = 'active',
  int reviewCount = 0,
}) =>
    {
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
      'review_count': reviewCount,
      'correct_streak': 0,
      'ease_factor': 2.5,
      'interval_days': 0,
      'next_review_date': null,
      'last_reviewed_at': null,
      'mastery_level': 0,
      'lapse_count': 0,
      'learning_mode': mode,
      'collocations': mode == 'active' ? 'comply with' : '',
      'example_sentence': 'This is an example.',
      'example_translation': 'Đây là ví dụ.',
      'example_target': word,
      'created_at': '2026-10-20T10:00:00.000Z',
      'list_name': 'Noun',
      'list_id': 3,
    };

Future<void> _pumpApp(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: home));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('trang chính: 2 tab Học ngay / Nên biết lọc đúng danh sách', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );

    final active = [word(id: 1, word: 'deploy', meaning: 'triển khai')];
    final passive = [word(id: 2, word: 'chancellor', meaning: 'thủ tướng', mode: 'passive')];
    final requests = <Map<String, dynamic>>[];

    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(body);
      final data = body['data'] as Map<String, dynamic>? ?? const {};
      switch (body['action']) {
        case 'getRecentWords':
          final mode = (data['mode'] ?? 'all').toString();
          final rows = mode == 'passive' ? passive : active;
          return http.Response(jsonEncode({'data': rows}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        case 'getDashboardStats':
          return http.Response(
            jsonEncode({
              'data': {
                'categoryStats': {},
                'reviewStats': {
                  'dueToday': 1,
                  'grammarDue': 0,
                  'passiveDue': 1,
                  'totalWords': 2,
                  'breakdown': {},
                },
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        case 'setWordLearningMode':
          return http.Response('{"data":null}', 200);
      }
      return http.Response('{"data":null}', 200);
    });

    await http.runWithClient(() async {
      await _pumpApp(tester, const RecentPage(userId: 1));

      expect(find.text('deploy'), findsOneWidget);
      expect(find.text('Học ngay'), findsWidgets);
      // Nút ôn nhẹ hiện vì có 1 từ Nên biết đến hạn.
      expect(find.text('Gặp lại nhẹ'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('mode-tab-passive')));
      await tester.pumpAndSettle();
      expect(find.text('chancellor'), findsOneWidget);
      expect(find.text('deploy'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('mode-tab-active')));
      await tester.pumpAndSettle();
      expect(find.text('deploy'), findsOneWidget);

      // Đổi loại qua menu dài trên thẻ.
      await tester.longPress(find.text('deploy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chuyển sang Nên biết'));
      await tester.pumpAndSettle();

      final modeCalls =
          requests.where((r) => r['action'] == 'setWordLearningMode').toList();
      expect(modeCalls, hasLength(1));
      expect((modeCalls.single['data'] as Map)['mode'], 'passive');
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('ôn Nên biết: chọn đáp án đúng -> lưu lịch 1 ngày, mastery 0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );

    final passive = [
      word(
        id: 2,
        word: 'chancellor',
        meaning: 'thủ tướng',
        mode: 'passive',
        reviewCount: 0,
      ),
    ];
    final pool = [
      ...passive,
      word(id: 3, word: 'apple', meaning: 'quả táo'),
      word(id: 4, word: 'deploy', meaning: 'triển khai'),
      word(id: 5, word: 'resilient', meaning: 'kiên cường'),
    ];
    final requests = <Map<String, dynamic>>[];

    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(body);
      switch (body['action']) {
        case 'getPassiveDueWords':
          return http.Response(jsonEncode({'data': passive}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        case 'getVocabularyWords':
          return http.Response(jsonEncode({'data': pool}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        case 'updateWordReview':
          return http.Response('{"data":null}', 200);
      }
      return http.Response('{"data":null}', 200);
    });

    await http.runWithClient(() async {
      await _pumpApp(tester, const PassiveReviewPage(userId: 1));

      expect(find.text('chancellor'), findsOneWidget);
      await tester.tap(find.text('thủ tướng'));
      await tester.pumpAndSettle();

      expect(find.text('Đúng rồi!'), findsOneWidget);
      expect(find.text('Gặp lại sau 1 ngày'), findsOneWidget);

      final updates =
          requests.where((r) => r['action'] == 'updateWordReview').toList();
      expect(updates, hasLength(1));
      final data = updates.single['data'] as Map<String, dynamic>;
      expect(data['intervalDays'], 1);
      expect(data['masteryLevel'], 0);
      expect(data['reviewCount'], 1);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('phân loại: nút 2 bên, copy 20 từ, nộp xong từ không hiện lại', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final batch = [
      word(id: 1, word: 'deploy', meaning: 'triển khai', mode: ''),
      word(id: 2, word: 'chancellor', meaning: 'thủ tướng', mode: ''),
    ];
    final requests = <Map<String, dynamic>>[];
    final clipboard = <String>[];
    var submitted = false;

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map;
          clipboard.add(args['text'] as String);
        }
        return null;
      },
    );

    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(body);
      switch (body['action']) {
        case 'getUnclassifiedWords':
          return http.Response(
            jsonEncode({
              'data': submitted
                  ? {'items': [], 'remaining': 0, 'total': 2}
                  : {'items': batch, 'remaining': 2, 'total': 2},
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        case 'bulkClassifyWords':
          submitted = true;
          return http.Response(
            jsonEncode({'data': {'updatedCount': 2}}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
      }
      return http.Response('{"data":null}', 200);
    });

    await http.runWithClient(() async {
      await _pumpApp(tester, const ModeMigrationPage(userId: 1));

      expect(find.textContaining('Còn 2/2 từ chưa phân loại'), findsOneWidget);
      expect(find.text('deploy'), findsOneWidget);
      expect(find.text('chancellor'), findsOneWidget);

      // Bấm nút lớn 2 bên cho từng từ.
      await tester.tap(find.byKey(const ValueKey('classify-active-1')));
      await tester.tap(find.byKey(const ValueKey('classify-passive-2')));
      await tester.pumpAndSettle();
      expect(find.text('Đã chọn 2/2 từ'), findsOneWidget);

      // Copy nhanh 20 từ (chỉ từ tiếng Anh, cách nhau dấu phẩy).
      await tester.tap(find.byKey(const ValueKey('classify-copy')));
      await tester.pumpAndSettle();
      expect(clipboard, isNotEmpty);
      expect(clipboard.last, 'deploy, chancellor');

      // Cho SnackBar copy tự ẩn để không che nút Nộp.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Nộp lô: gửi đúng 2 từ + loại đã chọn.
      await tester.tap(find.byKey(const ValueKey('classify-submit')));
      await tester.pumpAndSettle();

      final bulk = requests
          .where((r) => r['action'] == 'bulkClassifyWords')
          .toList();
      expect(bulk, hasLength(1));
      final items = (bulk.single['data'] as Map)['items'] as List;
      expect(items, hasLength(2));
      expect(
        {for (final it in items) (it as Map)['id']: it['mode']},
        {1: 'active', 2: 'passive'},
      );

      // Nộp xong server trả lô rỗng -> từ đã có trạng thái không hiện lại.
      expect(find.text('deploy'), findsNothing);
      expect(find.text('Đã phân loại tất cả từ!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
