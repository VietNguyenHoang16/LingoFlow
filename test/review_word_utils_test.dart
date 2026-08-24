import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/services/review_word_utils.dart';

void main() {
  group('wordAt (regression: RangeError khi vao Review)', () {
    final words = [
      {'id': 1, 'word': 'cat'},
      {'id': 2, 'word': 'dog'},
    ];

    test('returns the word at a valid index', () {
      expect(wordAt(words, 0)?['word'], 'cat');
      expect(wordAt(words, 1)?['word'], 'dog');
    });

    test('returns null instead of throwing when index >= length', () {
      expect(wordAt(words, 2), isNull);
      expect(wordAt(words, 100), isNull);
    });

    test('returns null for negative index or empty list', () {
      expect(wordAt(words, -1), isNull);
      expect(wordAt(<Map<String, dynamic>>[], 0), isNull);
    });
  });

  group('normalizeWord (regression: TypeError cast mastery_level as int)', () {
    test('coerces int fields from string / double / null', () {
      final word = normalizeWord({
        'mastery_level': '2',
        'interval_days': 3.0,
        'lapse_count': null,
        'correct_streak': 'x',
        'review_count': true,
      });

      expect(word['mastery_level'], 2);
      expect(word['interval_days'], 3);
      expect(word['lapse_count'], 0);
      expect(word['correct_streak'], 0);
      expect(word['review_count'], 1); // true -> 1
    });

    test('keeps existing values and defaults unknown keys to safe values', () {
      final word = normalizeWord({
        'id': 7,
        'word': 'run',
        'meaning': 'chay',
        'is_mastered': 1,
        'is_difficult': 0,
        'ease_factor': '2.8',
      });

      expect(word['id'], 7);
      expect(word['word'], 'run');
      expect(word['meaning'], 'chay');
      expect(word['is_mastered'], true);
      expect(word['is_difficult'], false);
      expect(word['ease_factor'], 2.8);
      expect(word['pronunciation'], '');
      expect(word['full_details'], '');
      expect(word['word_type'], '');
    });
  });
}
