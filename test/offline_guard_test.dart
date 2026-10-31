import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoflow/pages/practice_page.dart';
import 'package:lingoflow/pages/review_page.dart';
import 'package:lingoflow/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const offlineMessage =
      'Khong co ket noi mang. Kiem tra WiFi / mobile data va thu lai.';

  Map<String, dynamic> dueWord() => {
        'id': 11,
        'word': 'apple',
        'meaning': 'quả táo',
        'pronunciation': 'ˈæp.əl',
        'full_details': '',
        'word_type': 'noun',
        'topic_tag': 'food',
        'common_synonyms': '',
        'ease_factor': 2.5,
        'interval_days': 3,
        'correct_streak': 2,
        'review_count': 4,
        'lapse_count': 0,
        'mastery_level': 1,
      };

  Future<void> scenario(
    WidgetTester tester,
    Future<void> Function(List<Map<String, dynamic>> requests) check, {
    required bool Function() isOffline,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );

    final requests = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(body);
      final headers = {
        'content-type': 'application/json; charset=utf-8',
      };
      if (isOffline()) {
        return http.Response(
          jsonEncode({'error': offlineMessage}),
          500,
          headers: headers,
        );
      }
      if (body['action'].toString().startsWith('get')) {
        return http.Response(
          jsonEncode({
            'data': [dueWord()],
          }),
          200,
          headers: headers,
        );
      }
      return http.Response(
        jsonEncode({'data': null}),
        200,
        headers: headers,
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const ReviewPage(userId: 1),
        ),
      );
      await tester.pumpAndSettle();
      await check(requests);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => client);
  }

  testWidgets('mất mạng khi chấm điểm: chặn lại, không mất lượt ôn', (
    tester,
  ) async {
    var offline = false;

    await scenario(
      tester,
      (requests) async {
        await tester.enterText(find.byType(TextField).first, 'aple');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.text('Again'), findsOneWidget);

        offline = true;
        await tester.tap(find.text('Good'));
        await tester.pumpAndSettle();

        // Khong duoc di tiep nhu the da luu: the van o day, co hop thoai chan.
        expect(find.text('Mất kết nối mạng'), findsOneWidget);
        expect(find.text('Good'), findsOneWidget);
        expect(find.text('Review Complete!'), findsNothing);
        expect(
          requests.where((r) => r['action'] == 'updateWordReview').length,
          1,
        );

        // Co mang lai -> "Thử lại" luu dung luot do roi moi di tiep.
        offline = false;
        await tester.tap(find.text('Thử lại'));
        await tester.pumpAndSettle();

        expect(find.text('Mất kết nối mạng'), findsNothing);
        expect(find.text('Review Complete!'), findsOneWidget);
        expect(
          requests.where((r) => r['action'] == 'updateWordReview').length,
          2,
        );
        expect(tester.takeException(), isNull);
      },
      isOffline: () => offline,
    );
  });

  testWidgets('luyện tập mất mạng: câu trả lời không bị mất, chặn và thử lại', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );

    var offline = true;
    final requests = <Map<String, dynamic>>[];
    final headers = {'content-type': 'application/json; charset=utf-8'};
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(body);
      if (offline) {
        return http.Response(
          jsonEncode({'error': offlineMessage}),
          500,
          headers: headers,
        );
      }
      return http.Response(jsonEncode({'data': null}), 200, headers: headers);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PracticePage(
            listId: 1,
            listName: 'Set',
            userId: 1,
            studyMode: false,
            preloadedWords: [dueWord()],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'apple');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Mất kết nối mạng'), findsOneWidget);

      offline = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Mất kết nối mạng'), findsNothing);
      expect(
        requests.where((r) => r['action'] == 'updateWordReview').length,
        2,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => client);
  });

  testWidgets('mở ôn tập khi mất mạng: báo cần kết nối, không phải hết việc', (
    tester,
  ) async {
    var offline = true;

    await scenario(
      tester,
      (requests) async {
        expect(find.text('Cần kết nối mạng'), findsOneWidget);
        expect(find.text('All caught up!'), findsNothing);

        offline = false;
        await tester.tap(find.text('Thử lại'));
        await tester.pumpAndSettle();

        expect(find.text('Cần kết nối mạng'), findsNothing);
        expect(find.text('Check answer'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      isOffline: () => offline,
    );
  });
}
