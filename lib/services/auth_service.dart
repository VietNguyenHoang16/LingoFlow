import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _phoneKey = 'logged_in_phone';
  static const String _userIdKey = 'logged_in_user_id';
  static const String _tokenKey = 'auth_token';

  Future<void> saveSession(String phoneNumber, int userId, {String? token}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phoneKey, phoneNumber);
    await prefs.setInt(_userIdKey, userId);
    if (token != null) {
      await prefs.setString(_tokenKey, token);
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<Map<String, dynamic>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_phoneKey);
    final userId = prefs.getInt(_userIdKey);

    if (phone != null && userId != null) {
      return {
        'phone': phone,
        'userId': userId,
      };
    }
    return null;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_phoneKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_tokenKey);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_phoneKey) && prefs.containsKey(_userIdKey);
  }
}