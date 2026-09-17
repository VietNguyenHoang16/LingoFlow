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
  Future<void> scenario(
    WidgetTester tester,
    Future<void> Function(List<Map<String, dynamic>> requests) check, {
    bool failDelete = false,
    bool grammar = false,
    bool multiple = false,
    Completer<void>? deletionGate,
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
              if (multiple)
                {
                  'id': 12,
                  'word': 'pear',
                  'meaning': 'quả lê',
                  'ease_factor': 2.5,
                },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (body['action'] == 'deleteVocabularyWord' && deletionGate != null) {
        await deletionGate.future;
      }
      if (failDelete && body['action'] == 'deleteVocabularyWord') {
        return http.Response(jsonEncode({'error': 'Offline'}), 500);
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

  Future<void> openDelete(WidgetTester tester) async {
    await tester.longPress(find.text('quả táo'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa từ'), findsOneWidget);
    await tester.tap(find.text('Xóa từ'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa từ này?'), findsOneWidget);
  }

  testWidgets('delete stays hidden; tap and cancel preserve answer', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      expect(find.text('Xóa từ'), findsNothing);
      await tester.enterText(find.byType(TextField), 'ap');
      await tester.tap(find.text('quả táo'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa từ'), findsNothing);
      await openDelete(tester);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('ap'), findsOneWidget);
      expect(
        requests.where((r) => r['action'] == 'deleteVocabularyWord'),
        isEmpty,
      );
    });
  });

  testWidgets('delete final word finishes without recording review', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      await openDelete(tester);
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();
      expect(find.text('Review Complete!'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(requests.where((r) => r['action'] == 'updateWordReview'), isEmpty);
      final deletion = requests.singleWhere(
        (r) => r['action'] == 'deleteVocabularyWord',
      );
      expect(deletion['data'], {'wordId': 11});
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('failed delete preserves word and input for retry', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      await tester.enterText(find.byType(TextField), 'ap');
      await openDelete(tester);
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();
      expect(find.text('quả táo'), findsOneWidget);
      expect(find.text('ap'), findsOneWidget);
      expect(find.textContaining('Không thể xóa'), findsOneWidget);
      expect(find.text('Review Complete!'), findsNothing);
      await openDelete(tester);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, failDelete: true);
  });

  testWidgets('delete advances to remaining word without skipping it', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      final firstIsApple = find.text('quả táo').evaluate().isNotEmpty;
      final firstMeaning = firstIsApple ? 'quả táo' : 'quả lê';
      final nextMeaning = firstIsApple ? 'quả lê' : 'quả táo';
      await tester.longPress(find.text(firstMeaning));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa từ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();
      expect(find.text(nextMeaning), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.text('Review Complete!'), findsNothing);
      expect(requests.where((r) => r['action'] == 'updateWordReview'), isEmpty);
    }, multiple: true);
  });

  testWidgets('keyboard opens hidden menu and dismissal never deletes', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.text('Xóa từ'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Xóa từ'), findsNothing);
      expect(
        requests.where((r) => r['action'] == 'deleteVocabularyWord'),
        isEmpty,
      );
    });
  });

  testWidgets('pending delete blocks ratings and duplicate requests', (
    tester,
  ) async {
    final gate = Completer<void>();
    await scenario(
      tester,
      (requests) async {
        await tester.tap(find.text('Show answer'));
        await tester.pumpAndSettle();
        await openDelete(tester);
        await tester.tap(find.text('Xóa'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
        await tester.longPress(find.text('quả táo'), warnIfMissed: false);
        await tester.pump();
        expect(
          requests.where((r) => r['action'] == 'deleteVocabularyWord').length,
          1,
        );
        expect(
          requests.where((r) => r['action'] == 'updateWordReview'),
          isEmpty,
        );
        gate.complete();
        await tester.pumpAndSettle();
        expect(find.text('Review Complete!'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      grammar: true,
      deletionGate: gate,
    );
  });

  testWidgets('Again repeat is removed, not rated again by deletion', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await openDelete(tester);
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();
      expect(find.text('Review Complete!'), findsOneWidget);
      expect(
        requests.where((r) => r['action'] == 'updateWordReview').length,
        1,
      );
      expect(tester.takeException(), isNull);
    }, grammar: true);
  });
}
