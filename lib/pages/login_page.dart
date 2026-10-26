import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'dashboard_page.dart';

/// Man dang nhap: khong dung anh, chi gradient + animation.
/// - Khoi logo & ten app troi nhe, quang sang theo nhip.
/// - The form truot len, segmented toggle truot muot.
/// - O so dien thoai co vong sang khi focus, hien dau check khi du 9 so.
/// - Nut CTA gradient co vet sang chay qua; sai so thi lac (shake) + bao loi.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  );
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  bool _isLoading = false;
  bool _isRegisterMode = false;
  bool _pressed = false;
  bool _phoneFocused = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _entrance.forward();
    _float.repeat(reverse: true);
    _drift.repeat();
    _shimmer.repeat();
    _phoneFocus.addListener(() {
      if (_phoneFocused != _phoneFocus.hasFocus) {
        setState(() => _phoneFocused = _phoneFocus.hasFocus);
      }
    });
    _phoneController.addListener(() {
      final hadError = _errorText != null;
      setState(() {
        if (hadError) _errorText = null;
      });
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    _entrance.dispose();
    _float.dispose();
    _drift.dispose();
    _shimmer.dispose();
    _shake.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // Logic
  // ---------------------------------------------------------------

  String get _digits => _phoneController.text.replaceAll(RegExp(r'\D'), '');

  bool get _isValidPhone => _digits.length == 9;

  String _formatPhoneNumber(String phone) {
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 9) digits = digits.substring(0, 9);
    return '+84$digits';
  }

  void _showError(String message) {
    HapticFeedback.mediumImpact();
    setState(() => _errorText = message);
    _shake.forward(from: 0);
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;
    if (!_isValidPhone) {
      _showError('Nhập đủ 9 số điện thoại nhé');
      _phoneFocus.requestFocus();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final db = DatabaseService();
      final formattedPhone = _formatPhoneNumber(_digits);

      if (_isRegisterMode) {
        final success = await db.registerUser(formattedPhone);
        if (!mounted) return;
        if (success) {
          setState(() {
            _isRegisterMode = false;
            _phoneController.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đăng ký thành công! Giờ bạn đăng nhập nhé.')),
          );
        } else {
          _showError('Số điện thoại này đã đăng ký');
        }
      } else {
        final result = await db.loginUser(formattedPhone);
        if (!mounted) return;
        if (result != null) {
          final userId = result['userId'] as int;
          final token = result['token'] as String;
          await AuthService().saveSession(formattedPhone, userId, token: token);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => DashboardPage(userId: userId)),
          );
          return;
        }
        _showError('Số này chưa đăng ký — thử tạo tài khoản');
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _errorText = null;
      _phoneController.clear();
    });
  }

  // ---------------------------------------------------------------
  // Animation helpers
  // ---------------------------------------------------------------

  Animation<double> _interval(double start, double end, {Curve curve = Curves.easeOutCubic}) {
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, end, curve: curve),
    );
  }

  double _shakeOffset() {
    if (!_shake.isAnimating) return 0;
    final t = _shake.value;
    return math.sin(t * math.pi * 7) * 9 * (1 - t);
  }

  // ---------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(theme),
          SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 24),
                            _buildHero(theme),
                            const SizedBox(height: 30),
                            _buildCard(theme),
                            const SizedBox(height: 22),
                            _buildFooter(theme),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF0C1210), Color(0xFF10201A), Color(0xFF0C1210)]
              : const [Color(0xFFFFFCF6), Color(0xFFF1F8F2), Color(0xFFFFFCF6)],
        ),
      ),
      child: AnimatedBuilder(
        animation: _drift,
        builder: (context, _) {
          final t = _drift.value * math.pi * 2;
          return Stack(
            children: [
              _blob(
                theme,
                size: 320,
                color: theme.colorScheme.primary,
                dx: math.sin(t) * 26,
                dy: math.cos(t * 0.8) * 30 - 40,
                top: -60,
                right: -80,
                alpha: isDark ? 40 : 52,
              ),
              _blob(
                theme,
                size: 260,
                color: theme.colorScheme.secondary,
                dx: math.cos(t * 0.9) * 30,
                dy: math.sin(t * 0.7) * 26,
                bottom: 40,
                left: -90,
                alpha: isDark ? 30 : 40,
              ),
              _blob(
                theme,
                size: 200,
                color: theme.colorScheme.tertiary,
                dx: math.sin(t * 1.1 + 1.4) * 24,
                dy: math.cos(t * 0.9 + 0.6) * 22,
                top: 220,
                left: -60,
                alpha: isDark ? 24 : 32,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _blob(
    ThemeData theme, {
    required double size,
    required Color color,
    required double dx,
    required double dy,
    required int alpha,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withAlpha(alpha), color.withAlpha(0)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(ThemeData theme) {
    return AnimatedBuilder(
      animation: Listenable.merge([_entrance, _float]),
      builder: (context, child) {
        final enter = _interval(0.05, 0.55, curve: Curves.easeOutBack).value;
        final bob = math.sin(_float.value * math.pi * 2) * 6;
        final pulse = 1 + math.sin(_float.value * math.pi * 2) * 0.05;

        return Column(
          children: [
            SizedBox(
              height: 104,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Halo
                    Transform.scale(
                      scale: pulse,
                      child: Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              theme.colorScheme.primary.withAlpha(60),
                              theme.colorScheme.primary.withAlpha(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(0, bob),
                      child: Transform.scale(
                        scale: enter.clamp(0.0, 1.3),
                        child: Opacity(
                          opacity: enter.clamp(0.0, 1.0),
                          child: Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  theme.colorScheme.primary,
                                  Color.lerp(theme.colorScheme.primary, const Color(0xFF34D399), 0.55)!,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withAlpha(70),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Center(
                              child: Icon(
                                Icons.auto_stories_rounded,
                                color: theme.colorScheme.onPrimary,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            _buildWordmark(theme),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _entrance,
              builder: (context, child) => Opacity(
                opacity: _interval(0.28, 0.75).value,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - _interval(0.28, 0.75).value)),
                  child: child,
                ),
              ),
              child: Text(
                _isRegisterMode
                    ? 'Tạo tài khoản mới, miễn phí'
                    : 'Học từ vựng thông minh mỗi ngày',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Be Vietnam Pro',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWordmark(ThemeData theme) {
    const brand = 'Vocab';
    const accent = 'Pro';

    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, _) {
        final letters = <Widget>[];
        for (var i = 0; i < brand.length; i++) {
          letters.add(_letter(brand[i], i, brand.length, theme.colorScheme.onSurface));
        }
        for (var i = 0; i < accent.length; i++) {
          letters.add(_letter(accent[i], brand.length + i, brand.length + accent.length,
              theme.colorScheme.primary));
        }
        return Row(mainAxisAlignment: MainAxisAlignment.center, children: letters);
      },
    );
  }

  Widget _letter(String char, int index, int total, Color color) {
    final delay = 0.1 + index * 0.035;
    final t = _interval(delay, delay + 0.32, curve: Curves.easeOutBack).value;
    return Transform.translate(
      offset: Offset(0, 16 * (1 - t)),
      child: Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Text(
          char,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 42,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.4,
            height: 1.05,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildCard(ThemeData theme) {
    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) {
        final t = _interval(0.32, 0.95).value;
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 30 * (1 - t)), child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withAlpha(18),
              blurRadius: 40,
              spreadRadius: -8,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModeToggle(theme),
            const SizedBox(height: 20),
            _buildPhoneField(theme),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.topCenter,
              child: _errorText == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 10, left: 4),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 15, color: theme.colorScheme.error),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _errorText!,
                              style: TextStyle(
                                fontFamily: 'Be Vietnam Pro',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            _buildSubmitButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle(ThemeData theme) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: _isRegisterMode ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withAlpha(22),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              _toggleOption(theme, 'Đăng nhập', false),
              _toggleOption(theme, 'Đăng ký', true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggleOption(ThemeData theme, String label, bool isRegister) {
    final selected = _isRegisterMode == isRegister;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selected ? null : _toggleMode,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField(ThemeData theme) {
    final valid = _isValidPhone;
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) => Transform.translate(
        offset: Offset(_shakeOffset(), 0),
        child: child,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Số điện thoại',
              style: TextStyle(
                fontFamily: 'Be Vietnam Pro',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _errorText != null
                    ? theme.colorScheme.error
                    : (_phoneFocused
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant),
                width: _phoneFocused || _errorText != null ? 1.8 : 1.2,
              ),
              boxShadow: _phoneFocused
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withAlpha(40),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🇻🇳', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        '+84',
                        style: TextStyle(
                          fontFamily: 'Be Vietnam Pro',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1.2,
                  height: 26,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _phoneController,
                      focusNode: _phoneFocus,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(9),
                      ],
                      onSubmitted: (_) => _handleSubmit(),
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        letterSpacing: 0.4,
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: '9xx xxx xxx',
                        counterText: '',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        hintStyle: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          letterSpacing: 0.4,
                          color: theme.colorScheme.onSurfaceVariant.withAlpha(110),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  scale: valid ? 1 : 0.2,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: valid ? 1 : 0,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 22,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(ThemeData theme) {
    final label = _isRegisterMode ? 'Tạo tài khoản' : 'Tiếp tục';
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: _isLoading ? null : _handleSubmit,
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                theme.colorScheme.primary,
                Color.lerp(theme.colorScheme.primary, const Color(0xFF10B981), 0.65)!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withAlpha(_pressed ? 45 : 85),
                blurRadius: _pressed ? 14 : 24,
                offset: Offset(0, _pressed ? 6 : 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AnimatedBuilder(
              animation: _shimmer,
              builder: (context, child) {
                final dx = -1.4 + 2.8 * _shimmer.value;
                return ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment(dx - 0.5, -0.4),
                    end: Alignment(dx + 0.5, 0.4),
                    colors: [
                      Colors.white.withAlpha(0),
                      Colors.white.withAlpha(64),
                      Colors.white.withAlpha(0),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ).createShader(rect),
                  child: child,
                );
              },
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _isLoading
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: theme.colorScheme.onPrimary,
                            strokeWidth: 2.6,
                          ),
                        )
                      : Row(
                          key: ValueKey('label-$_isRegisterMode'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontWeight: FontWeight.w800,
                                fontSize: 16.5,
                                letterSpacing: 0.1,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 20,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) => Opacity(
        opacity: _interval(0.6, 1).value,
        child: child,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded, size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            'Miễn phí • Không quảng cáo • Bảo mật',
            style: TextStyle(
              fontFamily: 'Be Vietnam Pro',
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
