import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoflow/widgets/bulk_import_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bước phân tích có progress bar chạy vô hạn nên không dùng pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  Future<void> scenario(
    WidgetTester tester,
    Future<void> Function(List<Map<String, dynamic>> requests) check, {
    List<Map<String, dynamic>> existingWords = const [],
    Completer<void>? holdBulk,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final requests = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.url.host == 'api.dictionaryapi.dev') {
        return http.Response(
          jsonEncode([
            {
              'phonetics': [
                {'text': '/ˈæp.əl/', 'audio': ''},
              ],
              'meanings': [],
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
        case 'filterExistingWordsDetailed':
          return http.Response(
            jsonEncode({'data': existingWords}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        case 'filterExistingWords':
          return http.Response(
            jsonEncode({'data': []}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        case 'enrichWords':
          final words = (data['words'] as List).cast<String>();
          return http.Response(
            jsonEncode({
              'data': [
                for (final w in words)
                  if (w.toLowerCase() == 'zzzzz')
                    {
                      'word': w,
                      'meaning': '',
                      'wordType': '',
                      'error': 'AI không lấy được nghĩa cho từ này.',
                    }
                  else
                    {
                      'word': w,
                      'meaning': 'nghĩa của $w',
                      'wordType': 'noun',
                      'learningMode':
                          w.toLowerCase() == 'resilient' ? 'passive' : 'active',
                      'collocations':
                          w.toLowerCase() == 'apple' ? 'an apple a day' : '',
                    },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        case 'bulkAddWords':
          if (holdBulk != null) await holdBulk.future;
          final words = data['words'] as List;
          return http.Response(
            jsonEncode({
              'data': {'insertedCount': words.length, 'failed': []},
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
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => BulkImportDialog.show(ctx, userId: 1),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await check(requests);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => client);
  }

  testWidgets('dan tu phay: AI dien nghia + loai tu roi import', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      await tester.enterText(find.byType(TextField), 'apple, resilient');
      await tester.tap(find.text('Phân tích bằng AI'));
      await _settle(tester);

      // Preview hien nghia + loai tu AI dien.
      expect(find.text('apple'), findsOneWidget);
      expect(find.text('nghĩa của apple'), findsOneWidget);
      expect(find.text('nghĩa của resilient'), findsOneWidget);
      expect(find.text('Import 2 từ'), findsOneWidget);

      await tester.tap(find.text('Import 2 từ'));
      await tester.pumpAndSettle();

      final bulk = requests.where((r) => r['action'] == 'bulkAddWords').toList();
      final sent = bulk
          .expand((r) => ((r['data'] as Map)['words'] as List))
          .cast<Map<String, dynamic>>()
          .toList();
      expect(sent, hasLength(2));
      expect(sent.map((w) => w['meaning']), [
        'nghĩa của apple',
        'nghĩa của resilient',
      ]);
      expect(sent.every((w) => w['wordType'] == 'noun'), isTrue);
      expect(find.text('Đã thêm 2 từ.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('AI gan Hoc ngay / Nen biet + cum tu, import gui dung loai', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      await tester.enterText(find.byType(TextField), 'apple, resilient');
      await tester.tap(find.text('Phân tích bằng AI'));
      await _settle(tester);

      expect(find.text('Học ngay: 1'), findsOneWidget);
      expect(find.text('Nên biết: 1'), findsOneWidget);
      expect(find.textContaining('Cụm: an apple a day'), findsOneWidget);
      expect(find.text('Import 2 từ'), findsOneWidget);

      await tester.tap(find.text('Import 2 từ'));
      await tester.pumpAndSettle();

      final sent = requests
          .where((r) => r['action'] == 'bulkAddWords')
          .expand((r) => ((r['data'] as Map)['words'] as List))
          .cast<Map<String, dynamic>>()
          .toList();
      expect(sent.map((w) => w['word']), ['apple', 'resilient']);
      expect(sent.map((w) => w['learningMode']), ['active', 'passive']);
      expect(sent.first['collocations'], 'an apple a day');
      expect(find.text('Đã thêm 2 từ.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('chuyen mot tu sang Bo qua: khong tinh vao Import, khong gui', (
    tester,
  ) async {
    final hold = Completer<void>();
    await scenario(
      tester,
      (requests) async {
        await tester.enterText(find.byType(TextField), 'apple, resilient');
        await tester.tap(find.text('Phân tích bằng AI'));
        await _settle(tester);

        expect(find.text('Import 2 từ'), findsOneWidget);

        // resilient dang la "Nen biet" -> bam chip 1 lan thanh "Bo qua".
        await tester.tap(find.byKey(const ValueKey('import-mode-2')));
        await tester.pumpAndSettle();

        expect(find.text('Import 1 từ'), findsOneWidget);
        expect(find.text('Bỏ qua: 1'), findsOneWidget);

        await tester.tap(find.text('Import 1 từ'));
        await _settle(tester);

        // Danh sach tick trong luc import chi co tu thuc su duoc luu.
        expect(find.text('apple'), findsOneWidget);
        expect(find.text('resilient'), findsNothing);

        hold.complete();
        await tester.pumpAndSettle();

        final sent = requests
            .where((r) => r['action'] == 'bulkAddWords')
            .expand((r) => ((r['data'] as Map)['words'] as List))
            .cast<Map<String, dynamic>>()
            .toList();
        expect(sent.map((w) => w['word']), ['apple']);
        expect(find.text('Đã thêm 1 từ.'), findsOneWidget);
        expect(
          find.text('Đã bỏ qua 1 từ mà AI xếp "không ưu tiên".'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
      holdBulk: hold,
    );
  });

  testWidgets('tu AI khong lay duoc nghia: bao ro va chi import tu hop le', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      await tester.enterText(find.byType(TextField), 'apple, zzzzz');
      await tester.tap(find.text('Phân tích bằng AI'));
      await _settle(tester);

      expect(
        find.text('1 từ không dùng được sẽ bị bỏ qua (xem lỗi bên dưới).'),
        findsOneWidget,
      );
      expect(find.text('AI không lấy được nghĩa'), findsOneWidget);
      expect(find.text('Import 1 từ'), findsOneWidget);

      await tester.tap(find.text('Import 1 từ'));
      await tester.pumpAndSettle();

      final sent = requests
          .where((r) => r['action'] == 'bulkAddWords')
          .expand((r) => ((r['data'] as Map)['words'] as List))
          .cast<Map<String, dynamic>>()
          .toList();
      expect(sent.map((w) => w['word']), ['apple']);
      expect(find.text('Đã thêm 1 từ.'), findsOneWidget);
      expect(
        find.text('Đã bỏ qua 1 từ (0 đã có, 1 không dùng được).'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('tu da co trong bo tu: hien nghia va khong bi tick khi import', (
    tester,
  ) async {
    final hold = Completer<void>();
    await scenario(
      tester,
      (requests) async {
        await tester.enterText(find.byType(TextField), 'apple, resilient');
        await tester.tap(find.text('Phân tích bằng AI'));
        await _settle(tester);

        // Bang import hien nghia cua tu bi trung + chi import tu moi.
        expect(find.text('quả táo'), findsOneWidget);
        expect(find.text('Trùng từ'), findsOneWidget);
        expect(find.text('Import 1 từ'), findsOneWidget);

        await tester.tap(find.text('Import 1 từ'));
        await _settle(tester);

        // Danh sach tick trong luc import chi co tu thuc su duoc luu.
        expect(find.text('resilient'), findsOneWidget);

        hold.complete();
        await tester.pumpAndSettle();
        expect(find.text('Đã thêm 1 từ.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      existingWords: const [
        {'word': 'apple', 'meaning': 'quả táo', 'wordType': 'noun'},
      ],
      holdBulk: hold,
    );
  });

  testWidgets('tu bi Bo qua khong xuat hien trong danh sach tick khi import', (
    tester,
  ) async {
    final hold = Completer<void>();
    await scenario(
      tester,
      (requests) async {
        await tester.enterText(find.byType(TextField), 'apple, resilient');
        await tester.tap(find.text('Phân tích bằng AI'));
        await _settle(tester);

        // resilient: Nen biet -> Bo qua.
        await tester.tap(find.byKey(const ValueKey('import-mode-2')));
        await tester.pumpAndSettle();
        expect(find.text('Import 1 từ'), findsOneWidget);

        await tester.tap(find.text('Import 1 từ'));
        await _settle(tester);

        // "resilient" da bi bo qua -> khong con trong danh sach tick.
        expect(find.text('apple'), findsOneWidget);
        expect(find.text('resilient'), findsNothing);

        hold.complete();
        await tester.pumpAndSettle();
        expect(find.text('Đã thêm 1 từ.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      holdBulk: hold,
    );
  });
}
