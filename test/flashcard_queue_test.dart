import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/services/flashcard_queue.dart';

void main() {
  test('biết -> bỏ thẻ khỏi hàng đợi', () {
    final queue = FlashcardQueue(['a', 'b']);
    expect(queue.current, 'a');
    expect(queue.markKnown(), 'a');
    expect(queue.current, 'b');
    expect(queue.remaining, 1);
    expect(queue.known, 1);
    expect(queue.isDone, isFalse);
  });

  test('chưa biết -> thẻ quay lại cuối hàng đợi', () {
    final queue = FlashcardQueue(['a', 'b', 'c']);
    queue.markUnknown();
    expect(queue.current, 'b');
    expect(queue.markKnown(), 'b');
    expect(queue.markKnown(), 'c');
    expect(queue.current, 'a');
    expect(queue.remaining, 1);
    expect(queue.isDone, isFalse);
  });

  test('xong khi tất cả đã biết', () {
    final queue = FlashcardQueue(['a', 'b']);
    queue.markKnown();
    queue.markKnown();
    expect(queue.isDone, isTrue);
    expect(queue.current, isNull);
    expect(queue.known, 2);
    expect(queue.total, 2);
  });

  test('thẻ duy nhất chưa biết thì vẫn còn trong hàng đợi', () {
    final queue = FlashcardQueue(['a']);
    queue.markUnknown();
    expect(queue.current, 'a');
    expect(queue.remaining, 1);
    expect(queue.isDone, isFalse);
  });
}
