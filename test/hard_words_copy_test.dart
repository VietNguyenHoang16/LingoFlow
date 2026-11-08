import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoflow/pages/hard_words_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _word(int id, String word) => {
      'id': id,
      'word': word,
      'meaning': 'nghĩa $word',
      'pronunciation': '',
      'full_details': '',
      'word_type': 'noun',
      'topic_tag': '',
      'common_synonyms': '',
      'collocations': '',
      'is_favorite': false,
      'example_sentence': '',
      'example_translation': '',
      'example_target': '',
    };

void main() {
  testWidgets('sao chép toàn bộ từ khó: mỗi từ một dòng', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final data = body['action'] == 'getHardWords'
          ? [_word(1, 'apple'), _word(2, 'banana'), _word(3, 'cherry')]
          : null;
      return http.Response(
        jsonEncode({'data': data}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: HardWordsPage(userId: 1)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Sao chép tất cả'));
      await tester.pump();

      expect(copied, ['apple\nbanana\ncherry']);
      expect(find.text('Đã sao chép 3 từ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
