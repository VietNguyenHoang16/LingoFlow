import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  bool _isInitialized = false;

  static const String _mobileApiBaseUrl = String.fromEnvironment(
    'LINGOFLOW_API_BASE_URL',
    defaultValue: 'https://vocab-virid.vercel.app',
  );
  static String get _endpoint {
    if (kIsWeb) return '/api/lingoflow';
    return '$_mobileApiBaseUrl/api/lingoflow';
  }

  Future<void> init() async {
    if (_isInitialized) return;
    await _request<void>('init');
    _isInitialized = true;
  }

  Future<T> _request<T>(
    String action, {
    Map<String, dynamic> data = const {},
  }) async {
    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'action': action, 'data': data}),
          )
          .timeout(const Duration(seconds: 15));
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('SocketException') ||
          msg.contains('Connection refused') ||
          msg.contains('NetworkException') ||
          msg.contains('TimeoutException') ||
          msg.contains('HandshakeException')) {
        throw Exception('Khong co ket noi mang. Kiem tra WiFi / mobile data va thu lai.');
      }
      rethrow;
    }

    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Server tra ve phan hoi khong hop le (HTTP ${response.statusCode}).');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload['error']?.toString() ?? 'Request that bai (HTTP ${response.statusCode})';
      throw Exception(message);
    }

    return payload['data'] as T;
  }

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  Map<String, dynamic> _mapDates(Map<String, dynamic> row) {
    final mapped = Map<String, dynamic>.from(row);
    for (final key in const [
      'lastPracticed',
      'next_review_date',
      'last_reviewed_at',
    ]) {
      if (mapped.containsKey(key)) {
        mapped[key] = _parseDate(mapped[key]);
      }
    }
    return mapped;
  }

  // ---- Auth ----
  Future<bool> registerUser(String phoneNumber) async {
    return _request<bool>('registerUser', data: {'phoneNumber': phoneNumber});
  }

  Future<int?> getUserId(String phoneNumber) async {
    final value = await _request<dynamic>('getUserId', data: {'phoneNumber': phoneNumber});
    return value == null ? null : _asInt(value);
  }

  Future<bool> loginUser(String phoneNumber) async {
    return _request<bool>('loginUser', data: {'phoneNumber': phoneNumber});
  }

  Future<bool> userExists(int userId) async {
    return _request<bool>('userExists', data: {'userId': userId});
  }

  // ---- Lists ----
  Future<int> createList(int userId, String category, String name) async {
    final id = await _request<dynamic>('createList', data: {'userId': userId, 'category': category, 'name': name});
    return _asInt(id);
  }

  Future<List<Map<String, dynamic>>> getListsByCategory(int userId, String category) async {
    final rows = await _request<List<dynamic>>('getListsByCategory', data: {'userId': userId, 'category': category});
    return rows.map((row) => _mapDates(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<List<Map<String, dynamic>>> getAllLists(int userId) async {
    final rows = await _request<List<dynamic>>('getAllLists', data: {'userId': userId});
    return rows.map((row) => _mapDates(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<void> updateListProgress(int listId, int progress, int wordCount) async {
    await _request<void>('updateListProgress', data: {'listId': listId, 'progress': progress, 'wordCount': wordCount});
  }

  Future<void> deleteList(int listId) async {
    await _request<void>('deleteList', data: {'listId': listId});
  }

  // ---- Categories ----
  Future<Map<String, dynamic>> getCategoryStats(int userId) async {
    final stats = await _request<Map<String, dynamic>>('getCategoryStats', data: {'userId': userId});
    return Map<String, dynamic>.from(stats);
  }

  // ---- Words ----
  Future<int> addVocabularyWord(
    int listId,
    String word,
    String pronunciation,
    String meaning, {
    String? fullDetails,
    String? wordType,
  }) async {
    final id = await _request<dynamic>('addVocabularyWord', data: {
      'listId': listId,
      'word': word,
      'pronunciation': pronunciation,
      'meaning': meaning,
      'fullDetails': fullDetails ?? '',
      'wordType': wordType ?? '',
    });
    return _asInt(id);
  }

  Future<int> addWordToCategory(
    int userId,
    String category,
    String word,
    String pronunciation,
    String meaning, {
    String? fullDetails,
    String? wordType,
  }) async {
    final id = await _request<dynamic>('addVocabularyWord', data: {
      'userId': userId,
      'category': category,
      'word': word,
      'pronunciation': pronunciation,
      'meaning': meaning,
      'fullDetails': fullDetails ?? '',
      'wordType': wordType ?? '',
    });
    return _asInt(id);
  }

  Future<List<Map<String, dynamic>>> getVocabularyWords(int listId) async {
    final rows = await _request<List<dynamic>>('getVocabularyWords', data: {'listId': listId});
    return rows.map((row) => _mapDates(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<List<Map<String, dynamic>>> getWordsByCategory(int userId, String category) async {
    final rows = await _request<List<dynamic>>('getWordsByCategory', data: {'userId': userId, 'category': category});
    return rows.map((row) => _mapDates(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<void> updateWordMastered(int wordId, bool isMastered) async {
    await _request<void>('updateWordMastered', data: {'wordId': wordId, 'isMastered': isMastered});
  }

  Future<void> updateWordDifficult(int wordId, bool isDifficult) async {
    await _request<void>('updateWordDifficult', data: {'wordId': wordId, 'isDifficult': isDifficult});
  }

  Future<void> deleteVocabularyWord(int wordId) async {
    await _request<void>('deleteVocabularyWord', data: {'wordId': wordId});
  }

  Future<void> updateVocabularyWordDetails({
    required int wordId,
    required String meaning,
    String? pronunciation,
    String? fullDetails,
    String? wordType,
  }) async {
    await _request<void>('updateVocabularyWordDetails', data: {
      'wordId': wordId,
      'meaning': meaning,
      'pronunciation': pronunciation ?? '',
      'fullDetails': fullDetails ?? '',
      'wordType': wordType ?? '',
    });
  }

  Future<void> updateVocabularyWord({
    required int wordId,
    required String word,
    required String meaning,
    String? pronunciation,
    String? fullDetails,
    String? wordType,
  }) async {
    await _request<void>('updateVocabularyWord', data: {
      'wordId': wordId,
      'word': word,
      'meaning': meaning,
      'pronunciation': pronunciation ?? '',
      'fullDetails': fullDetails ?? '',
      'wordType': wordType ?? '',
    });
  }

  Future<void> updateWordReview({
    required int wordId,
    required int reviewCount,
    required int correctStreak,
    required double easeFactor,
    required int intervalDays,
    required DateTime nextReviewDate,
    required int masteryLevel,
    required int lapseCount,
  }) async {
    await _request<void>('updateWordReview', data: {
      'wordId': wordId,
      'reviewCount': reviewCount,
      'correctStreak': correctStreak,
      'easeFactor': easeFactor,
      'intervalDays': intervalDays,
      'nextReviewDate': nextReviewDate.toIso8601String(),
      'masteryLevel': masteryLevel,
      'lapseCount': lapseCount,
    });
  }

  // ---- Review ----
  Future<List<Map<String, dynamic>>> getWordsDueForReview(int listId) async {
    final rows = await _request<List<dynamic>>('getWordsDueForReview', data: {'listId': listId});
    return rows.map((row) => _mapDates(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<List<Map<String, dynamic>>> getAllWordsDueForReview(int userId) async {
    final rows = await _request<List<dynamic>>('getAllWordsDueForReview', data: {'userId': userId});
    return rows.map((row) => _mapDates(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<List<Map<String, dynamic>>> getWordsDueForReviewByCategory(int userId, String category) async {
    final rows = await _request<List<dynamic>>('getWordsDueForReviewByCategory', data: {'userId': userId, 'category': category});
    return rows.map((row) => _mapDates(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<Map<String, dynamic>> getReviewStats(int userId) async {
    final stats = await _request<Map<String, dynamic>>('getReviewStats', data: {'userId': userId});
    return Map<String, dynamic>.from(stats);
  }

  Future<Map<int, int>> getListMasteryBreakdown(int listId) async {
    final raw = await _request<Map<String, dynamic>>('getListMasteryBreakdown', data: {'listId': listId});
    return raw.map((key, value) => MapEntry(_asInt(key), _asInt(value)));
  }

  Future<Map<int, int>> getCategoryMasteryBreakdown(int userId, String category) async {
    final raw = await _request<Map<String, dynamic>>('getCategoryMasteryBreakdown', data: {'userId': userId, 'category': category});
    return raw.map((key, value) => MapEntry(_asInt(key), _asInt(value)));
  }

  // ---- Search ----
  Future<List<Map<String, dynamic>>> searchWord(int userId, String query) async {
    final rows = await _request<List<dynamic>>('searchWord', data: {'userId': userId, 'query': query});
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> close() async {
    _isInitialized = false;
  }
}
