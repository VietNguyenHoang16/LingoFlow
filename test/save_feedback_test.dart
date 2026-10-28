import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoflow/pages/review_page.dart';
import 'package:lingoflow/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Map<String, dynamic> dueWord() => {
        'id': 11,
        'word': 'apple',
        'meaning': 'quả táo',
        'pronunciation': 'ˈæp.əl',
        'full_details': '',
        'word_type': 'noun',
        'topic_tag': 'food',
        'common_synonyms': 'fruit',
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
    Completer<void>? updateGate,
    bool failUpdate = false,
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
    final headers = {'content-type': 'application/json; charset=utf-8'};
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(body);
      final action = body['action'].toString();
      if (action.startsWith('get')) {
        return http.Response(
          jsonEncode({
            'data': [dueWord()],
          }),
          200,
          headers: headers,
        );
      }
      if (action == 'updateVocabularyWordDetails' ||
          action == 'updateVocabularyWord') {
        if (updateGate != null) await updateGate.future;
        if (failUpdate) {
          return http.Response(
            jsonEncode({'error': 'Server loi'}),
            500,
            headers: headers,
          );
        }
        return http.Response(
          jsonEncode({
            'data': {
              'sentence': 'I eat an apple.',
              'translation': 'Tôi ăn một quả táo.',
              'target': 'apple',
            },
          }),
          200,
          headers: headers,
        );
      }
      return http.Response(jsonEncode({'data': null}), 200, headers: headers);
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

  Future<void> openEditSheet(WidgetTester tester) async {
    await tester.longPress(find.text('quả táo'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chỉnh sửa từ'));
    await tester.pumpAndSettle();
    expect(find.text('Sửa từ & nghĩa'), findsOneWidget);
  }

  testWidgets('sửa từ: Đang lưu khoá thao tác rồi Đã lưu rồi tan', (
    tester,
  ) async {
    final gate = Completer<void>();

    await scenario(
      tester,
      (requests) async {
        await openEditSheet(tester);
        await tester.enterText(
          find.widgetWithText(TextField, 'Nghĩa'),
          'quả táo đỏ',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Trong luc luu: co lop phu, khong mo duoc menu / cham bay.
        expect(find.text('Đang lưu…'), findsOneWidget);
        await tester.longPress(
          find.text('quả táo đỏ'),
          warnIfMissed: false,
        );
        await tester.pump();
        expect(find.text('Chỉnh sửa từ'), findsNothing);

        gate.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Đã lưu'), findsOneWidget);
        expect(find.text('Đang lưu…'), findsNothing);

        await tester.pumpAndSettle();
        expect(find.text('Đã lưu'), findsNothing);
        expect(find.text('quả táo đỏ'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      updateGate: gate,
    );
  });

  testWidgets('sửa từ thất bại: lớp phủ biến mất, không hề báo Đã lưu', (
    tester,
  ) async {
    await scenario(
      tester,
      (requests) async {
        await openEditSheet(tester);
        await tester.enterText(
          find.widgetWithText(TextField, 'Nghĩa'),
          'quả táo đỏ',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
        await tester.pumpAndSettle();

        expect(find.text('Đang lưu…'), findsNothing);
        expect(find.text('Đã lưu'), findsNothing);
        expect(find.textContaining('Lỗi:'), findsOneWidget);
        expect(find.text('quả táo'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      failUpdate: true,
    );
  });
}
