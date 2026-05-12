import 'dart:convert';

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
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'action': action, 'data': data}),
    );

    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Server returned an invalid response.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload['error']?.toString() ?? 'Request failed';
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

  Future<bool> registerUser(String phoneNumber) async {
    return _request<bool>('registerUser', data: {'phoneNumber': phoneNumber});
  }

  Future<int?> getUserId(String phoneNumber) async {
    final value = await _request<dynamic>(
      'getUserId',
      data: {'phoneNumber': phoneNumber},
    );
    return value == null ? null : _asInt(value);
  }

  Future<bool> loginUser(String phoneNumber) async {
    return _request<bool>('loginUser', data: {'phoneNumber': phoneNumber});
  }

  Future<bool> userExists(int userId) async {
    return _request<bool>('userExists', data: {'userId': userId});
  }

  Future<int> createVocabularyGroup(int userId, String name) async {
    final id = await _request<dynamic>(
      'createVocabularyGroup',
      data: {'userId': userId, 'name': name},
    );
    return _asInt(id);
  }

  Future<List<Map<String, dynamic>>> getVocabularyGroups(int userId) async {
    final rows = await _request<List<dynamic>>(
      'getVocabularyGroups',
      data: {'userId': userId},
    );
    return rows
        .map((row) => _mapDates(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> deleteVocabularyGroup(int groupId) async {
    await _request<void>('deleteVocabularyGroup', data: {'groupId': groupId});
  }

  Future<int> createVocabularySet(
    int userId,
    String name, {
    int? groupId,
  }) async {
    final id = await _request<dynamic>(
      'createVocabularySet',
      data: {'userId': userId, 'name': name, 'groupId': groupId},
    );
    return _asInt(id);
  }

  Future<List<Map<String, dynamic>>> getVocabularySets(int userId) async {
    final rows = await _request<List<dynamic>>(
      'getVocabularySets',
      data: {'userId': userId},
    );
    return rows
        .map((row) => _mapDates(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getVocabularySetsByGroup(
    int userId,
    int groupId,
  ) async {
    final rows = await _request<List<dynamic>>(
      'getVocabularySetsByGroup',
      data: {'userId': userId, 'groupId': groupId},
    );
    return rows
        .map((row) => _mapDates(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> updateVocabularySetProgress(
    int setId,
    int progress,
    int wordCount,
  ) async {
    await _request<void>(
      'updateVocabularySetProgress',
      data: {'setId': setId, 'progress': progress, 'wordCount': wordCount},
    );
  }

  Future<void> deleteVocabularySet(int setId) async {
    await _request<void>('deleteVocabularySet', data: {'setId': setId});
  }

  Future<int> addVocabularyWord(
    int setId,
    String word,
    String pronunciation,
    String meaning, {
    String? fullDetails,
  }) async {
    final id = await _request<dynamic>(
      'addVocabularyWord',
      data: {
        'setId': setId,
        'word': word,
        'pronunciation': pronunciation,
        'meaning': meaning,
        'fullDetails': fullDetails ?? '',
      },
    );
    return _asInt(id);
  }

  Future<List<Map<String, dynamic>>> getVocabularyWords(int setId) async {
    final rows = await _request<List<dynamic>>(
      'getVocabularyWords',
      data: {'setId': setId},
    );
    return rows
        .map((row) => _mapDates(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> updateWordMastered(int wordId, bool isMastered) async {
    await _request<void>(
      'updateWordMastered',
      data: {'wordId': wordId, 'isMastered': isMastered},
    );
  }

  Future<void> deleteVocabularyWord(int wordId) async {
    await _request<void>('deleteVocabularyWord', data: {'wordId': wordId});
  }

  Future<void> updateVocabularyWordDetails({
    required int wordId,
    required String meaning,
    String? pronunciation,
    String? fullDetails,
  }) async {
    await _request<void>(
      'updateVocabularyWordDetails',
      data: {
        'wordId': wordId,
        'meaning': meaning,
        'pronunciation': pronunciation ?? '',
        'fullDetails': fullDetails ?? '',
      },
    );
  }

  Future<void> updateWordReview({
    required int wordId,
    required int reviewCount,
    required int correctStreak,
    required double easeFactor,
    required int intervalDays,
    required DateTime nextReviewDate,
    required int masteryLevel,
  }) async {
    await _request<void>(
      'updateWordReview',
      data: {
        'wordId': wordId,
        'reviewCount': reviewCount,
        'correctStreak': correctStreak,
        'easeFactor': easeFactor,
        'intervalDays': intervalDays,
        'nextReviewDate': nextReviewDate.toIso8601String(),
        'masteryLevel': masteryLevel,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getWordsDueForReview(int setId) async {
    final rows = await _request<List<dynamic>>(
      'getWordsDueForReview',
      data: {'setId': setId},
    );
    return rows
        .map((row) => _mapDates(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getAllWordsDueForReview(int userId) async {
    final rows = await _request<List<dynamic>>(
      'getAllWordsDueForReview',
      data: {'userId': userId},
    );
    return rows
        .map((row) => _mapDates(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> getReviewStats(int userId) async {
    final stats = await _request<Map<String, dynamic>>(
      'getReviewStats',
      data: {'userId': userId},
    );
    return Map<String, dynamic>.from(stats);
  }

  Future<Map<int, int>> getSetMasteryBreakdown(int setId) async {
    final raw = await _request<Map<String, dynamic>>(
      'getSetMasteryBreakdown',
      data: {'setId': setId},
    );
    return raw.map((key, value) => MapEntry(_asInt(key), _asInt(value)));
  }

  Future<List<Map<String, dynamic>>> searchWord(
    int userId,
    String query,
  ) async {
    final rows = await _request<List<dynamic>>(
      'searchWord',
      data: {'userId': userId, 'query': query},
    );
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> close() async {
    _isInitialized = false;
  }
}
