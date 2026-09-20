import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/services/answer_comparison.dart';

/// Dấu phải luôn dựng lại được đúng chuỗi gốc — nếu không, widget highlight sẽ
/// hiển thị sai chữ.
void expectMarksRebuild(
  AnswerDiff diff, {
  required String expected,
  required String typed,
}) {
  expect(diff.expectedMarks.map((m) => m.char).join(), expected);
  expect(diff.typedMarks.map((m) => m.char).join(), typed);
}

List<CharMarkKind> kindsAt(List<CharMark> marks, Iterable<int> indexes) {
  final byIndex = {for (final m in marks) m.index: m.kind};
  return [for (final i in indexes) byIndex[i] ?? CharMarkKind.keep];
}

void main() {
  group('diffAnswer: truong hop dung', () {
    test('giong tuyet doi -> dung, khong co dau lech', () {
      final diff = diffAnswer(typed: 'apple', expected: 'apple');
      expect(diff.isCorrect, isTrue);
      expect(diff.distance, 0);
      expect(diff.hasMismatch, isFalse);
      expect(diff.similarity, 1);
      expectMarksRebuild(diff, expected: 'apple', typed: 'apple');
    });

    test('chi khac hoa thuong / khoang trang dau cuoi -> van dung', () {
      for (final typed in ['Apple', 'APPLE', '  apple  ', 'ApPlE']) {
        final diff = diffAnswer(typed: typed, expected: 'apple');
        expect(diff.isCorrect, isTrue, reason: 'typed=$typed');
        expect(diff.hasMismatch, isFalse, reason: 'typed=$typed');
      }
    });

    test('tu ghep: giong het va khac hoa thuong', () {
      final diff = diffAnswer(typed: 'Look After', expected: 'look after');
      expect(diff.isCorrect, isTrue);
      expect(diff.hasMismatch, isFalse);
    });
  });

  group('diffAnswer: go thieu ky tu', () {
    test('thieu 1 chu o giua -> danh dau missing dung vi tri', () {
      final diff = diffAnswer(typed: 'aple', expected: 'apple');
      expect(diff.isCorrect, isFalse);
      expect(diff.distance, 1);
      expect(diff.mismatchCount, 1);
      expect(kindsAt(diff.expectedMarks, [2]), [CharMarkKind.missing]);
      // Phia nguoi dung khong co ky tu thua -> khong to gi tren dong da go.
      expect(diff.typedMarks.any((m) => m.isMismatch), isFalse);
      expectMarksRebuild(diff, expected: 'apple', typed: 'aple');
    });
  });

  group('diffAnswer: go thua ky tu', () {
    test('thua 1 chu -> danh dau extra tren chuoi da go', () {
      final diff = diffAnswer(typed: 'appple', expected: 'apple');
      expect(diff.isCorrect, isFalse);
      expect(diff.distance, 1);
      expect(diff.expectedMarks.any((m) => m.isMismatch), isFalse);
      expect(kindsAt(diff.typedMarks, [3]), [CharMarkKind.extra]);
      expectMarksRebuild(diff, expected: 'apple', typed: 'appple');
    });

    test('thua khoang trang giua 2 tu -> extra la khoang trang', () {
      final diff = diffAnswer(typed: 'look  after', expected: 'look after');
      expect(diff.isCorrect, isFalse);
      expect(diff.hasMismatch, isTrue);
      expectMarksRebuild(diff, expected: 'look after', typed: 'look  after');
    });
  });

  group('diffAnswer: go sai 1 ky tu', () {
    test('thay the 1 ky tu -> gop thanh replaced ca 2 phia', () {
      final diff = diffAnswer(typed: 'cut', expected: 'cat');
      expect(diff.isCorrect, isFalse);
      expect(diff.distance, 1);
      expect(kindsAt(diff.expectedMarks, [0, 1, 2]), [
        CharMarkKind.keep,
        CharMarkKind.replaced,
        CharMarkKind.keep,
      ]);
      expect(kindsAt(diff.typedMarks, [0, 1, 2]), [
        CharMarkKind.keep,
        CharMarkKind.replaced,
        CharMarkKind.keep,
      ]);
      expectMarksRebuild(diff, expected: 'cat', typed: 'cut');
    });

    test('sai ky tu cuoi -> replaced o vi tri cuoi', () {
      final diff = diffAnswer(typed: 'applX', expected: 'apple');
      expect(diff.distance, 1);
      expect(kindsAt(diff.expectedMarks, [4]), [CharMarkKind.replaced]);
      expect(kindsAt(diff.typedMarks, [4]), [CharMarkKind.replaced]);
      expectMarksRebuild(diff, expected: 'apple', typed: 'applX');
    });

    test('sai 1 ky tu khong lan ra toan chuoi', () {
      final diff = diffAnswer(typed: 'recieve', expected: 'receive');
      expect(diff.mismatchCount, 1);
      expect(diff.typedMarks.where((m) => m.isMismatch).length, 1);
      expectMarksRebuild(diff, expected: 'receive', typed: 'recieve');
    });

    test('sai tu tieng Anh co dau -> khong crash', () {
      final diff = diffAnswer(typed: 'cafe', expected: 'café');
      expect(diff.isCorrect, isFalse);
      expect(diff.hasMismatch, isTrue);
      expectMarksRebuild(diff, expected: 'café', typed: 'cafe');
    });
  });

  group('diffAnswer: truong hop bien', () {
    test('sai hoan toan -> khong crash, con dau de to', () {
      final diff = diffAnswer(typed: 'aple', expected: 'banana');
      expect(diff.isCorrect, isFalse);
      expect(diff.hasMismatch, isTrue);
      expect(diff.distance, greaterThan(0));
      expectMarksRebuild(diff, expected: 'banana', typed: 'aple');
    });

    test('khac han dap an (khong chung ky tu) -> khong to de tranh nhieu', () {
      final diff = diffAnswer(typed: 'dog', expected: 'apple');
      expect(diff.isCorrect, isFalse);
      expect(diff.hasMismatch, isFalse);
      expect(diff.distance, 5);
      expect(diff.similarity, 0);
      expectMarksRebuild(diff, expected: 'apple', typed: 'dog');
    });

    test('chua go gi -> khong to do dau nao', () {
      for (final typed in ['', '   ']) {
        final diff = diffAnswer(typed: typed, expected: 'apple');
        expect(diff.isCorrect, isFalse, reason: 'typed="$typed"');
        expect(diff.hasMismatch, isFalse, reason: 'typed="$typed"');
        expect(
          diff.expectedMarks.every((m) => m.kind == CharMarkKind.keep),
          isTrue,
        );
      }
    });

    test('dap an rong -> khong crash', () {
      final diff = diffAnswer(typed: 'apple', expected: '');
      expect(diff.isCorrect, isFalse);
      expect(diff.hasMismatch, isFalse);
      expect(diff.distance, 5);
    });

    test('chuoi dai bat thuong -> bo qua can chinh, khong crash', () {
      final longWord = 'a' * 300;
      final diff = diffAnswer(typed: '${longWord}b', expected: longWord);
      expect(diff.isCorrect, isFalse);
      expect(diff.hasMismatch, isFalse);
      expect(diff.distance, greaterThanOrEqualTo(0));
      expectMarksRebuild(diff, expected: longWord, typed: '${longWord}b');
    });

    test('similarity giam theo so ky tu sai', () {
      final near = diffAnswer(typed: 'applX', expected: 'apple');
      final far = diffAnswer(typed: 'XXXXX', expected: 'apple');
      expect(near.similarity, greaterThan(far.similarity));
      expect(near.similarity, closeTo(0.8, 0.001));
      expect(far.similarity, 0);
    });

    test('ky tu ngoai BMP khong bi cat doi surrogate pair', () {
      final diff = diffAnswer(typed: 'a\u{1F600}c', expected: 'a\u{1F600}b');
      expect(diff.isCorrect, isFalse);
      expect(diff.distance, 1);
      expectMarksRebuild(diff, expected: 'a\u{1F600}b', typed: 'a\u{1F600}c');
    });
  });
}