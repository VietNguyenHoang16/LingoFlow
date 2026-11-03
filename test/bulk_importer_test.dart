import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoflow/services/bulk_word_importer.dart';
import 'package:lingoflow/services/database_service.dart';
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

  test('enrichMeanings thu lai khi connection abort', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1) {
        throw http.ClientException(
          'Software caused connection abort',
          request.url,
        );
      }
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

    final lines = importer.parseWords('apple');
    final enriched = await http.runWithClient(
      () => importer.enrichMeanings(1, lines),
      () => client,
    );

    expect(calls, 2);
    expect(enriched.single.meaning, 'quả táo');
    expect(enriched.single.isValid, isTrue);
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

  test('gop nhom dong nghia viet tren cung dong: verbose/wordy', () {
    final lines = importer.parseWords('verbose/wordy, 24/7, resilient');
    expect(lines, hasLength(3));
    expect(lines[0].word, 'verbose');
    expect(lines[0].synonyms, ['wordy']);
    expect(lines[0].commonSynonyms, 'wordy');
    // So khong bi tach thanh nhom.
    expect(lines[1].word, '24/7');
    expect(lines[1].synonyms, isEmpty);
    expect(lines[2].word, 'resilient');
  });

  test('nhom dong nghia dung dau = va toi da 3 tu phu', () {
    final lines = importer.parseWords('verbose = wordy = long-winded = windy');
    expect(lines, hasLength(1));
    expect(lines[0].word, 'verbose');
    expect(lines[0].synonyms, ['wordy', 'long-winded', 'windy']);
  });

  test('AI bao cung nghia -> gop thanh 1 card', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'data': [
            {
              'word': 'verbose',
              'meaning': 'dai dong',
              'wordType': 'adjective',
              'synonyms': ['wordy'],
            },
            {
              'word': 'wordy',
              'meaning': 'nhieu loi',
              'wordType': 'adjective',
              'synonyms': ['verbose'],
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final lines = importer.parseWords('verbose, wordy');
    final enriched = await http.runWithClient(
      () => importer.enrichMeanings(1, lines),
      () => client,
    );

    expect(enriched[0].isValid, isTrue);
    expect(enriched[0].synonyms, ['wordy']);
    expect(enriched[1].isMerged, isTrue);
    expect(enriched[1].mergedInto, 'verbose');
    expect(enriched[1].error, 'Gộp vào "verbose"');
    expect(enriched[1].isValid, isFalse);
  });

  test('trung nghia tieng Viet cung duoc gop', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'data': [
            {'word': 'verbose', 'meaning': 'dài dòng', 'wordType': 'adjective'},
            {'word': 'wordy', 'meaning': 'dài dòng', 'wordType': 'adjective'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final lines = importer.parseWords('verbose, wordy');
    final enriched = await http.runWithClient(
      () => importer.enrichMeanings(1, lines),
      () => client,
    );

    expect(enriched[0].synonyms, ['wordy']);
    expect(enriched[1].isMerged, isTrue);
  });

  test('importBatch gui commonSynonyms cua nhom gop', () async {
    final sent = <Map<String, dynamic>>[];
    final result = await importer.importBatch(
      1,
      [
        ImportLine(
          lineNumber: 1,
          rawLine: 'verbose/wordy',
          word: 'verbose',
          meaning: 'dài dòng',
          wordType: 'adjective',
          synonyms: const ['wordy'],
        ),
      ],
      pronunciationsOverride: const <String, String>{'verbose': '/ˈvɜː.bəl/'},
      bulkAdd: (userId, category, words) async {
        sent.addAll(words);
        return BulkAddResult(insertedCount: 1, failed: const []);
      },
    );

    expect(result.insertedCount, 1);
    expect(sent.single['word'], 'verbose');
    expect(sent.single['commonSynonyms'], 'wordy');
  });

  group('import thu cong POS :: tu :: nghia', () {
    test('parse du POS, tu, nghia, common va khong can AI', () {
      final lines = importer.parseWords('3 :: solid :: ổn :: good · reliable · decent');
      expect(lines, hasLength(1));
      final l = lines.single;
      expect(l.manual, isTrue);
      expect(l.word, 'solid');
      expect(l.wordType, 'adjective');
      expect(l.meaning, 'ổn');
      expect(l.synonyms, ['good', 'reliable', 'decent']);
      expect(l.commonSynonyms, 'good · reliable · decent');
      expect(l.isValid, isTrue);
    });

    test('nhan bien the || va format cu tu / POS / nghia', () {
      final byPipe = importer.parseWords('2 || give up || từ bỏ');
      expect(byPipe.single.wordType, 'verb');
      expect(byPipe.single.meaning, 'từ bỏ');
      expect(byPipe.single.manual, isTrue);

      final old = importer.parseWords('solid / 3 / ổn');
      expect(old.single.word, 'solid');
      expect(old.single.wordType, 'adjective');
      expect(old.single.manual, isTrue);
    });

    test('tach nhan chu de sau dau - cuoi cung', () {
      final l = importer
          .parseWords('11 :: Work under pressure :: Làm việc dưới áp lực - work')
          .single;
      expect(l.meaning, 'Làm việc dưới áp lực');
      expect(l.topicTag, 'work');
      expect(l.wordType, 'collocation');
    });

    test('loi dinh dang: thieu tu, thieu nghia, sai POS, sai format, qua 3 common',
        () {
      expect(importer.parseWords('1 :: :: quả táo').single.error, 'Thiếu từ');
      expect(importer.parseWords('1 :: apple ::').single.error, 'Thiếu nghĩa');
      expect(
        importer.parseWords('13 :: apple :: quả táo').single.error,
        'Số POS không hợp lệ',
      );
      expect(importer.parseWords('1 :: apple').single.error, 'Sai định dạng');
      expect(
        importer.parseWords('1 :: apple :: quả táo :: a · b · c · d').single.error,
        'Common tối đa 3 từ',
      );
    });

    test('khong nhan nham so kieu 24/7/365 la format cu', () {
      final lines = importer.parseWords('24/7/365');
      expect(lines.single.manual, isFalse);
      expect(lines.single.word, '24/7/365');
    });

    test('dung chung 1 khung: dong thu cong khong bi AI ghi de', () async {
      final asked = <List<String>>[];
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['action'], 'enrichWords');
        asked.add((body['data'] as Map)['words'].cast<String>());
        return http.Response(
          jsonEncode({
            'data': [
              {'word': 'apple', 'meaning': 'quả táo', 'wordType': 'noun'},
              {'word': 'give up', 'meaning': 'SAI', 'wordType': 'noun'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final lines = importer.parseWords('2 :: give up :: từ bỏ\napple');
      final enriched = await http.runWithClient(
        () => importer.enrichMeanings(1, lines),
        () => client,
      );

      // AI chỉ được hỏi đúng từ không viết theo quy tắc thủ công.
      expect(asked.single, ['apple']);
      expect(enriched[0].word, 'give up');
      expect(enriched[0].meaning, 'từ bỏ');
      expect(enriched[0].wordType, 'verb');
      expect(enriched[0].isValid, isTrue);
      expect(enriched[1].meaning, 'quả táo');
    });

    test('trung tu trong danh sach van bi danh dau', () {
      final lines = importer.parseWords('1 :: apple :: quả táo\n1 :: Apple :: táo');
      expect(lines[1].error, 'Trùng trong danh sách');
    });

    test('importBatch luu topicTag cua dong thu cong', () async {
      final sent = <Map<String, dynamic>>[];
      await importer.importBatch(
        1,
        [
          ImportLine(
            lineNumber: 1,
            rawLine: '3 :: solid :: ổn - gym',
            word: 'solid',
            meaning: 'ổn',
            wordType: 'adjective',
            topicTag: 'gym',
            manual: true,
          ),
        ],
        pronunciationsOverride: const <String, String>{'solid': ''},
        bulkAdd: (userId, category, words) async {
          sent.addAll(words);
          return BulkAddResult(insertedCount: 1, failed: const []);
        },
      );

      expect(sent.single['topicTag'], 'gym');
      expect(sent.single['wordType'], 'adjective');
    });
  });
}
