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
      try {
        final ipa = await _dict.fetchPronunciation(w['word'].toString());
        if (ipa.isNotEmpty) {
          await _db.updateWordPronunciation(
              wordId: w['id'] as int, pronunciation: ipa);
          updated++;
        } else {
          notFound++;
        }
      } catch (e) {
        debugPrint('PronunciationService: "${w['word']}" -> $e');
        notFound++;
      }
      onProgress?.call(i + 1, words.length);
    }
    return BackfillResult(updated: updated, notFound: notFound);
  }
}
