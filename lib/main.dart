import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'pages/intro_page.dart';
import 'services/database_service.dart';
import 'services/auth_service.dart';
import 'services/display_settings_service.dart';
import 'services/notification_service.dart';
import 'services/word_type_classifier.dart';
import 'widgets/tts_audio_unlocker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nap co chu da luu truoc khung hinh dau tien de chu khong bi nhay co.
  await DisplaySettingsService.instance.load(
    screenWidth: _initialScreenWidth(),
  );
  unawaited(
    DatabaseService().init().catchError((e) {
      debugPrint('Database connection failed: $e');
    }),
  );
  unawaited(
    NotificationService().init().catchError((e) {
      debugPrint('Notification init failed: $e');
    }),
  );
  // Background classify existing words once per app launch.
  // Delayed long enough that the first screens finish their network loads first.
  scheduleMicrotask(_backgroundClassify);
  runApp(const MyApp());
}

double _initialScreenWidth() {
  try {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    if (view.devicePixelRatio <= 0) return 0;
    return view.physicalSize.width / view.devicePixelRatio;
  } catch (_) {
    return 0;
  }
}

void _backgroundClassify() {
  Future.delayed(const Duration(seconds: 20), () async {
    try {
      final session = await AuthService().getSession();
      if (session == null) return;
      final userId = session['userId'] as int;
      final classified = await WordTypeClassifier().classifyAllUntagged(
        userId: userId,
      );
      debugPrint('Background classifier finished: $classified words updated');
    } catch (e) {
      debugPrint('Background classifier failed: $e');
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const BouncyScrollBehavior(),
      child: MaterialApp(
        title: 'VocabPro',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        // Boc toan app de bat lai audio doc sau khi iOS suspend (xem
        // TtsAudioUnlocker): chi can cham bat ky dau la tieng doc hoat dong lai.
        builder: (context, child) {
          final app = TtsAudioUnlocker(
            child: ValueListenableBuilder<double>(
              valueListenable: DisplaySettingsService.instance.textScale,
              builder: (context, textScale, _) =>
                  _buildAppShell(context, child, textScale),
            ),
          );
          if (!kIsWeb) return app;
          // Web: cham vao nut khac trong luc o nhap dang focus khong duoc lam
          // mat focus ngay o pointer-down. iPad Safari dong keyboard -> viewport
          // doi kich thuoc giua gesture -> cu cham bi huy (phai cham 2 lan,
          // man hinh nhay). Gom ca app (ke ca dialog) vao 1 tap region cua o
          // nhap mac dinh; viec dong keyboard do code chu dong goi unfocus.
          return TextFieldTapRegion(groupId: EditableText, child: app);
        },
        home: const IntroPage(),
      ),
    );
  }
}

/// Rong hon nguong nay thi boc app trong cot mobile-o-giua-man-hinh.
const double _kDesktopBreakpoint = 600;
const double _kAppMaxWidth = 430;

/// Tren web desktop, giu app trong mot cot giua man hinh de giao dien giong
/// het ban mobile (card khong bi keo ngang, bottom CTA khong dai ngoang).
/// Mobile / man hinh hep (<=600dp) tra ve nguyen ven.
///
/// Co chu `textScale` (Settings > Co chu) duoc ap cho toan app. Tren iPad, cung
/// mot co chu se hien nho hon nhieu so voi dien thoai nen mac dinh o day la
/// 1.3x; cot app duoc no rong tuong ung de chu to ma khong bi tran.
Widget _buildAppShell(BuildContext context, Widget? child, double textScale) {
  final media = MediaQuery.of(context);
  if (child == null) return const SizedBox.shrink();

  final scaler =
      TextScaler.linear(media.textScaler.scale(1.0) * textScale);

  if (media.size.width <= _kDesktopBreakpoint) {
    return MediaQuery(
      data: media.copyWith(textScaler: scaler),
      child: child,
    );
  }

  final columnWidth =
      math.min(_kAppMaxWidth * textScale, media.size.width);
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF07110E), Color(0xFF0C1210)]
            : const [Color(0xFFF2EDE1), Color(0xFFE6F3EB)],
      ),
    ),
    child: Center(
      child: Container(
        width: columnWidth,
        height: media.size.height,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.symmetric(
            vertical: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withAlpha(120)
                  : const Color(0xFF3B2F1F).withAlpha(28),
              blurRadius: 48,
              spreadRadius: -8,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: MediaQuery(
          // De widget ben trong thay dung be ngang cot app nhu tren dien thoai.
          data: media.copyWith(
            size: Size(columnWidth, media.size.height),
            textScaler: scaler,
          ),
          child: child,
        ),
      ),
    ),
  );
}

class BouncyScrollBehavior extends ScrollBehavior {
  const BouncyScrollBehavior();
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const BouncingScrollPhysics();
}
