import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'ai_settings_service.dart';
import 'auth_service.dart';

class BulkAddFailure {
  final String word;
  final String message;
  final bool retryable;

  const BulkAddFailure({
    required this.word,
    required this.message,
    this.retryable = false,
  });
}

class BulkAddResult {
  final int insertedCount;
  final List<BulkAddFailure> failed;

  const BulkAddResult({required this.insertedCount, this.failed = const []});
}

/// Nghia tieng Viet + loai tu + loai hoc do AI lay cho mot tu. `error` khac
/// rong khi AI khong tra ve duoc (client bo qua tu do va bao lai).
class AiWordInfo {
  final String word;
  final String meaning;
  final String wordType;

  /// 'active' = Hoc ngay, 'passive' = Nen biet, 'skip' = Khong uu tien.
  final String learningMode;
  final String collocations;
  final String error;

  const AiWordInfo({
    required this.word,
    required this.meaning,
    required this.wordType,
    this.learningMode = 'active',
    this.collocations = '',
    this.error = '',
  });

  bool get isUsable => meaning.isNotEmpty && wordType.isNotEmpty;
}

/// Tu da co trong bo tu cua user (dung khi import bi trung): kem nghia + loai
/// tu da luu de bang import hien thi duoc.
class ExistingWord {
  final String word;
  final String meaning;
  final String wordType;

