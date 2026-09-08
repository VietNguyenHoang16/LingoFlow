import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/services/topic_tag_utils.dart';

void main() {
  group('splitTopicTag', () {
    test('tách nhãn ở cuối', () {
      expect(
        splitTopicTag('dùng hết sạch - gym'),
        (meaning: 'dùng hết sạch', topicTag: 'gym'),
      );
    });

    test('không suffix thì nhãn rỗng', () {
      expect(
        splitTopicTag('công bằng'),
        (meaning: 'công bằng', topicTag: ''),
      );
    });

    test('nhiều dấu - thì lấy phần cuối cùng', () {
      expect(
        splitTopicTag('học bài - chăm chỉ - school'),
        (meaning: 'học bài - chăm chỉ', topicTag: 'school'),
      );
    });

    test('suffix trống thì nhãn rỗng', () {
      expect(
        splitTopicTag('nghĩa gì đó - '),
        (meaning: 'nghĩa gì đó', topicTag: ''),
      );
    });
  });
}
