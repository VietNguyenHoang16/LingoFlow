import 'dart:async';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'services/database_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/word_type_classifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// Rong hon nguong nay thi boc app trong cot mobile-o-giua-man-hinh.
  static const double _kDesktopBreakpoint = 600;
  static const double _kAppMaxWidth = 430;

  Widget? _initialScreen;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final session = await AuthService().getSession();
    if (!mounted) return;

    if (session != null) {
      final userId = session['userId'] as int;
      setState(() {
        _initialScreen = DashboardPage(userId: userId);
      });
      return;
    }

    setState(() {
      _initialScreen = const LoginPage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const BouncyScrollBehavior(),
      child: MaterialApp(
        title: 'LingoFlow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        builder: _buildAppShell,
        home: _initialScreen ?? const _LaunchScreen(),
      ),
    );
  }

  /// Tren web desktop, giu app trong mot cot ~480dp giua man hinh de giao dien
  /// giong het ban mobile (card khong bi keo ngang, bottom CTA khong dai ngoang).
  /// Mobile / man hinh hep (<=600dp) tra ve nguyen ven.
  Widget _buildAppShell(BuildContext context, Widget? child) {
    final media = MediaQuery.of(context);
    if (child == null || media.size.width <= _kDesktopBreakpoint) {
      return child ?? const SizedBox.shrink();
    }

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
          width: _kAppMaxWidth,
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
            // De widget ben trong thay dung be ngang 480dp nhu tren dien thoai.
            data: media.copyWith(size: Size(_kAppMaxWidth, media.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}

class BouncyScrollBehavior extends ScrollBehavior {
  const BouncyScrollBehavior();
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const BouncingScrollPhysics();
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      ),
    );
  }
}
