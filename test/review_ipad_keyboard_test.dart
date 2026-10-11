import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoflow/pages/review_page.dart';
import 'package:lingoflow/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('iPad: cham vao vung nhap thi xin focus o dap an', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (body['action'].toString().startsWith('get')) {
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 11,
                'word': 'apple',
                'meaning': 'quả táo',
                'ease_factor': 2.5,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{"data":null}', 200);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const ReviewPage(userId: 1),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      // Test env tu focus (autofocus) nen nut cham-de-mo-phim an di.
      // Giai focus de mo phong iPad Safari chan tu focus ngoai gesture.
      final field = tester.widget<TextField>(find.byType(TextField));
      field.focusNode?.unfocus();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Chạm vào đây để hiện bàn phím'), findsOneWidget);
      await tester.tap(find.text('Chạm vào đây để hiện bàn phím'));
      await tester.pump();

      // Trong gesture cham, focus phai roi vao o nhap de Safari mo keyboard.
      final refocused = tester.widget<TextField>(find.byType(TextField));
      expect(refocused.focusNode?.hasFocus, isTrue);
      // Xa het timer cuon 300ms cua focus de ket thuc test sach.
      await tester.pump(const Duration(milliseconds: 500));
    }, () => client);
  });
}
