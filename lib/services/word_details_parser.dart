const List<String> kPosKeys = [
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

Map<String, dynamic> _parseDefinitionPair(String pairStr) {
  final defMatch = RegExp(r'definition:\s*(.+?)(?=,\s*example:)').firstMatch(pairStr);
  final exMatch = RegExp(r'example:\s*(.+)').firstMatch(pairStr);
  return {
    'definition': defMatch != null ? defMatch.group(1)!.trim() : '',
    'example': exMatch != null ? exMatch.group(1)!.trim() : '',
  };
}

/// Parse [fullDetails] string into structured list.
/// Handles format: `noun: [{definition: ..., example: ...}, ...]`
/// Also handles Vietnamese text-only details (returns empty list).
List<Map<String, dynamic>> parseFullDetails(String raw) {
  if (raw.trim().isEmpty) return [];

  var content = raw.trim();
  if (content.startsWith('Chi tiết: ')) {
    content = content.substring('Chi tiết: '.length);
  }

  if (content.startsWith('[') == false && !kPosKeys.any((k) => content.contains('$k:'))) {
    return [];
  }

  final results = <Map<String, dynamic>>[];

  for (final pos in kPosKeys) {
    final posRegex = RegExp(
      '$pos:\\s*\\[\\s*(.*?)\\s*\\]',
      dotAll: true,
    );
    final match = posRegex.firstMatch(content);
    if (match == null) continue;

    final definitionsStr = match.group(1)!;
    final pairRegex = RegExp(r'\{[^}]+\}');
    final definitions = <Map<String, dynamic>>[];

    for (final pairMatch in pairRegex.allMatches(definitionsStr)) {
      final pair = pairMatch.group(0)!;
      final parsed = _parseDefinitionPair(pair);
      if (parsed['definition'] is String && parsed['definition'].toString().isNotEmpty) {
        definitions.add(parsed);
      }
    }

    if (definitions.isNotEmpty) {
      results.add({
        'pos': pos,
        'definitions': definitions,
      });
    }
  }

  return results;
}

/// Extract the first non-empty example from parsed details.
String extractFirstExample(List<Map<String, dynamic>> details) {
  for (final posEntry in details) {
    final definitions = posEntry['definitions'] as List? ?? [];
    for (final def in definitions) {
      final example = (def['example']?.toString() ?? '').trim();
      if (example.isNotEmpty) {
        return example;
      }
    }
  }
  return '';
}

/// Get the primary POS (first one found).
String? getPrimaryPos(List<Map<String, dynamic>> details) {
  if (details.isEmpty) return null;
  return details.first['pos'] as String?;
}/// Rebuild [fullDetails] string from parsed structured data.
/// Produces format: `noun: [{definition: ..., example: ...}, ...]`
String rebuildFullDetails(List<Map<String, dynamic>> details) {
  if (details.isEmpty) return '';

  final parts = <String>[];
  for (final entry in details) {
    final pos = entry['pos'] as String;
    final definitions = entry['definitions'] as List;
    final defStrings = definitions.map((def) {
      final definition = (def['definition'] as String?) ?? '';
      final example = (def['example'] as String?) ?? '';
      return '{definition: $definition, example: $example}';
    }).join(', ');
    parts.add('$pos: [$defStrings]');
  }

  return parts.join(', ');
}

/// Add [example] to the first definition without an example in [fullDetails].
/// Returns updated fullDetails string with the example embedded.
String addExampleToFullDetails(String fullDetails, String example) {
  final parsed = parseFullDetails(fullDetails);
  if (parsed.isEmpty) return fullDetails;

  for (final posEntry in parsed) {
    final definitions = posEntry['definitions'] as List<Map<String, dynamic>>;
    for (final def in definitions) {
      if ((def['example'] as String?)?.trim().isEmpty ?? false) {
        def['example'] = example;
        return rebuildFullDetails(parsed);
      }
    }
  }

  // If all definitions have examples, add to the first one
  final firstDefs = parsed.first['definitions'] as List<Map<String, dynamic>>;
  if (firstDefs.isNotEmpty) {
    firstDefs[0]['example'] = example;
    return rebuildFullDetails(parsed);
  }

  return fullDetails;
}