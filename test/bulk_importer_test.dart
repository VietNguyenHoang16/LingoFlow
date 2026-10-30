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

  test('bo so thu tu dau dong khi danh so (29. asset -> asset)', () {
    final lines = importer.parseWords(
      '29. asset, 3) give up, 12 - take off, 7: run, (4) commute',
    );
    expect(
      lines.map((l) => l.word),
      ['asset', 'give up', 'take off', 'run', 'commute'],
    );
  });

  test('giu nguyen khi so dau dong khong phai so thu tu', () {
    final lines = importer.parseWords('8-bit, 24/7, 3.14, 1980s, 100m');
    expect(
      lines.map((l) => l.word),
      ['8-bit', '24/7', '3.14', '1980s', '100m'],
    );
  });

  test('dong chi co so thu tu rong bi bo qua', () {
    final lines = importer.parseWords('29., apple');
    expect(lines.map((l) => l.word), ['apple']);
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
      expect(body['action'], 'filterExistingWordsDetailed');
      return http.Response(
        jsonEncode({
          'data': [
            {'word': 'Apple', 'meaning': 'quả táo', 'wordType': 'noun'},
          ],
        }),
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

  test('tu trung voi bo tu cu hien thi nghia + loai tu da luu', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['action'], 'filterExistingWordsDetailed');
      return http.Response(
        jsonEncode({
          'data': [
            {'word': 'apple', 'meaning': 'quả táo', 'wordType': 'noun'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final lines = importer.parseWords('apple, banana');
    final checked = await http.runWithClient(
      () => importer.checkDuplicates(1, lines),
      () => client,
    );

    expect(checked[0].isDuplicate, isTrue);
    expect(checked[0].meaning, 'quả táo');
    expect(checked[0].wordType, 'noun');
    // Trung tu khong duoc import.
    expect(checked[0].isValid, isFalse);
    expect(checked[1].meaning, isEmpty);
  });

  test('API cu khong co action detailed: van danh dau trung qua fallback',
      () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (body['action'] == 'filterExistingWordsDetailed') {
        return http.Response('{"error":"unknown action"}', 400);
      }
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
    expect(checked[0].meaning, isEmpty);
    expect(checked[1].error, isNull);
  });

  test('trung trong danh sach van hien nghia cua dong dau tien', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'data': [
            {'word': 'apple', 'meaning': 'quả táo', 'wordType': 'noun'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final lines = importer.parseWords('apple, Apple, banana');
    final enriched = await http.runWithClient(
      () => importer.enrichMeanings(1, lines),
      () => client,
    );

    expect(enriched[0].meaning, 'quả táo');
    expect(enriched[1].error, 'Trùng trong danh sách');
    // Dong trung khong duoc AI phan tich nhung van hien thi nghia.
    expect(enriched[1].meaning, 'quả táo');
    expect(enriched[1].wordType, 'noun');
    expect(enriched[1].isValid, isFalse);
  });
}
