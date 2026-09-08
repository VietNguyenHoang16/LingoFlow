import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/widgets/topic_tag_badge.dart';

void main() {
  testWidgets('hiện tên nhãn khi có tag', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TopicTagBadge(tag: 'gym'))),
    );
    expect(find.text('gym'), findsOneWidget);
  });

  testWidgets('ẩn khi tag rỗng', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TopicTagBadge(tag: ''))),
    );
    expect(find.byType(Text), findsNothing);
  });
}
