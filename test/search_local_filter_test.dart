import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoflow/pages/dashboard_page.dart';
import 'package:lingoflow/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mock tra ve danh sach tu nhe cho action getWordIndex + dem request.
Future<(List<Map<String, dynamic>>, int Function())> pumpSheet(
  WidgetTester tester, {
  required int userId,
  required List<Map<String, dynamic>> words,
}) async {
  final requests = <Map<String, dynamic>>[];
  final client = MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    requests.add(body);
    if (body['action'] == 'getWordIndex') {
      return http.Response(jsonEncode({'data': words}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    return http.Response('{"data":null}', 200);
  });

  await http.runWithClient(() async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: SearchBottomSheet(userId: userId)),
    ));
    await tester.pumpAndSettle();
  }, () => client);

  return (
    requests,
    () => requests.where((r) => r['action'] == 'getWordIndex').length,
  );
}

const _words = [
  {
    'id': 1,
    'word': 'Apple',
    'meaning': 'qua tao',
    'word_type': 'noun',
    'topic_tag': 'fruit',
    'list_name': 'Noun',
    'category': 'noun',
  },
  {
    'id': 2,
    'word': 'banana',
    'meaning': 'qua chuoi',
    'word_type': 'noun',
    'topic_tag': '',
    'list_name': 'Noun',
    'category': 'noun',
  },
];

void main() {
  testWidgets('loc ngay tai may: go het tu, khong goi mang them', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final (requests, indexFetches) = await pumpSheet(tester, userId: 101, words: _words);

    expect(indexFetches(), 1);

    await tester.enterText(find.byType(TextField), 'app');
    await tester.pump();

    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('banana'), findsNothing);
    expect(indexFetches(), 1, reason: 'khong goi lai getWordIndex khi go');
    expect(requests.any((r) => r['action'] == 'searchWord'), isFalse,
        reason: 'khong goi searchWord nua');
  });

  testWidgets('khop topic_tag va khong phan biet hoa thuong', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpSheet(tester, userId: 102, words: _words);

    await tester.enterText(find.byType(TextField), 'FRU');
    await tester.pump();

    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('banana'), findsNothing);
  });

  testWidgets('xoa query thi khong hien ket qua', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpSheet(tester, userId: 103, words: _words);

    await tester.enterText(find.byType(TextField), 'ban');
    await tester.pump();
    expect(find.text('banana'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text('banana'), findsNothing);
    expect(find.text('Type to search'), findsOneWidget);
  });
}