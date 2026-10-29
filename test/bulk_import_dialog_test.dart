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
    Future<void> Function(List<Map<String, dynamic>> requests) check,
  ) async {
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
                    {'word': w, 'meaning': 'nghĩa của $w', 'wordType': 'noun'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        case 'bulkAddWords':
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

  testWidgets('loai tru tu o preview: khong import, bam lai thi hoan tac', (
    tester,
  ) async {
    await scenario(tester, (requests) async {
      await tester.enterText(find.byType(TextField), 'apple, resilient');
      await tester.tap(find.text('Phân tích bằng AI'));
      await _settle(tester);

      expect(find.text('Import 2 từ'), findsOneWidget);

      // Loại trừ "resilient" (dòng #2).
      await tester.tap(find.byKey(const ValueKey('import-exclude-2')));
      await tester.pumpAndSettle();

      expect(find.text('Import 1 từ'), findsOneWidget);
      expect(find.text('Đã loại trừ: 1'), findsOneWidget);
      // Dòng bị loại vẫn hiện để còn hoàn tác.
      expect(find.text('resilient'), findsOneWidget);

      // Bấm lại để hoàn tác.
      await tester.tap(find.byKey(const ValueKey('import-exclude-2')));
      await tester.pumpAndSettle();
      expect(find.text('Import 2 từ'), findsOneWidget);

      // Loại trừ lần nữa rồi import: chỉ gửi "apple".
      await tester.tap(find.byKey(const ValueKey('import-exclude-2')));
      await tester.pumpAndSettle();
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
        find.text('Đã loại trừ 1 từ bạn bỏ trước khi import.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
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
}
