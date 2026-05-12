import 'dart:async';
import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'services/database_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

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
  runApp(const MyApp());
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
    return MaterialApp(
      title: 'LingoFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4a40e0)),
        useMaterial3: true,
      ),
      home: _initialScreen ?? const _LaunchScreen(),
    );
  }
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFfaf4ff),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF4a40e0),
        ),
      ),
    );
  }
}
