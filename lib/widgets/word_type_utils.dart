import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

const List<String> kWordTypeKeys = [
  'noun',
  'verb',
  'adjective',
  'adverb',
  'preposition',
  'conjunction',
  'pronoun',
  'interjection',
  'phrasal_verb',
  'idiom',
  'collocation',
  'grammar',
];

const Map<String, String> kWordTypeLabel = {
  'noun': 'Nouns',
  'verb': 'Verbs',
  'adjective': 'Adjectives',
  'adverb': 'Adverbs',
  'preposition': 'Prepositions',
  'conjunction': 'Conjunctions',
  'pronoun': 'Pronouns',
  'interjection': 'Interjections',
  'phrasal_verb': 'Phrasal Verbs',
  'idiom': 'Idioms',
  'collocation': 'Collocations',
  'grammar': 'Grammar',
};

const Map<String, String> kWordTypeShortLabel = {
  'noun': 'N',
  'verb': 'V',
  'adjective': 'Adj',
  'adverb': 'Adv',
  'preposition': 'Prep',
  'conjunction': 'Conj',
  'pronoun': 'Pron',
  'interjection': 'Interj',
  'phrasal_verb': 'PhrV',
  'idiom': 'Idiom',
  'collocation': 'Coll',
  'grammar': 'Gram',
};

const Map<String, IconData> kWordTypeIcons = {
  'noun': Icons.bookmark_rounded,
  'verb': Icons.directions_run_rounded,
  'adjective': Icons.brush_rounded,
  'adverb': Icons.bolt_rounded,
  'preposition': Icons.link_rounded,
  'conjunction': Icons.join_right_rounded,
  'pronoun': Icons.person_rounded,
  'interjection': Icons.campaign_rounded,
  'phrasal_verb': Icons.alt_route_rounded,
  'idiom': Icons.format_quote_rounded,
  'collocation': Icons.style_rounded,
  'grammar': Icons.schema_rounded,
};

const Map<String, List<String>> kWordTypeAbbreviations = {
  'noun': ['n', 'noun'],
  'verb': ['v', 'verb'],
  'adjective': ['adj', 'adj.', 'a', 'adjective'],
  'adverb': ['adv', 'adv.', 'adverb'],
  'preposition': ['prep', 'preposition'],
  'conjunction': ['conj', 'con', 'conjunction'],
  'pronoun': ['pron', 'pronoun'],
  'interjection': ['interj', 'int', 'interjection', 'exclamation'],
  'phrasal_verb': ['phrv', 'phrasal', 'phrasal_verb', 'phrasal verb'],
  'idiom': ['idiom'],
  'collocation': ['coll', 'collocation'],
  'grammar': ['gram', 'grammar', 'struct', 'structure', 'pattern'],
};

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
