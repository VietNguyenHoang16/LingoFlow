import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/services/dictionary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final svc = DictionaryService();

  group('parseWordData', () {
    test('lays phonetic dau tien non-empty', () {
      final result = svc.parseWordData({
        'phonetics': [
          {'text': '', 'audio': ''},
          {'text': '/ˈleɪ.bər/', 'audio': 'https://a.mp3'},
          {'text': '/ˈleɪbə/', 'audio': ''},
        ],
        'meanings': [],
      });
      expect(result?['pronunciation'], '/ˈleɪ.bər/');
      expect(result?['audioUrl'], 'https://a.mp3');
    });

    test('tra ve null pronunciation khi khong co phonetics', () {
      final result = svc.parseWordData({'phonetics': [], 'meanings': []});
      expect(result?['pronunciation'], isNull);
    });
  });

  group('stripSlashes', () {
    test('bo dau / o dau va cuoi', () {
      expect(DictionaryService.stripSlashes('/kənˈfɛti/'), 'kənˈfɛti');
    });
    test('giu nguyen ipa khong co slash', () {
      expect(DictionaryService.stripSlashes('kənˈfɛti'), 'kənˈfɛti');
    });
    test('chuoi rong van rong', () {
      expect(DictionaryService.stripSlashes(''), '');
    });
  });
}
