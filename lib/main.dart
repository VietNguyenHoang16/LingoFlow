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
  // Triggered after a short delay so login/session restore can finish first.
  scheduleMicrotask(_backgroundClassify);
  runApp(const MyApp());
}

void _backgroundClassify() {
  Future.delayed(const Duration(seconds: 4), () async {
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
        home: _initialScreen ?? const _LaunchScreen(),
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