  const ExistingWord({
    required this.word,
    this.meaning = '',
    this.wordType = '',
  });
}

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  bool _isInitialized = false;

  /// Cache getWordIndex theo userId; xoa khi co action sua du lieu tu.
  static final Map<int, List<Map<String, dynamic>>> _wordIndexCache = {};
  static const Set<String> _wordIndexMutations = {
    'addVocabularyWord',
    'bulkAddWords',
    'bulkDeleteWords',
    'deleteVocabularyWord',
    'updateVocabularyWord',
    'updateVocabularyWordDetails',
    'deleteList',
  };

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
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final token = await AuthService().getToken();
    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'action': action, 'data': data}),
          )
          .timeout(timeout);
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

    if (response.statusCode == 401) {
      await AuthService().clearSession();
      throw Exception('Phien dang nhap het han. Vui long dang nhap lai.');
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

    if (_wordIndexMutations.contains(action)) {
      _wordIndexCache.clear();
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

  Map<String, String>? _parseExample(dynamic value) {
    if (value is! Map) return null;
    return {
      'sentence': (value['sentence'] ?? '').toString(),
      'translation': (value['translation'] ?? '').toString(),
      'target': (value['target'] ?? '').toString(),
    };
  }

  Map<String, dynamic> _mapDates(Map<String, dynamic> row) {
    final mapped = Map<String, dynamic>.from(row);
    for (final key in const [
      'lastPracticed',
      'next_review_date',
      'last_reviewed_at',
      'created_at',
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

  Future<Map<String, dynamic>?> loginUser(String phoneNumber) async {
    final value = await _request<dynamic>('loginUser', data: {'phoneNumber': phoneNumber});
    if (value == null) return null;
    return Map<String, dynamic>.from(value as Map);
  }

  // ---- Lists ----
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
  /// Gop category stats + review stats trong 1 request.
  Future<({Map<String, dynamic> categoryStats, Map<String, dynamic> reviewStats})>
      getDashboardStats(int userId) async {
    final result = await _request<Map<String, dynamic>>(
      'getDashboardStats',
      data: {'userId': userId},
    );
    return (
      categoryStats: Map<String, dynamic>.from(result['categoryStats'] as Map),
      reviewStats: Map<String, dynamic>.from(result['reviewStats'] as Map),
    );
  }

  // ---- Words ----
  Future<int> addVocabularyWord(
    int listId,
    String word,
    String pronunciation,
    String meaning, {
    String? fullDetails,
    String? wordType,
    String? topicTag,
    String? commonSynonyms,
  }) async {
    final id = await _request<dynamic>('addVocabularyWord', data: {
      'listId': listId,
      'word': word,
      'pronunciation': pronunciation,
      'meaning': meaning,
      'fullDetails': fullDetails ?? '',
      'wordType': wordType ?? '',
      'topicTag': topicTag ?? '',
      'commonSynonyms': commonSynonyms ?? '',
    }, timeout: const Duration(seconds: 45));
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
    String? topicTag,
    String? commonSynonyms,
  }) async {
    final id = await _request<dynamic>('addVocabularyWord', data: {
      'userId': userId,
      'category': category,
      'word': word,
      'pronunciation': pronunciation,
      'meaning': meaning,
      'fullDetails': fullDetails ?? '',
      'wordType': wordType ?? '',
      'topicTag': topicTag ?? '',
      'commonSynonyms': commonSynonyms ?? '',
    }, timeout: const Duration(seconds: 45));
    return _asInt(id);
  }

  /// Lay nghia tieng Viet + loai tu cho nhieu tu cung luc (AI).
  Future<List<AiWordInfo>> enrichWords(List<String> words) async {
    if (words.isEmpty) return const [];
    final rows = await _request<List<dynamic>>(
      'enrichWords',
      data: {'words': words},
      timeout: const Duration(seconds: 75),
    );
    return rows.whereType<Map>().map((row) {
      return AiWordInfo(
        word: (row['word'] ?? '').toString(),
        meaning: (row['meaning'] ?? '').toString().trim(),
        wordType: (row['wordType'] ?? '').toString().trim(),
        learningMode: (row['learningMode'] ?? '').toString().trim(),
        collocations: (row['collocations'] ?? '').toString().trim(),
        error: (row['error'] ?? '').toString(),
      );
    }).toList();
  }

  /// Kiem tra nhieu tu cung luc - tra ve cac tu da ton tai (lowercase).
  Future<Set<String>> filterExistingWords(int userId, List<String> words) async {
    if (words.isEmpty) return {};
    final rows = await _request<List<dynamic>>(
      'filterExistingWords',
      data: {'userId': userId, 'words': words},
    );
    return rows.map((w) => w.toString()).toSet();
  }

  /// Nhu [filterExistingWords] nhung kem nghia + loai tu da luu, de bang import
  /// hien thi duoc nghia cua tu bi trung ngay tai dong do.
  Future<List<ExistingWord>> findExistingWords(
    int userId,
    List<String> words,
  ) async {
    if (words.isEmpty) return const [];
    final rows = await _request<List<dynamic>>(
      'filterExistingWordsDetailed',
      data: {'userId': userId, 'words': words},
    );
    return rows.whereType<Map>().map((row) {
      return ExistingWord(
        word: (row['word'] ?? '').toString(),
        meaning: (row['meaning'] ?? '').toString().trim(),
        wordType: (row['wordType'] ?? '').toString().trim(),
      );
    }).toList();
  }

  /// Them hang loat vao mot list. Tra ve so tu chen + danh sach tu loi.
  Future<BulkAddResult> bulkAddVocabularyWords(int listId, List<Map<String, dynamic>> words) async {
    final result = await _request<Map<String, dynamic>>(
      'bulkAddWords',
      data: {'listId': listId, 'words': words},
      timeout: const Duration(seconds: 60),
    );
    return _bulkResult(result);
  }

  /// Them hang loat theo category. Tra ve so tu chen + danh sach tu loi.
  Future<BulkAddResult> bulkAddCategoryWords(
    int userId,
    String category,
    List<Map<String, dynamic>> words,
  ) async {
    final result = await _request<Map<String, dynamic>>(
      'bulkAddWords',
      data: {'userId': userId, 'category': category, 'words': words},
      timeout: const Duration(seconds: 60),
    );
    return _bulkResult(result);
  }

  BulkAddResult _bulkResult(Map<String, dynamic> result) {
    final raw = result['failed'];
    final failed = raw is List
        ? raw
            .whereType<Map>()
            .map((row) => BulkAddFailure(
                  word: (row['word'] ?? '').toString(),
                  message: (row['message'] ?? '').toString(),
                  retryable: row['retryable'] == true,
                ))
            .toList()
        : <BulkAddFailure>[];
    return BulkAddResult(
      insertedCount: _asInt(result['insertedCount']),
      failed: failed,
    );
  }

  Future<Map<String, dynamic>> testAiProvider(AiProviderConfig config) async {
    return _request<Map<String, dynamic>>(
      'testAiProvider',
      data: config.toApiJson(),
      timeout: const Duration(seconds: 20),
    );
  }

  Future<List<AiProviderConfig>> getAiConfigs() async {
    final rows = await _request<List<dynamic>>('getAiConfigs');
    return rows
        .whereType<Map>()
        .map((row) => AiProviderConfig.fromJson(Map<String, dynamic>.from(row)))
        .where((config) => config.isComplete)
        .take(AiProviderConfig.maxProviders)
        .toList();
  }

  Future<void> saveAiConfigs(List<AiProviderConfig> configs) async {
    await _request<dynamic>('saveAiConfigs', data: {
      'configs': configs
          .where((config) => config.isComplete)
          .take(AiProviderConfig.maxProviders)
          .map((config) => config.toApiJson())
          .toList(),
    });
  }

  Future<AiExampleStyle> getAiExampleStyle() async {
    final result = await _request<Map<String, dynamic>>('getAiExampleStyle');
    return AiExampleStyle.fromJson(result);
  }

  Future<AiExampleStyle> saveAiExampleStyle(AiExampleStyle style) async {
    final result = await _request<Map<String, dynamic>>(
      'saveAiExampleStyle',
      data: {'style': style.toApiJson()},
    );
    return AiExampleStyle.fromJson(result);
  }

  Future<Map<String, String>> generateWordExample(int wordId) async {
    final result = await _request<Map<String, dynamic>>(
      'generateWordExample',
      data: {'wordId': wordId},
      timeout: const Duration(seconds: 45),
    );
    return {
      'sentence': (result['sentence'] ?? '').toString(),
      'translation': (result['translation'] ?? '').toString(),
      'target': (result['target'] ?? '').toString(),
    };
  }

  Future<void> updateWordExample(
    int wordId, {
    required String sentence,
    required String translation,
    String target = '',
  }) async {
    await _request<void>(
      'updateWordExample',
      data: {
        'wordId': wordId,
        'sentence': sentence,
        'translation': translation,
        'target': target,
      },
      timeout: const Duration(seconds: 20),
    );
  }

  Future<void> bulkDeleteWords(List<int> wordIds) async {
    await _request<void>(
      'bulkDeleteWords',
      data: {'wordIds': wordIds},
    );
  }

  Future<List<Map<String, dynamic>>> getVocabularyWords(int listId) async {
    final rows = await _request<List<dynamic>>('getVocabularyWords', data: {'listId': listId});
    return rows.map((row) => _mapDates(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<List<Map<String, dynamic>>> getWordsByCategory(int userId, String category) async {
    final rows = await _request<List<dynamic>>('getWordsByCategory', data: {'userId': userId, 'category': category});
    return rows.map((row) => _mapDates(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<List<Map<String, dynamic>>> getRecentWords(int userId, {int limit = 20, String mode = 'all'}) async {
    final rows = await _request<List<dynamic>>('getRecentWords', data: {'userId': userId, 'limit': limit, 'mode': mode});
    return rows.map((row) => _mapDates(Map<String, dynamic>.from(row as Map))).toList();
  }

  /// Từ "Nên biết" đã đến hạn ôn nhẹ (4 đáp án, không bắt gõ).
  Future<List<Map<String, dynamic>>> getPassiveDueWords(int userId, {int limit = 20}) async {
    final rows = await _request<List<dynamic>>('getPassiveDueWords', data: {'userId': userId, 'limit': limit});
    return rows.map((row) => _mapDates(Map<String, dynamic>.from(row as Map))).toList();
  }

  /// Đổi loại 1 từ (Học ngay <-> Nên biết). Server reset lịch ôn theo loại.
  Future<void> setWordLearningMode(int wordId, String mode) async {
    await _request<void>('setWordLearningMode', data: {'wordId': wordId, 'mode': mode});
  }

  /// Áp dụng kết quả phân loại lại: mỗi item là {'id': int, 'mode': 'active'|'passive'}.
  Future<int> bulkSetLearningMode(List<Map<String, dynamic>> items) async {
    final result = await _request<Map<String, dynamic>>('bulkSetLearningMode', data: {'items': items});
    return _asInt(result['updatedCount']);
  }

  /// Danh sách từ để mở màn "Phân loại lại từ vựng".
  Future<List<Map<String, dynamic>>> getMigrationCandidates(int userId) async {
    final rows = await _request<List<dynamic>>('getMigrationCandidates', data: {'userId': userId});
    return rows.map((row) => _mapDates(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<List<Map<String, dynamic>>> getWordsMissingPronunciation(int userId) async {
    final rows = await _request<List<dynamic>>('getWordsMissingPronunciation', data: {'userId': userId});
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getUntaggedWords(int userId) async {
    final rows = await _request<List<dynamic>>('getUntaggedWords', data: {'userId': userId});
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> updateWordPronunciation({required int wordId, required String pronunciation}) async {
    await _request<void>('updateWordPronunciation',
        data: {'wordId': wordId, 'pronunciation': pronunciation});
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

  Future<Map<String, String>?> updateVocabularyWordDetails({
    required int wordId,
    required String meaning,
    String? pronunciation,
    String? fullDetails,
    String? wordType,
    String? topicTag,
    String? commonSynonyms,
    bool regenerateExample = false,
  }) async {
    final result = await _request<dynamic>('updateVocabularyWordDetails', data: {
      'wordId': wordId,
      'meaning': meaning,
      'pronunciation': pronunciation ?? '',
      'fullDetails': fullDetails ?? '',
      'wordType': wordType ?? '',
      'topicTag': topicTag ?? '',
      'commonSynonyms': commonSynonyms ?? '',
      'refreshExample': regenerateExample,
    });
    return _parseExample(result);
  }

  Future<Map<String, String>?> updateVocabularyWord({
    required int wordId,
    required String word,
    required String meaning,
    String? pronunciation,
    String? fullDetails,
    String? wordType,
    String? topicTag,
    String? commonSynonyms,
  }) async {
    final result = await _request<dynamic>('updateVocabularyWord', data: {
      'wordId': wordId,
      'word': word,
      'meaning': meaning,
      'pronunciation': pronunciation ?? '',
      'fullDetails': fullDetails ?? '',
      'wordType': wordType ?? '',
      'topicTag': topicTag ?? '',
      'commonSynonyms': commonSynonyms ?? '',
    });
    return _parseExample(result);
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

  Future<List<Map<String, dynamic>>> getWordsDueForReviewGrammar(int userId) async {
    final rows = await _request<List<dynamic>>('getWordsDueForReviewGrammar', data: {'userId': userId});
    return rows.map((row) => _mapDates(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<List<Map<String, dynamic>>> getWordsDueForReviewByCategory(int userId, String category) async {
    final rows = await _request<List<dynamic>>('getWordsDueForReviewByCategory', data: {'userId': userId, 'category': category});
    return rows.map((row) => _mapDates(Map<String, dynamic>.from(row as Map))).toList();
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
  /// Tim tren toan bo tu da luu (word / meaning / topic_tag), tra ve day du
  /// field nhu getRecentWords de hien thi + sua ngay tai cho.
  Future<List<Map<String, dynamic>>> searchWord(int userId, String query) async {
    final rows = await _request<List<dynamic>>(
      'searchWord',
      data: {'userId': userId, 'query': query},
      timeout: const Duration(seconds: 30),
    );
    return rows.map((row) => _mapDates(Map<String, dynamic>.from(row as Map))).toList();
  }

  /// Danh sach tu nhe (id/word/meaning/type/tag/list) de loc ngay tai may.
  /// Cache trong bo nho, tu xoa khi co thao tac sua du lieu tu.
  Future<List<Map<String, dynamic>>> wordIndex(int userId, {bool force = false}) async {
    final cached = _wordIndexCache[userId];
    if (cached != null && !force) return cached;
    final rows = await _request<List<dynamic>>('getWordIndex', data: {'userId': userId});
    final words = rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
    _wordIndexCache[userId] = words;
    return words;
  }

  Future<Map<String, dynamic>?> getWordDetails(int wordId) async {
    final value = await _request<dynamic>('getWordDetails', data: {'wordId': wordId});
    if (value == null) return null;
    return Map<String, dynamic>.from(value as Map);
  }

  Future<void> close() async {
    _isInitialized = false;
  }
}
