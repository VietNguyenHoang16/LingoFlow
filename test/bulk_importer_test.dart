import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/services/bulk_word_importer.dart';

void main() {
  final importer = BulkWordImporter();

  test('parse dong co common (format ::)', () {
    final lines = importer.parseLines(
      '3 :: solid :: ổn, tốt :: good · reliable · decent',
    );
    expect(lines, hasLength(1));
    final l = lines.first;
    expect(l.isValid, isTrue);
    expect(l.word, 'solid');
    expect(l.meaning, 'ổn, tốt');
    expect(l.commonSynonyms, 'good · reliable · decent');
  });

  test('parse dong thieu common -> rong (tuong thich nguoc)', () {
    final lines = importer.parseLines('1 :: apple :: quả táo');
    expect(lines, hasLength(1));
    final l = lines.first;
    expect(l.isValid, isTrue);
    expect(l.commonSynonyms, '');
  });

  test('parse format || co common', () {
    final lines = importer.parseLines(
      '3 || solid || ổn || good, reliable',
    );
    expect(lines.first.isValid, isTrue);
    expect(lines.first.commonSynonyms, 'good, reliable');
  });

  test('common qua 3 tu -> loi', () {
    final lines = importer.parseLines(
      '3 :: solid :: ổn :: good, reliable, decent, stable',
    );
    expect(lines.first.isValid, isFalse);
    expect(lines.first.error, 'Common tối đa 3 từ');
  });

  test('thua segment -> loi dinh dang', () {
    final lines = importer.parseLines(
      '3 :: solid :: ổn :: good :: related :: nuance',
    );
    expect(lines.first.isValid, isFalse);
    expect(lines.first.error, contains('Sai định dạng'));
  });

  test('comment va dong trong bi bo qua', () {
    final lines = importer.parseLines('# comment\n\n1 :: apple :: quả táo');
    expect(lines, hasLength(1));
  });
}
