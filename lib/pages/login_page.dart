import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isRegisterMode = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String phone) {
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 9) {
      digits = digits.substring(0, 9);
    }
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
        const SnackBar(
          content: Text('Vui lòng nhập đủ 9 số'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = DatabaseService();
      final formattedPhone = _formatPhoneNumber(phone);

      if (_isRegisterMode) {
        final success = await db.registerUser(formattedPhone);
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đăng ký thành công!'),
                backgroundColor: Colors.green,
              ),
            );
            setState(() => _isRegisterMode = false);
            _phoneController.clear();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Số điện thoại đã đăng ký'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        final success = await db.loginUser(formattedPhone);
        if (success) {
          if (mounted) {
            final userId = await db.getUserId(formattedPhone);
            if (userId == null) {
              throw Exception('User session could not be resolved.');
            }
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
              const SnackBar(
                content: Text('Số điện thoại chưa đăng ký'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
                      ),
                      Text(
                        _isRegisterMode ? 'Register' : 'Login',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'LingoFlow',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        Container(
                          width: 280,
                          height: 280,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              'https://lh3.googleusercontent.com/aida-public/AB6AXuDyrEXAFZSt7L2Hpmk8m9LBzxgTL8I88j9aMxrpp4_EG8BQ_pxBAx4FWfmsgRc4HsoTiNZcqbxcpy5_kg6cDpRW0BHeMkULm3KG7NepCxVKMVt1DeVKcvInJ1k23-_IrAVBbCUzw75lTgcaauq2i5qFQuTY-KWyWCSnZfGbmYj-w3moYQETSrVcHsLKpdwP1U1D6HN3YD8ihLfwpO7AhsqslIZmmfZ86DvAYzxpKq1N8O9RkETBlz2w5q9JjqU2JBkPUIrDi59TUtun',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(
                                    Icons.image,
                                    size: 80,
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _isRegisterMode
                              ? 'Create Account'
                              : 'Welcome to LingoFlow',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isRegisterMode
                              ? 'Enter your phone number to create account'
                              : 'Master English with the most personalized cognitive lounge experience.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Be Vietnam Pro',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 16, bottom: 8),
                              child: Text(
                                'Phone Number',
                                style: TextStyle(
                                  fontFamily: 'Be Vietnam Pro',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Container(
                              height: 64,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant.withAlpha(76),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(
                                          color: theme.colorScheme.outlineVariant.withAlpha(76),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Text('🇻🇳', style: TextStyle(fontSize: 18)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '+84',
                                          style: TextStyle(
                                            fontFamily: 'Be Vietnam Pro',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.expand_more,
                                          size: 18,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: TextField(
                                        controller: _phoneController,
                                        keyboardType: TextInputType.phone,
                                        maxLength: 9,
                                        decoration: InputDecoration(
                                          hintText: 'Enter your number',
                                          counterText: '',
                                          hintStyle: TextStyle(
                                            fontFamily: 'Be Vietnam Pro',
                                            fontWeight: FontWeight.normal,
                                            color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                                          ),
                                          border: InputBorder.none,
                                        ),
                                        style: TextStyle(
                                          fontFamily: 'Be Vietnam Pro',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 64,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: theme.colorScheme.onPrimary,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isRegisterMode
                                        ? 'Create Account'
                                        : 'Get Verification Code',
                                    style: const TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 48),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color: theme.colorScheme.outlineVariant.withAlpha(51),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Or login with',
                                style: TextStyle(
                                  fontFamily: 'Be Vietnam Pro',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: theme.colorScheme.outlineVariant.withAlpha(51),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSocialButton(
                              'https://lh3.googleusercontent.com/aida-public/AB6AXuDk-MvnR8gFA_c65RP-GgBurD0JK9pEHU4ZoEeFYi6SMICUXNSsQ9gawRTmFlyXUbqmXPOLqr_Zl9j6sIZ6jFuIXFdsHX5NJAAQTkfYv19KiQS1XcMJ5tzKv8av2JEeGzm0TdBOP_sOqj4cnubUXTJRAVQALeuC9WPUy5-sIzDI9L3xKqioJpJuS4d2h2Wx9PqyLUN93cvrVkWC8DuAkZ91q-A3kbAz2A1IP60RZu8Jex-lD6VaaFjugYm_au6N4aHF5UXJR3PEtBYT',
                            ),
                            const SizedBox(width: 24),
                            _buildSocialButton(
                              'https://lh3.googleusercontent.com/aida-public/AB6AXuC6DogXHQokPbNIEiVzWl0M4h5Icr8OsggZEB4qOp8Qezv3zkrTyUbIOhh41G9R8RBMWaLPr4SrH0F51Y2MPDTq51M1BKpa68acnpRPXreKBXaF6ni-rwzZK09Dp973Raj3qA5ssVNFP6qhUZezj9UqKRdaJOEzR_eYEWbmEyvXReSw3IJIJRP6JXvYsVA59mtK5vQ_bbiEP8gW71GYUIA40Q0J55pAplFhdDedSlQ1Z5uyY9jJVlJZi9Yw2KfW8XC9j2dOVUzEz-Aa',
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isRegisterMode = !_isRegisterMode;
                              _phoneController.clear();
                            });
                          },
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontFamily: 'Be Vietnam Pro',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              children: [
                                TextSpan(
                                  text: _isRegisterMode
                                      ? 'Already have account? '
                                      : 'New to LingoFlow? ',
                                ),
                                TextSpan(
                                  text: _isRegisterMode
                                      ? 'Login'
                                      : 'Create an account',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton(String imageUrl) {
    final theme = Theme.of(context);
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.image, size: 28, color: theme.colorScheme.onSurfaceVariant);
          },
        ),
      ),
    );
  }
}
