import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoflow/pages/review_page.dart';
import 'package:lingoflow/theme/app_theme.dart';
import 'package:lingoflow/widgets/answer_diff_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _mismatch = Color(0xFFFFD54F);

/// Flatten toàn bộ span (kể cả span lồng nhau) để kiểm tra style từng ký tự.
List<TextSpan> _allSpans(WidgetTester tester, {required String plainText}) {
  final spans = <TextSpan>[];
  void walk(InlineSpan span) {
    if (span is TextSpan) {
      spans.add(span);
      for (final child in span.children ?? const <InlineSpan>[]) {
        walk(child);
      }
    }
  }

  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    if (rich.text.toPlainText() == plainText) walk(rich.text);
  }
  return spans;
}

bool _hasStyledChar(
  WidgetTester tester, {
  required String plainText,
  required String char,
  required TextDecoration decoration,
}) =>
    _allSpans(tester, plainText: plainText).any((s) =>
        (s.text ?? '').contains(char) &&
        s.style?.decoration == decoration &&
        s.style?.color == _mismatch);

void main() {
  Future<void> scenario(
    WidgetTester tester,
    Future<void> Function(List<Map<String, dynamic>> requests) check, {
    bool grammar = false,
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

  Future<void> checkAnswer(WidgetTester tester, String typed) async {
    await tester.enterText(find.byType(TextField), typed);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets('go thieu 1 chu -> chu thieu tren the dap an duoc to do', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      await checkAnswer(tester, 'aple');

      expect(find.byType(AnswerDiffText), findsOneWidget);
      expect(find.text('How well did you know it?'), findsOneWidget);
      expect(
        _hasStyledChar(
          tester,
          plainText: 'apple',
          char: 'p',
          decoration: TextDecoration.underline,
        ),
        isTrue,
      );
      // Chu dung vi tri khong bi to.
      expect(
        _hasStyledChar(
          tester,
          plainText: 'apple',
          char: 'l',
          decoration: TextDecoration.underline,
        ),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('go thua 1 chu -> dong You typed bi gach ngang', (tester) async {
    await scenario(tester, (requests) async {
      await checkAnswer(tester, 'appple');

      expect(
        _hasStyledChar(
          tester,
          plainText: 'You typed: appple',
          char: 'p',
          decoration: TextDecoration.lineThrough,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('go dung -> khong to gi them', (tester) async {
    await scenario(tester, (_) async {
      await checkAnswer(tester, 'Apple');

      expect(find.byType(AnswerDiffText), findsNothing);
      expect(find.text('apple'), findsOneWidget);
      expect(find.textContaining('You typed'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('nhap rong roi Check -> khong to do, khong co dong You typed', (
    tester,
  ) async {
    await scenario(tester, (_) async {
      await tester.tap(find.text('Check answer'));
      await tester.pumpAndSettle();

      expect(find.byType(AnswerDiffText), findsNothing);
      expect(find.textContaining('You typed'), findsNothing);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      expect(find.text('How well did you know it?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('tra loi khac han dap an -> khong to gi, hien nhu cu', (
    tester,
  ) async {
    await scenario(tester, (_) async {
      await checkAnswer(tester, 'dog');

      expect(find.byType(AnswerDiffText), findsNothing);
      expect(find.text('apple'), findsOneWidget);
      expect(find.text('You typed: dog'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('grammar review -> khong to dau sai nao', (tester) async {
    await scenario(tester, (_) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('How well did you know it?'), findsOneWidget);
      expect(find.byType(AnswerDiffText), findsNothing);
      expect(tester.takeException(), isNull);
    }, grammar: true);
  });

  testWidgets('cham diem Again -> dau sai duoc xoa cung the dap an', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      await checkAnswer(tester, 'aple');
      expect(find.byType(AnswerDiffText), findsOneWidget);

      await tester.tap(find.text('Again'));
      await tester.pumpAndSettle();

      expect(find.byType(AnswerDiffText), findsNothing);
      expect(
        requests.where((r) => r['action'] == 'updateWordReview'),
        isNotEmpty,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('long-press the van mo duoc xoa tu khi dang to dau sai', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      await checkAnswer(tester, 'aple');
      expect(find.byType(AnswerDiffText), findsOneWidget);

      await tester.longPress(find.text('quả táo'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Xóa từ'), findsOneWidget);

      await tester.tap(find.text('Xóa từ'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa từ này?'), findsOneWidget);

      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      // Huy xoa -> giu nguyen cau tra loi + dau sai, khong goi API xoa.
      expect(find.byType(AnswerDiffText), findsOneWidget);
      expect(requests.where((r) => r['action'] == 'deleteVocabularyWord'),
          isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}