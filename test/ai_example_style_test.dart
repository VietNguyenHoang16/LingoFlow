import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/services/ai_settings_service.dart';
import 'package:lingoflow/widgets/ai_example_style_sheet.dart';

void main() {
  group('AiExampleStyle', () {
    test('mặc định: đời sống, công việc, IT + bỏ nghĩa hiếm', () {
      const style = AiExampleStyle.defaults;
      expect(style.contexts, ['daily', 'work', 'it']);
      expect(style.skipRareSenses, isTrue);
      expect(style.custom, '');
      expect(style.isDefault, isTrue);
    });

    test('id lạ bị loại, trùng được gộp, giữ đúng thứ tự danh mục', () {
      final style = AiExampleStyle.fromJson({
        'contexts': ['IT', 'it', 'mars', 'study'],
        'skipRareSenses': false,
        'custom': '  câu   ngắn \n dưới 12 từ ',
      });
      expect(style.contexts, ['it', 'study']);
      expect(style.skipRareSenses, isFalse);
      expect(style.custom, 'câu ngắn dưới 12 từ');
      expect(style.isDefault, isFalse);
    });

    test('thiếu contexts hoặc JSON hỏng -> quay về mặc định', () {
      final style = AiExampleStyle.fromJson({'custom': 12});
      expect(style.contexts, ['daily', 'work', 'it']);
      expect(style.skipRareSenses, isTrue);
      expect(style.custom, '12');
    });

    test('custom bị cắt ở 300 ký tự và gộp khoảng trắng', () {
      final custom = AiExampleStyle.normalizeCustom('a  ${'b' * 400}');
      expect(custom.length, AiExampleStyle.maxCustomLength);
      expect(custom.contains('  '), isFalse);
    });

    test('toApiJson giữ được dữ liệu khi đọc lại', () {
      const style = AiExampleStyle(
        contexts: ['travel', 'media'],
        skipRareSenses: false,
        custom: 'tránh tên riêng',
      );
      final restored = AiExampleStyle.fromJson(style.toApiJson());
      expect(restored.contexts, style.contexts);
      expect(restored.skipRareSenses, false);
      expect(restored.custom, 'tránh tên riêng');
    });

    test('tóm tắt hiển thị trong Cài đặt', () {
      expect(
        AiExampleStyle.defaults.summary,
        'Đời sống hằng ngày, Công việc / văn phòng, IT & công nghệ · bỏ nghĩa hiếm',
      );
      expect(
        const AiExampleStyle(contexts: [], skipRareSenses: false).summary,
        'AI tự chọn bối cảnh · mọi nghĩa',
      );
    });
  });

  group('Xem trước chỉ dẫn gửi AI', () {
    test('mặc định khớp khối Learner preferences', () {
      final preview = buildAiExampleStylePreview(AiExampleStyle.defaults);
      expect(preview.startsWith('Learner preferences:'), isTrue);
      expect(preview, contains('"concrete" use "cụ thể, rõ ràng"'));
      expect(preview, contains('"harness" use "tận dụng, khai thác"'));
      expect(
        preview,
        contains(
          'set the scene in: everyday life, work and the office, IT and technology.',
        ),
      );
    });

    test('không chọn gì -> báo dùng prompt gốc', () {
      final preview = buildAiExampleStylePreview(
        const AiExampleStyle(contexts: [], skipRareSenses: false),
      );
      expect(preview, 'Không có chỉ dẫn thêm — AI dùng prompt gốc.');
    });

    test('yêu cầu riêng được chèn nguyên văn', () {
      final preview = buildAiExampleStylePreview(
        const AiExampleStyle(
          contexts: ['it'],
          custom: 'chỉ dùng thì hiện tại đơn',
        ),
      );
      expect(preview, contains('Extra notes from the learner: chỉ dùng thì hiện tại đơn'));
      expect(preview, contains('set the scene in: IT and technology.'));
    });
  });

  test('id bối cảnh của app khớp với server', () {
    final source = File('api/_lib/xai.js').readAsStringSync();
    final block = RegExp(
      r'const EXAMPLE_CONTEXTS = \{(.*?)\n\};',
      dotAll: true,
    ).firstMatch(source);
    expect(block, isNotNull, reason: 'không tìm thấy EXAMPLE_CONTEXTS');

    final serverIds = RegExp(r'^\s{2}(\w+):', multiLine: true)
        .allMatches(block!.group(1)!)
        .map((match) => match.group(1)!)
        .toSet();
    final appIds = kAiExampleContexts.map((context) => context.id).toSet();
    expect(appIds, serverIds);
  });

  testWidgets('sheet hiện mặc định và lưu đúng lựa chọn', (tester) async {
    AiExampleStyle? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => AiExampleStyleSheet.show(
                  context,
                  loader: () async => AiExampleStyle.defaults,
                  saver: (style) async {
                    saved = style;
                    return style;
                  },
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Cách AI sinh ví dụ'), findsOneWidget);
    final defaultChip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Đời sống hằng ngày'),
    );
    expect(defaultChip.selected, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    // O yeu cau rieng + xem truoc nam duoi: cuon xuong roi moi nhap.
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'câu ngắn dưới 10 từ',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Extra notes from the learner'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.skipRareSenses, isFalse);
    expect(saved!.custom, 'câu ngắn dưới 10 từ');
    expect(saved!.contexts, ['daily', 'work', 'it']);
  });
}
