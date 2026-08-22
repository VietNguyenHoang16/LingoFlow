import 'package:flutter/foundation.dart';

import 'database_service.dart';
import 'dictionary_service.dart';

class BackfillResult {
  final int updated;
  final int notFound;
  const BackfillResult({required this.updated, required this.notFound});
}

class PronunciationService {
  static final PronunciationService _instance =
      PronunciationService._internal();
  factory PronunciationService() => _instance;
  PronunciationService._internal();

  final DictionaryService _dict = DictionaryService();
  final DatabaseService _db = DatabaseService();

  Future<void> _pause(int ms) => Future.delayed(Duration(milliseconds: ms));

  Future<String> _fetchWithRetry(String word) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final ipa = await _dict.fetchPronunciation(word);
        if (ipa.isNotEmpty) return ipa;
      } catch (e) {
        debugPrint('PronunciationService: "$word" fetch -> $e');
      }
      if (attempt < 2) await _pause(1000 * (attempt + 1));
    }
    return '';
  }

  Future<bool> _updateWithRetry({required int wordId, required String pronunciation}) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        await _db.updateWordPronunciation(wordId: wordId, pronunciation: pronunciation);
        return true;
      } catch (e) {
        debugPrint('PronunciationService: word $wordId update -> $e');
        if (attempt < 2) await _pause(1000 * (attempt + 1));
      }
    }
    return false;
  }

  Future<BackfillResult> backfillUser(
    int userId, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final words = await _db.getWordsMissingPronunciation(userId);
    int updated = 0;
    int notFound = 0;
    for (int i = 0; i < words.length; i++) {
      if (isCancelled?.call() ?? false) break;
      final w = words[i];
      final ipa = await _fetchWithRetry(w['word'].toString());
      if (ipa.isNotEmpty &&
          await _updateWithRetry(
              wordId: w['id'] as int, pronunciation: ipa)) {
        updated++;
      } else {
        notFound++;
      }
      onProgress?.call(i + 1, words.length);
      await _pause(200);
    }
    return BackfillResult(updated: updated, notFound: notFound);
  }
}
