import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoflow/services/bulk_word_importer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final importer = BulkWordImporter();

  test('tach danh sach tu ngan cach bang dau phay', () {
    final lines = importer.parseWords('serendipity, resilient, commute');
    expect(lines, hasLength(3));
    expect(
      lines.map((l) => l.word),
      ['serendipity', 'resilient', 'commute'],
    );
    // Chua co nghia / loai tu -> chua hop le cho den khi AI dien.
    expect(lines.every((l) => l.meaning.isEmpty), isTrue);
    expect(lines.every((l) => l.wordType == null), isTrue);
    expect(lines.every((l) => !l.isValid), isTrue);
  });

  test('nhan ca xuong dong, cham phay, gach dau dong va dau nhay', () {
    final lines = importer.parseWords(
      '- give up;\n"look after"\n\ncommute',
    );
    expect(
      lines.map((l) => l.word),
      ['give up', 'look after', 'commute'],
    );
  });

  test('trung trong danh sach (khong phan biet hoa thuong) bi danh dau', () {
    final lines = importer.parseWords('apple, Apple, banana');
    expect(lines, hasLength(3));
    expect(lines[1].error, 'Trùng trong danh sách');
    expect(lines[2].error, isNull);
  });

  test('comment va phan tu rong bi bo qua', () {
    final lines = importer.parseWords('# ghi chu\n\napple, , banana');
    expect(lines, hasLength(2));
    expect(lines.map((l) => l.word), ['apple', 'banana']);
  });

  test('enrichMeanings dien nghia + loai tu, tu AI bo sot bi danh dau loi',
      () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['action'], 'enrichWords');
      expect((body['data'] as Map)['words'], ['apple', 'zzzzz']);
      return http.Response(
        jsonEncode({
          'data': [
            {'word': 'apple', 'meaning': 'quả táo', 'wordType': 'noun'},
            {'word': 'zzzzz', 'meaning': '', 'wordType': '', 'error': 'AI không lấy được nghĩa cho từ này.'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final lines = importer.parseWords('apple, zzzzz');
    final enriched = await http.runWithClient(
      () => importer.enrichMeanings(1, lines),
      () => client,
    );

    expect(enriched[0].meaning, 'quả táo');
    expect(enriched[0].wordType, 'noun');
    expect(enriched[0].isValid, isTrue);
    expect(enriched[1].isValid, isFalse);
    expect(enriched[1].error, 'AI không lấy được nghĩa');
  });

  test('enrichMeanings loi mang -> moi tu bi danh dau loi', () async {
    final client = MockClient(
      (request) async => http.Response('{"error":"hỏng"}', 500),
    );

    final lines = importer.parseWords('apple, banana');
    final enriched = await http.runWithClient(
      () => importer.enrichMeanings(1, lines),
      () => client,
    );

    expect(enriched.every((l) => !l.isValid), isTrue);
    expect(enriched.every((l) => (l.error ?? '').isNotEmpty), isTrue);
  });

  test('checkDuplicates chay truoc khi AI dien nghia', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['action'], 'filterExistingWords');
      return http.Response(
        jsonEncode({'data': ['apple']}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final lines = importer.parseWords('apple, banana');
    final checked = await http.runWithClient(
      () => importer.checkDuplicates(1, lines),
      () => client,
    );

    expect(checked[0].error, 'Trùng từ');
    expect(checked[1].error, isNull);
  });
}
