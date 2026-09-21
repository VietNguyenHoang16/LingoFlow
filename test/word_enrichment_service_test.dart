import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoflow/services/word_enrichment_service.dart';
import 'package:lingoflow/services/word_details_parser.dart';

/// Entry gia lap cua dictionaryapi.dev (dung cho ca 3 test).
String _dictionaryBody() => jsonEncode([
      {
        'phonetics': [
          {'text': '', 'audio': ''},
          {'text': '/ˈæp.əl/', 'audio': 'https://a.mp3'},
        ],
        'meanings': [
          {
            'partOfSpeech': 'noun',
            'definitions': [
              {
                'definition': 'A round fruit.',
                'example': 'I ate an {apple}.',
              },
              {'definition': 'The tree.', 'example': ''},
            ],
          },
          {
            'partOfSpeech': 'exclamation',
            'definitions': [
              {'definition': 'Used to express approval.', 'example': ''},
            ],
          },
        ],
      },
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildFullDetails', () {
    test('tao dung format parseFullDetails doc duoc', () {
      final raw = WordEnrichmentService.buildFullDetails([
        {
          'type': 'noun',
          'definitions': [
            {'definition': 'A round fruit.', 'example': 'I ate an apple.'},
            {'definition': 'The tree.', 'example': ''},
          ],
        },
        {
          'type': 'verb',
          'definitions': [
            {'definition': 'To become apple-shaped.', 'example': ''},
          ],
        },
      ]);

      expect(
        raw,
        'noun: [{definition: A round fruit., example: I ate an apple.}, '
        '{definition: The tree., example: }]\n'
        'verb: [{definition: To become apple-shaped., example: }]',
      );

      final parsed = parseFullDetails(raw);
      expect(parsed.length, 2);
      expect(parsed[0]['pos'], 'noun');
      final nounDefs = parsed[0]['definitions'] as List;
      expect(nounDefs.length, 2);
      expect(nounDefs[0]['definition'], 'A round fruit.');
      expect(nounDefs[0]['example'], 'I ate an apple.');
      expect(parsed[1]['pos'], 'verb');
    });

    test('bo ky tu pha format va gioi han 3 definition moi loai tu', () {
      final raw = WordEnrichmentService.buildFullDetails([
        {
          'type': 'noun',
          'definitions': [
            {'definition': 'A {brace}', 'example': ''},
            {'definition': 'Two [bracket]', 'example': ''},
            {'definition': 'Three', 'example': ''},
            {'definition': 'Four', 'example': ''},
          ],
        },
      ]);

      expect(raw.contains('{definition: A (brace)'), isTrue);
      expect(raw.contains('Two (bracket)'), isTrue);
      expect(raw.contains('Four'), isFalse);
      expect(parseFullDetails(raw).single['definitions'], hasLength(3));
    });

    test('tra ve rong khi khong co definitions', () {
      expect(WordEnrichmentService.buildFullDetails(null), '');
      expect(WordEnrichmentService.buildFullDetails([]), '');
      expect(
        WordEnrichmentService.buildFullDetails([
          {'type': 'noun', 'definitions': []},
        ]),
        '',
      );
    });

    test('bo qua POS la khong map duoc sang key cua app', () {
      expect(
        WordEnrichmentService.buildFullDetails([
          {
            'type': 'sound_effect',
            'definitions': [
              {'definition': 'Bang.', 'example': ''},
            ],
          },
        ]),
        '',
      );
    });
  });

  group('buildWordTypes', () {
    test('map part-of-speech sang key cua app', () {
      expect(
        WordEnrichmentService.buildWordTypes([
          {'type': 'Noun'},
          {'type': 'exclamation'},
          {'type': 'unknown-pos'},
        ]),
        'noun,interjection',
      );
    });

    test('tra ve rong khi khong map duoc', () {
      expect(WordEnrichmentService.buildWordTypes(null), '');
      expect(WordEnrichmentService.buildWordTypes([{'type': ''}]), '');
    });
  });

  group('fetch', () {
    test('goi dictionary, strip slash IPA va tra ve du lieu da chuan hoa',
        () async {
      Uri? requested;
      final client = MockClient((request) async {
        requested = request.url;
        return http.Response(
          _dictionaryBody(),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final result = await http.runWithClient(
        () => WordEnrichmentService().fetch(' Apple '),
        () => client,
      );

      expect(requested?.path, '/api/v2/entries/en/Apple');
      expect(result, isNotNull);
      expect(result!.pronunciation, 'ˈæp.əl');
      expect(result.wordType, 'noun,interjection');
      expect(result.fullDetails, startsWith('noun: ['));
      expect(result.fullDetails.contains('A round fruit.'), isTrue);
      expect(parseFullDetails(result.fullDetails), hasLength(2));
    });

    test('tra ve null khi tu khong co trong tu dien', () async {
      final client = MockClient((request) async => http.Response('{}', 404));
      final result = await http.runWithClient(
        () => WordEnrichmentService().fetch('zzzzz'),
        () => client,
      );
      expect(result, isNull);
    });

    test('tra ve null khi chuoi rong (khong goi mang)', () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response(_dictionaryBody(), 200);
      });
      final result = await http.runWithClient(
        () => WordEnrichmentService().fetch('   '),
        () => client,
      );
      expect(result, isNull);
      expect(called, isFalse);
    });
  });
}
