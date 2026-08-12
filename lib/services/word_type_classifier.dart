import 'package:flutter/foundation.dart';
import 'database_service_web.dart';
import 'dictionary_service.dart';

class WordTypeClassifier {
  static final WordTypeClassifier _instance = WordTypeClassifier._internal();
  factory WordTypeClassifier() => _instance;
  WordTypeClassifier._internal();

  final DatabaseService _db = DatabaseService();
  final DictionaryService _dict = DictionaryService();

  static const Map<String, String> _posToKey = {
    'noun': 'noun',
    'verb': 'verb',
    'adjective': 'adjective',
    'adverb': 'adverb',
    'preposition': 'preposition',
    'conjunction': 'conjunction',
    'pronoun': 'pronoun',
    'interjection': 'interjection',
    'exclamation': 'interjection',
  };

  /// Classifies all words with empty `word_type` for the given user.
  /// Skips silently on any per-word failure (network, parse, missing data).
  /// Returns the number of words successfully classified.
  Future<int> classifyAllUntagged({
    required int userId,
    void Function(int done, int total)? onProgress,
  }) async {
    final lists = await _db.getAllLists(userId);
    if (lists.isEmpty) return 0;

    final untagged = <Map<String, dynamic>>[];
    for (final list in lists) {
      final listId = list['id'] as int;
      final words = await _db.getVocabularyWords(listId);
      for (final w in words) {
        final wt = (w['word_type'] as String? ?? '').trim();
        if (wt.isEmpty) {
          untagged.add(w);
        }
      }
    }
    if (untagged.isEmpty) return 0;

    int classified = 0;
    for (int i = 0; i < untagged.length; i++) {
      final w = untagged[i];
      final word = (w['word'] as String? ?? '').trim();
      if (word.isEmpty) {
        onProgress?.call(i + 1, untagged.length);
        continue;
      }
      try {
        final info = await _dict.getWordInfo(word);
        if (info == null) {
          onProgress?.call(i + 1, untagged.length);
          continue;
        }
        final types = (info['types'] as List?) ?? [];
        final keys = <String>{};
        for (final t in types) {
          final pos = (t as Map)['type']?.toString().toLowerCase().trim();
          if (pos == null) continue;
          final key = _posToKey[pos];
          if (key != null) keys.add(key);
        }
        if (keys.isEmpty) {
          onProgress?.call(i + 1, untagged.length);
          continue;
        }
        final joined = keys.toList().join(',');
        await _db.updateVocabularyWordDetails(
          wordId: w['id'] as int,
          meaning: (w['meaning'] as String? ?? ''),
          pronunciation: w['pronunciation'] as String?,
          fullDetails: w['full_details'] as String?,
          wordType: joined,
        );
        classified++;
        if (kDebugMode) {
          debugPrint('Classified "$word" -> $joined');
        }
      } catch (_) {
        // Skip silently per spec; do not retry, do not flag.
      }
      onProgress?.call(i + 1, untagged.length);
      // Small delay to respect rate limits on the public dictionary API.
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return classified;
  }
}
