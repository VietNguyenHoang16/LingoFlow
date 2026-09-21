import 'package:flutter/foundation.dart';

import 'dictionary_service.dart';
import 'word_type_classifier.dart';

/// Du lieu phu cua mot tu lay tu tu dien: phat am IPA, chi tiet (definition +
/// example) va loai tu. Dung khi sua Tu trong man On tap.
class WordEnrichment {
  final String pronunciation;
  final String fullDetails;
  final String wordType;

  const WordEnrichment({
    required this.pronunciation,
    required this.fullDetails,
    required this.wordType,
  });

  bool get isEmpty =>
      pronunciation.isEmpty && fullDetails.isEmpty && wordType.isEmpty;
}

/// Lay du lieu phu tu dictionaryapi.dev qua [DictionaryService] co san.
/// Khong bao gio throw: loi mang / tu khong co trong tu dien -> tra ve null.
class WordEnrichmentService {
  static final WordEnrichmentService _instance =
      WordEnrichmentService._internal();
  factory WordEnrichmentService() => _instance;
  WordEnrichmentService._internal();

  final DictionaryService _dict = DictionaryService();

  /// Gioi han 3 definition moi loai tu - dong bo voi DictionaryService.
  static const int _maxDefinitionsPerType = 3;

  /// Tra ve null khi khong tim thay tu hoac khong lay duoc du lieu nao.
  Future<WordEnrichment?> fetch(
    String word, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return null;
    final info = await _dict.getWordInfo(trimmed, timeout: timeout);
    if (info == null) return null;
    final enrichment = WordEnrichment(
      pronunciation: DictionaryService.stripSlashes(
        ((info['pronunciation'] as String?) ?? '').trim(),
      ),
      fullDetails: buildFullDetails(info['types']),
      wordType: buildWordTypes(info['types']),
    );
    return enrichment.isEmpty ? null : enrichment;
  }

  /// Build `full_details` theo format DB ma `parseFullDetails` doc duoc:
  /// `noun: [{definition: ..., example: ...}, ...]`, moi loai tu 1 dong.
  @visibleForTesting
  static String buildFullDetails(dynamic types) {
    if (types is! List) return '';
    final lines = <String>[];
    for (final entry in types) {
      if (entry is! Map) continue;
      final rawPos = (entry['type'] ?? '').toString().trim().toLowerCase();
      // Map ve key loai tu cua app: POS la (vd 'exclamation') khong nam trong
      // kPosKeys se khong duoc parseFullDetails doc lai -> bo qua.
      final pos = WordTypeClassifier.kPosToWordType[rawPos];
      if (pos == null) continue;
      final definitions = entry['definitions'];
      if (definitions is! List) continue;
      final pairs = <String>[];
      for (final definition in definitions) {
        if (definition is! Map) continue;
        final text = _sanitize((definition['definition'] ?? '').toString());
        if (text.isEmpty) continue;
        final example = _sanitize((definition['example'] ?? '').toString());
        pairs.add('{definition: $text, example: $example}');
        if (pairs.length == _maxDefinitionsPerType) break;
      }
      if (pairs.isEmpty) continue;
      lines.add('$pos: [${pairs.join(', ')}]');
    }
    return lines.join('\n');
  }

  /// Map part-of-speech -> key loai tu cua app, dang 'noun,verb'.
  @visibleForTesting
  static String buildWordTypes(dynamic types) {
    if (types is! List) return '';
    final keys = <String>{};
    for (final entry in types) {
      if (entry is! Map) continue;
      final pos = (entry['type'] ?? '').toString().trim().toLowerCase();
      final key = WordTypeClassifier.kPosToWordType[pos];
      if (key != null) keys.add(key);
    }
    return keys.join(',');
  }

  /// Bo ky tu pha format `{definition: ..., example: ...}` / `pos: [...]`
  /// va gop khoang trang de chuoi luon parse duoc.
  static String _sanitize(String raw) => raw
      .replaceAll('{', '(')
      .replaceAll('}', ')')
      .replaceAll('[', '(')
      .replaceAll(']', ')')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
