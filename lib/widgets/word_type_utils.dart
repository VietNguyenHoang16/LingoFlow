import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

const List<String> kWordTypeKeys = [
  'noun',
  'verb',
  'adjective',
  'adverb',
  'preposition',
  'conjunction',
];

const Map<String, String> kWordTypeLabel = {
  'noun': 'Nouns',
  'verb': 'Verbs',
  'adjective': 'Adjectives',
  'adverb': 'Adverbs',
  'preposition': 'Prepositions',
  'conjunction': 'Conjunctions',
};

const Map<String, String> kWordTypeShortLabel = {
  'noun': 'N',
  'verb': 'V',
  'adjective': 'Adj',
  'adverb': 'Adv',
  'preposition': 'Prep',
  'conjunction': 'Conj',
};

const Map<String, IconData> kWordTypeIcons = {
  'noun': Icons.bookmark_rounded,
  'verb': Icons.directions_run_rounded,
  'adjective': Icons.brush_rounded,
  'adverb': Icons.bolt_rounded,
  'preposition': Icons.link_rounded,
  'conjunction': Icons.join_right_rounded,
};

const Map<String, List<String>> kWordTypeAbbreviations = {
  'noun': ['n', 'noun'],
  'verb': ['v', 'verb'],
  'adjective': ['adj', 'adj.', 'a', 'adjective'],
  'adverb': ['adv', 'adv.', 'adverb'],
  'preposition': ['prep', 'preposition'],
  'conjunction': ['conj', 'con', 'conjunction'],
};

/// Số POS (1-based) -> word_type key, theo dung thu tu kWordTypeKeys.
/// 1=noun, 2=verb, 3=adjective, 4=adverb, 5=preposition, 6=conjunction.
const Map<int, String> kPosNumberToKey = {
  1: 'noun',
  2: 'verb',
  3: 'adjective',
  4: 'adverb',
  5: 'preposition',
  6: 'conjunction',
};

/// Parse số POS từ string. Trả về word_type key nếu hợp lệ, null nếu không.
String? parsePosNumber(String raw) {
  final n = int.tryParse(raw.trim());
  if (n == null) return null;
  return kPosNumberToKey[n];
}

String normalizeWordTypeAbbrev(String raw) {
  final lower = raw.toLowerCase().replaceAll(RegExp(r'[\s\.]+'), ' ').trim();
  final compact = lower.replaceAll(' ', '');
  for (final entry in kWordTypeAbbreviations.entries) {
    for (final abbr in entry.value) {
      final compactAbbr = abbr.replaceAll(' ', '');
      if (compactAbbr == compact) return entry.key;
    }
  }
  return '';
}

Map<String, dynamic> wordTypeConfig(String key, BuildContext context) {
  final safeKey = kWordTypeLabel.containsKey(key) ? key : '';
  final colors = context.lingoColors.wordTypeColors;
  return {
    'key': safeKey,
    'label': kWordTypeLabel[safeKey] ?? key,
    'shortLabel': kWordTypeShortLabel[safeKey] ?? key,
    'icon': kWordTypeIcons[safeKey] ?? Icons.help_outline_rounded,
    'color': colors[safeKey] ?? context.lingoColors.masteryNew,
  };
}
