import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/services/word_change_bus.dart';

void main() {
  group('WordChangeBus - du lieu moi hien ngay khong can doi tab', () {
    test('notifyChanged phat su kien cho moi trang dang nghe', () async {
      final events = <WordChangeEvent>[];
      final sub = WordChangeBus().stream.listen(events.add);

      WordChangeBus().notifyChanged('add-words');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(events, hasLength(1));
      expect(events.first.reason, 'add-words');
    });

    test('nhieu trang cung nhan 1 su kien', () async {
      final first = <WordChangeEvent>[];
      final second = <WordChangeEvent>[];
      final sub1 = WordChangeBus().stream.listen(first.add);
      final sub2 = WordChangeBus().stream.listen(second.add);

      WordChangeBus().notifyChanged('delete-word');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub1.cancel();
      await sub2.cancel();

      expect(first, hasLength(1));
      expect(second, hasLength(1));
    });

    test('huy nghe thi khong nhan su kien nua', () async {
      final events = <WordChangeEvent>[];
      final sub = WordChangeBus().stream.listen(events.add);
      await sub.cancel();

      WordChangeBus().notifyChanged('edit-word');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(events, isEmpty);
    });
  });
}
