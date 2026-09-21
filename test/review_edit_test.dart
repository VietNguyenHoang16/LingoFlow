import 'dart:async';
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

void main() {
  /// Mock ca API app lan dictionaryapi.dev: request tu dien duoc ghi lai voi
  /// action 'dictionary' de test kiem tra co/khong goi mang.
  Future<void> scenario(
    WidgetTester tester,
    Future<void> Function(List<Map<String, dynamic>> requests) check, {
    bool failUpdate = false,
    bool dictionaryMissing = false,
    Completer<void>? updateGate,
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
      if (request.url.host == 'api.dictionaryapi.dev') {
        requests.add({'action': 'dictionary', 'url': request.url.toString()});
        if (dictionaryMissing) return http.Response('{}', 404);
        return http.Response(
          jsonEncode([
            {
              'phonetics': [
                {'text': '/ˈæp.əl/', 'audio': ''},
              ],
              'meanings': [
                {
                  'partOfSpeech': 'noun',
                  'definitions': [
                    {
                      'definition': 'A round fruit.',
                      'example': 'I ate an apple.',
                    },
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
      if (body['action'].toString().startsWith('get')) {
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 11,
                'word': 'apple',
                'meaning': 'quả táo',
                'pronunciation': 'ˈæp.əl',
                'full_details': '',
                'word_type': 'noun',
                'topic_tag': 'food',
                'common_synonyms': 'fruit',
                'ease_factor': 2.5,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (updateGate != null && body['action'] == 'updateVocabularyWord') {
        await updateGate.future;
      }
      if (failUpdate &&
          (body['action'] == 'updateVocabularyWord' ||
              body['action'] == 'updateVocabularyWordDetails')) {
        return http.Response(jsonEncode({'error': 'Offline'}), 500);
      }
      return http.Response('{"data":null}', 200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ReviewPage(userId: 1),
        ),
      );
      await tester.pumpAndSettle();
      await check(requests);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => client);
  }

  Iterable<Map<String, dynamic>> actions(
    List<Map<String, dynamic>> requests,
    String action,
  ) =>
      requests.where((r) => r['action'] == action);

  /// Mo menu an bang nhan giu the roi chon "Chinh sua tu".
  Future<void> openEdit(WidgetTester tester) async {
    await tester.longPress(find.text('quả táo'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Chỉnh sửa từ'), findsOneWidget);
    expect(find.text('Xóa từ'), findsOneWidget);
    await tester.tap(find.text('Chỉnh sửa từ'));
    await tester.pumpAndSettle();
    expect(find.text('Sửa từ & nghĩa'), findsOneWidget);
  }

  Finder dialogWordField() => find.widgetWithText(TextField, 'Từ');
  Finder dialogMeaningField() => find.widgetWithText(TextField, 'Nghĩa');

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
  }

  /// Go dap an sai roi mo the dap an (de co AnswerDiffText + o nhap da go).
  Future<void> answerWrong(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, 'aple');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(AnswerDiffText), findsOneWidget);
  }

  testWidgets('menu an chi hien khi nhan giu va co ca sua lan xoa', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      expect(find.text('Chỉnh sửa từ'), findsNothing);
      expect(find.text('Xóa từ'), findsNothing);

      await tester.longPress(find.text('quả táo'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Chỉnh sửa từ'), findsOneWidget);
      expect(find.text('Xóa từ'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Chỉnh sửa từ'), findsNothing);
      expect(
        requests.where((r) => !r['action'].toString().startsWith('get')),
        isEmpty,
      );
    });
  });

  testWidgets('Shift+F10 mo menu co ca hai muc', (tester) async {
    await scenario(tester, (requests) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.text('Chỉnh sửa từ'), findsOneWidget);
      expect(find.text('Xóa từ'), findsOneWidget);
    });
  });

  testWidgets('sua nghia: chi cap nhat nghia, khong goi tu dien, giu dap an', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      await answerWrong(tester);

      await openEdit(tester);
      await tester.enterText(dialogMeaningField(), 'quả táo đỏ');
      await save(tester);

      final detail = actions(requests, 'updateVocabularyWordDetails').single;
      expect((detail['data'] as Map)['wordId'], 11);
      expect((detail['data'] as Map)['meaning'], 'quả táo đỏ');
      expect(actions(requests, 'updateVocabularyWord'), isEmpty);
      expect(actions(requests, 'dictionary'), isEmpty);
      expect(actions(requests, 'deleteVocabularyWord'), isEmpty);

      // The hien ngay nghia moi, van o the dap an voi dau sai da to.
      expect(find.text('quả táo đỏ'), findsOneWidget);
      expect(find.text('How well did you know it?'), findsOneWidget);
      expect(find.byType(AnswerDiffText), findsOneWidget);
      expect(find.textContaining('Đã cập nhật nghĩa'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('doi tu: lay phat am + chi tiet + loai tu va luu day du', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      await openEdit(tester);
      await tester.enterText(dialogWordField(), 'apples');
      await tester.enterText(dialogMeaningField(), 'những quả táo');
      await save(tester);

      final dictionary = actions(requests, 'dictionary').single;
      expect((dictionary['url'] as String).contains('/en/apples'), isTrue);

      final update = actions(requests, 'updateVocabularyWord').single;
      final data = update['data'] as Map<String, dynamic>;
      expect(data['wordId'], 11);
      expect(data['word'], 'apples');
      expect(data['meaning'], 'những quả táo');
      expect(data['pronunciation'], 'ˈæp.əl');
      expect(data['wordType'], 'noun');
      expect(data['topicTag'], 'food');
      expect(data['commonSynonyms'], 'fruit');
      expect(
        data['fullDetails'],
        'noun: [{definition: A round fruit., example: I ate an apple.}]',
      );
      expect(actions(requests, 'updateVocabularyWordDetails'), isEmpty);
      expect(actions(requests, 'deleteVocabularyWord'), isEmpty);

      expect(find.text('những quả táo'), findsOneWidget);
      expect(find.textContaining('từ từ điển'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('doi tu: dap an da go va dau sai duoc reset', (tester) async {
    await scenario(tester, (requests) async {
      await answerWrong(tester);

      await openEdit(tester);
      await tester.enterText(dialogWordField(), 'apples');
      await save(tester);

      expect(actions(requests, 'updateVocabularyWord'), hasLength(1));
      expect(find.byType(AnswerDiffText), findsNothing);
      expect(find.text('aple'), findsNothing);
      expect(find.text('Check answer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('tu khong co trong tu dien: van luu tu + nghia', (tester) async {
    await scenario(
      tester,
      (requests) async {
        await openEdit(tester);
        await tester.enterText(dialogWordField(), 'zzzzz');
        await tester.enterText(dialogMeaningField(), 'nghĩa mới');
        await save(tester);

        expect(actions(requests, 'dictionary'), hasLength(1));
        final data = actions(requests, 'updateVocabularyWord').single['data']
            as Map<String, dynamic>;
        expect(data['word'], 'zzzzz');
        expect(data['meaning'], 'nghĩa mới');
        // Khong co du lieu moi -> giu nguyen phat am / loai tu cu.
        expect(data['pronunciation'], 'ˈæp.əl');
        expect(data['wordType'], 'noun');
        expect(data['fullDetails'], '');
        expect(find.text('nghĩa mới'), findsOneWidget);
        expect(find.textContaining('chưa lấy được'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      dictionaryMissing: true,
    );
  });

  testWidgets('huy dialog: khong goi API, giu nguyen du lieu va o nhap', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      await tester.enterText(find.byType(TextField).first, 'ap');
      await tester.pumpAndSettle();

      await openEdit(tester);
      await tester.enterText(dialogWordField(), 'apples');
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();

      expect(actions(requests, 'updateVocabularyWord'), isEmpty);
      expect(actions(requests, 'updateVocabularyWordDetails'), isEmpty);
      expect(actions(requests, 'dictionary'), isEmpty);
      expect(find.text('quả táo'), findsOneWidget);
      expect(find.text('ap'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('luu that bai: rollback du lieu va hien loi', (tester) async {
    await scenario(
      tester,
      (requests) async {
        await openEdit(tester);
        await tester.enterText(dialogWordField(), 'apples');
        await tester.enterText(dialogMeaningField(), 'những quả táo');
        await save(tester);

        expect(find.textContaining('Lỗi:'), findsOneWidget);
        expect(find.text('quả táo'), findsOneWidget);
        expect(find.text('những quả táo'), findsNothing);
        expect(find.text('Check answer'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      failUpdate: true,
    );
  });

  testWidgets('dang luu: chan cham diem va nhan giu lan hai', (tester) async {
    final gate = Completer<void>();
    await scenario(
      tester,
      (requests) async {
        await openEdit(tester);
        await tester.enterText(dialogWordField(), 'apples');
        await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
        await tester.longPress(find.text('quả táo'), warnIfMissed: false);
        await tester.pump();
        expect(actions(requests, 'updateVocabularyWord'), hasLength(1));
        expect(actions(requests, 'updateWordReview'), isEmpty);

        gate.complete();
        await tester.pumpAndSettle();
        // Luu xong: bao thanh cong, nghia khong doi (chi doi Tu).
        expect(find.textContaining('Đã cập nhật "apples"'), findsOneWidget);
        expect(find.text('quả táo'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      updateGate: gate,
    );
  });
}
