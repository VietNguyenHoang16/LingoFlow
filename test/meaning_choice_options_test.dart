import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/services/meaning_choice_options.dart';

void main() {
  test('1 dap an dung + toi da 3 nhiu, khong trung nghia dung', () {
    final options = buildMeaningOptions(
      correctMeaning: 'quả táo',
      poolMeanings: ['quả cam', 'quả chanh', 'quả bưởi', 'quả lê', 'quả ổi'],
      random: Random(42),
    );
    expect(options.length, 4);
    expect(options.where((o) => o.isCorrect).length, 1);
    expect(options.firstWhere((o) => o.isCorrect).meaning, 'quả táo');
    final distractors =
        options.where((o) => !o.isCorrect).map((o) => o.meaning).toList();
    expect(distractors.toSet().length, 3);
    expect(distractors.contains('quả táo'), isFalse);
  });

  test('pool it hon 3 -> it lua chon hon nhung van co dap an dung', () {
    final options = buildMeaningOptions(
      correctMeaning: 'apple',
      poolMeanings: const ['cam'],
      random: Random(42),
    );
    expect(options.length, 2);
    expect(
      options.where((o) => o.isCorrect && o.meaning == 'apple').length,
      1,
    );
  });

  test('pool rong -> chi con dap an dung (trang tu dong ve che do gõ)', () {
    final options = buildMeaningOptions(
      correctMeaning: 'x',
      poolMeanings: const [],
      random: Random(42),
    );
    expect(options.length, 1);
    expect(options.single.isCorrect, isTrue);
  });

  test('loai bo nghia trung dap an (khac viet hoa/khoang trang) va nghia rong', () {
    final options = buildMeaningOptions(
      correctMeaning: ' Táo ',
      poolMeanings: const ['táo', '', '  ', 'cam', 'chanh', 'buoi'],
      random: Random(42),
    );
    expect(options.length, 4);
    expect(
      options.map((o) => o.meaning.trim().toLowerCase()).toSet(),
      {'táo', 'cam', 'chanh', 'buoi'},
    );
    // Dap an dung duoc trim gọn để hien thi.
    expect(options.firstWhere((o) => o.isCorrect).meaning, 'Táo');
  });

  test('thu tu shuffle: vi tri dap an dung thay doi qua nhieu lan goi', () {
    final positions = <int>{};
    for (var i = 0; i < 20; i++) {
      final options = buildMeaningOptions(
        correctMeaning: 'nghĩa đúng',
        poolMeanings: const ['a', 'b', 'c'],
        random: Random(),
      );
      positions.add(options.indexWhere((o) => o.isCorrect));
    }
    expect(positions.length, greaterThan(1));
  });
}
