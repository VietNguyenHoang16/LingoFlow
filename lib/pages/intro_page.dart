import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'dashboard_page.dart';
import 'login_page.dart';

/// Màn intro: artwork VocabPro bay nhẹ rồi tự chuyển sang đăng nhập (hoặc
/// thẳng vào app nếu đã có phiên). Chạm vào bất kỳ đâu để bỏ qua.
class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> with TickerProviderStateMixin {
  static const _introDuration = Duration(milliseconds: 2200);
  static const _brandTop = Color(0xFF1E7FE6);
  static const _brandMid = Color(0xFF3FA3F7);
  static const _brandBottom = Color(0xFFA9E2FF);

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  Map<String, dynamic>? _session;
  bool _sessionReady = false;
  bool _introDone = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _entrance.forward();
    _loop.repeat();
    // Bat dau dem thoi gian sau khi khung hinh dau tien da ve, de tren may
    // cham khong bi cat mat intro.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _run();
    });
  }

  Future<void> _run() async {
    final sessionFuture = AuthService().getSession();
    await Future.delayed(_introDuration);
    if (!mounted) return;
    _introDone = true;
    _session = await sessionFuture.catchError((_) => null);
    _sessionReady = true;
    _maybeLeave();
  }

  void _skip() {
    if (_leaving) return;
    _introDone = true;
    _maybeLeave();
  }

  void _maybeLeave() {
    if (!mounted || _leaving || !_introDone || !_sessionReady) return;
    _leaving = true;
    final userId = _session?['userId'] as int?;
    final target = userId != null
        ? DashboardPage(userId: userId)
        : const LoginPage();
    Navigator.of(context).pushReplacement(_fadeRoute(target));
  }

  Route<void> _fadeRoute(Widget page) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 460),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _entrance.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Artwork rong ~78% man hinh, toi da 380dp (tablet/web khong bi qua to).
    final artSize = math.min(size.width * 0.78, 380.0);

    return Scaffold(
      backgroundColor: _brandTop,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skip,
        child: Semantics(
          label: 'VocabPro',
          button: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_brandTop, _brandMid, _brandBottom],
                  ),
                ),
              ),

              // Sparkles bay len cham cham.
              AnimatedBuilder(
                animation: _loop,
                builder: (context, _) => CustomPaint(
                  painter: _SparklePainter(progress: _loop.value),
                ),
              ),

              Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_entrance, _loop]),
                  builder: (context, child) {
                    final enter = Curves.easeOutCubic.transform(
                      (_entrance.value / 0.78).clamp(0.0, 1.0),
                    );
                    final bob = math.sin(_loop.value * math.pi * 2) * 7;
                    return Opacity(
                      opacity: enter,
                      child: Transform.translate(
                        offset: Offset(0, bob + (1 - enter) * 26),
                        child: Transform.scale(
                          scale: 0.9 + 0.1 * enter,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: artSize,
                        height: artSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(36),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0B4C99).withAlpha(70),
                              blurRadius: 48,
                              offset: const Offset(0, 18),
                            ),
                            BoxShadow(
                              color: Colors.white.withAlpha(60),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          'assets/images/vocabpro_intro.webp',
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          semanticLabel: 'VocabPro',
                        ),
                      ),
                      const SizedBox(height: 34),
                      _pulsingDots(),
                    ],
                  ),
                ),
              ),

              // Skip hint
              Positioned(
                bottom: 28 + MediaQuery.paddingOf(context).bottom,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _entrance,
                  builder: (context, _) => Opacity(
                    opacity: (_entrance.value - 0.5).clamp(0.0, 1.0) * 0.75,
                    child: const Text(
                      'Chạm để bắt đầu',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Be Vietnam Pro',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: Color(0xFF0B4C99),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pulsingDots() {
    return AnimatedBuilder(
      animation: _loop,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_loop.value + i * 0.18) % 1.0;
            final wave = (math.sin(phase * math.pi * 2) + 1) / 2;
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha((90 + 140 * wave).round()),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Nhung dom sang bong bong bay len, tao cam giac "vui ve, nhe nhang".
class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.progress});

  final double progress;

  static const _count = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < _count; i++) {
      final seed = i / _count;
      final speed = 0.35 + seed * 0.55;
      final t = (progress * speed + seed) % 1.0;

      // Vi tri ngang co dinh theo seed, doc di tu day len dinh.
      final x = size.width * (0.08 + 0.84 * _hash(seed));
      final y = size.height * (1.05 - t * 1.15);
      final radius = 1.6 + 3.0 * _hash(seed + 0.37);
      final opacity = (math.sin(t * math.pi) * 0.55).clamp(0.0, 1.0);

      paint.color = Colors.white.withAlpha((opacity * 255).round());
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  double _hash(double v) {
    final s = math.sin(v * 127.1 + 311.7) * 43758.5453;
    return s - s.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
