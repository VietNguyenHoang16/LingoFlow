// Regression: banner 2 nut on tap tren Dashboard phai render duoc trong
// CustomScrollView (chieu cao unbounded). Bug that: Column + Spacer ben trong
// SliverToBoxAdapter -> RenderFlex exception -> home screen trang.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/theme/app_theme.dart';
import 'package:lingoflow/widgets/review_banner_buttons.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: child),
        ],
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ReviewBannerButtons render trong CustomScrollView (unbounded height)', (tester) async {
    await tester.pumpWidget(_wrap(
      ReviewBannerButtons(
        dueWords: 3,
        dueGrammar: 2,
        onWordsReview: () {},
        onGrammarReview: () {},
      ),
    ));

    expect(find.text('Time to review!'), findsOneWidget);
    expect(find.text('Grammar time!'), findsOneWidget);
    expect(find.text('3 words due'), findsOneWidget);
    expect(find.text('2 structures due'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Trang thai 0: hien All done! cho tung nut rieng', (tester) async {
    await tester.pumpWidget(_wrap(
      ReviewBannerButtons(
        dueWords: 0,
        dueGrammar: 0,
        onWordsReview: () {},
        onGrammarReview: () {},
      ),
    ));

    expect(find.text('All done!'), findsNWidgets(2));
    expect(find.text('Keep your streak going!'), findsOneWidget);
    expect(find.text('No structures due!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RenderFlex unbounded khong xay ra trong khung cao co dinh', (tester) async {
    // Dam bao widget cung render duoc trong khung chat (Scaffold body thong thuong).
    await tester.pumpWidget(_wrap(
      SizedBox(
        height: 200,
        child: ReviewBannerButtons(
          dueWords: 1,
          dueGrammar: 0,
          onWordsReview: () {},
          onGrammarReview: () {},
        ),
      ),
    ));

    expect(find.text('Time to review!'), findsOneWidget);
    expect(find.text('All done!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
