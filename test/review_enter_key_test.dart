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
  Future<void> scenario(
    WidgetTester tester,
    Future<void> Function(List<Map<String, dynamic>> requests) check, {
    bool grammar = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 1200);
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
      if (body['action'].toString().startsWith('get')) {
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 11,
                'word': 'apple',
                'meaning': 'quả táo',
                'ease_factor': 2.5,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{"data":null}', 200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ReviewPage(userId: 1, grammarReview: grammar),
        ),
      );
      await tester.pumpAndSettle();
      await check(requests);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => client);
  }

  testWidgets('grammar review: Enter shows the answer card', (tester) async {
    await scenario(tester, (requests) async {
      expect(find.text('Show answer'), findsOneWidget);
      expect(find.text('How well did you know it?'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('Show answer'), findsNothing);
      expect(find.text('How well did you know it?'), findsOneWidget);
      // Enter chi mo the dap an, chua cham diem SRS nao.
      expect(requests.where((r) => r['action'] == 'updateWordReview'), isEmpty);
    }, grammar: true);
  });

  testWidgets('grammar review: Enter again while answer is open is a no-op', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('How well did you know it?'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Van o the dap an, Enter lan 2 khong cham diem / khong nhan the.
      expect(find.text('Review Complete!'), findsNothing);
      expect(requests.where((r) => r['action'] == 'updateWordReview'), isEmpty);
    }, grammar: true);
  });

  testWidgets('normal review: Enter in the input still shows the answer', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'apple');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('How well did you know it?'), findsOneWidget);
    });
  });
}
