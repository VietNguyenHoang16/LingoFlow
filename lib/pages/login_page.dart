import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isRegisterMode = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String phone) {
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 9) digits = digits.substring(0, 9);
    return '+84$digits';
  }

  bool _isValidPhone(String phone) {
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length == 9;
  }

  Future<void> _handleSubmit() async {
    final phone = _phoneController.text.trim();
    if (!_isValidPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui long nhap du 9 so')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final db = DatabaseService();
      final formattedPhone = _formatPhoneNumber(phone);

      if (_isRegisterMode) {
        final success = await db.registerUser(formattedPhone);
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Dang ky thanh cong!')),
            );
            setState(() {
              _isRegisterMode = false;
              _phoneController.clear();
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('So dien thoai da dang ky')),
            );
          }
        }
      } else {
        final success = await db.loginUser(formattedPhone);
        if (success) {
          if (mounted) {
            final userId = await db.getUserId(formattedPhone);
            if (userId == null) throw Exception('User session error.');
            await AuthService().saveSession(formattedPhone, userId);
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DashboardPage(userId: userId),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('So dien thoai chua dang ky')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loi: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // Background decorative blobs
          Positioned(
            top: -size.height * 0.08,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.7,
              height: size.width * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withAlpha(isDark ? 20 : 25),
              ),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.05,
            left: -size.width * 0.15,
            child: Container(
              width: size.width * 0.55,
              height: size.width * 0.55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    theme.colorScheme.secondary.withAlpha(isDark ? 20 : 30),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      children: [
                        const SizedBox(height: 48),

                        // Logo + App name
                        _buildHeroSection(theme),

                        const SizedBox(height: 40),

                        // Form card
                        _buildFormCard(theme),

                        const SizedBox(height: 24),

                        // Toggle login/register
                        _buildToggleRow(theme),

                        const SizedBox(height: 32),
                      ],
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

  Widget _buildHeroSection(ThemeData theme) {
    return Column(
      children: [
        // App icon
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withAlpha(80),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '🦉',
              style: TextStyle(fontSize: 44),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // App name
        Text(
          'LingoFlow',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isRegisterMode
              ? 'Tao tai khoan moi - Mien phi'
              : 'Hoc tu vung thong minh moi ngay',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Be Vietnam Pro',
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1.5,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: theme.colorScheme.primary.withAlpha(12),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isRegisterMode ? 'Dang ky' : 'Dang nhap',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nhap so dien thoai cua ban',
            style: TextStyle(
              fontFamily: 'Be Vietnam Pro',
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Phone input label
          Text(
            'So dien thoai',
            style: TextStyle(
              fontFamily: 'Be Vietnam Pro',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),

          // Phone input
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: theme.colorScheme.outlineVariant, width: 1.5),
            ),
            child: Row(
              children: [
                // Country code prefix
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                        width: 1.5,
                      ),
                    ),
                  ),
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
                // Text field
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 9,
                      decoration: InputDecoration(
                        hintText: '9xx xxx xxx',
                        counterText: '',
                        hintStyle: TextStyle(
                          fontFamily: 'Be Vietnam Pro',
                          color: theme.colorScheme.onSurfaceVariant
                              .withAlpha(120),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(
                        fontFamily: 'Be Vietnam Pro',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                disabledBackgroundColor:
                    theme.colorScheme.primary.withAlpha(100),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.onPrimary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      _isRegisterMode ? 'Tao tai khoan' : 'Tiep tuc',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isRegisterMode ? 'Da co tai khoan? ' : 'Chua co tai khoan? ',
          style: TextStyle(
            fontFamily: 'Be Vietnam Pro',
            fontSize: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        GestureDetector(
          onTap: () => setState(() {
            _isRegisterMode = !_isRegisterMode;
            _phoneController.clear();
          }),
          child: Text(
            _isRegisterMode ? 'Dang nhap' : 'Dang ky ngay',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
