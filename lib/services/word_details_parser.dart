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
  // Extract definition
  final defMatch = RegExp(r'definition:\s*(.+?)(?=,\s*(?:example|examples):|$)').firstMatch(pairStr);
  final definition = defMatch != null ? defMatch.group(1)!.trim() : '';

  // Extract single example (not followed by 's:')
  final exMatch = RegExp(r'example:\s*(.+?)(?=",\s*examples:|,?\s*\})').firstMatch(pairStr);
  final singleExample = exMatch != null ? exMatch.group(1)!.trim() : '';

  // Extract examples list
  final exsMatch = RegExp(r'examples:\s*\[([^\]]*)\]').firstMatch(pairStr);
  final List<dynamic> examplesList = [];
  if (exsMatch != null) {
    final examplesStr = exsMatch.group(1)!;
    // Split by comma and parse each example
    final exampleItems = examplesStr.split(',');
    for (final item in exampleItems) {
      final ex = item.trim();
      // Remove quotes if present
      final cleanEx = ex.replaceAll(RegExp(r"""^["\']|["\']$"""), '').trim();
      if (cleanEx.isNotEmpty) {
        examplesList.add(cleanEx);
      }
    }
  }

  return {
    'definition': definition,
    'example': singleExample,
    'examples': examplesList,
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
/// Supports both single 'example' string and 'examples' list format.
String rebuildFullDetails(List<Map<String, dynamic>> details) {
  if (details.isEmpty) return '';

  final parts = <String>[];
  for (final entry in details) {
    final pos = entry['pos'] as String;
    final definitions = entry['definitions'] as List;
    final defStrings = definitions.map((def) {
      final definition = (def['definition'] as String?) ?? '';
      // Check for single example string
      final example = (def['example'] as String?) ?? '';
      // Check for examples list
      final examples = def['examples'] as List? ?? [];
      
      String result = '{definition: $definition';
      if (example.trim().isNotEmpty) {
        result += ', example: $example';
      }
      // Add examples list if present
      if (examples.isNotEmpty) {
        final examplesStr = examples.map((e) => e.toString()).join(', ');
        result += ', examples: [$examplesStr]';
      }
      result += '}';
      return result;
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

/// Extract all examples from parsed details into a flat list.
/// Supports both single 'example' string and 'examples' list format.
List<String> extractAllExamples(String fullDetails) {
  final parsed = parseFullDetails(fullDetails);
  final examples = <String>[];
  for (final posEntry in parsed) {
    final definitions = posEntry['definitions'] as List? ?? [];
    for (final def in definitions) {
      // Check for single example string
      final ex = def['example'] as String?;
      if (ex != null && ex.trim().isNotEmpty) {
        examples.add(ex);
      }
      // Check for examples list
      final exs = def['examples'] as List?;
      if (exs != null) {
        for (final e in exs) {
          if (e is String && e.trim().isNotEmpty) {
            examples.add(e);
          }
        }
      }
    }
  }
  return examples;
}

/// Remove an example at [index] from [fullDetails].
/// Returns updated fullDetails string.
String removeExample(String fullDetails, int index) {
  final allExamples = extractAllExamples(fullDetails);
  if (index < 0 || index >= allExamples.length) return fullDetails;
  allExamples.removeAt(index);

  // Rebuild fullDetails without the removed example.
  // Since examples can be in different definitions, we reconstruct by
  // building a new structure with all remaining examples in the first definition
  final parsed = parseFullDetails(fullDetails);
  if (parsed.isEmpty) return fullDetails;

  // Clear all examples first, then re-add them all to the first definition
  final firstDefs = parsed.first['definitions'] as List<Map<String, dynamic>>;
  if (firstDefs.isNotEmpty) {
    // Clear examples in all definitions
    for (final posEntry in parsed) {
      final defs = posEntry['definitions'] as List;
      for (final def in defs) {
        def['example'] = '';
        def['examples'] = [];
      }
    }

    // Add all remaining examples back to the first definition
    final remainingExamples = allExamples;
    firstDefs[0]['examples'] = remainingExamples;
  }

  return rebuildFullDetails(parsed);
}

/// Update an example at [index] in [fullDetails] with [newExample].
/// Returns updated fullDetails string.
String updateExample(String fullDetails, int index, String newExample) {
  final allExamples = extractAllExamples(fullDetails);
  if (index < 0 || index >= allExamples.length) return fullDetails;
  allExamples[index] = newExample;

  final parsed = parseFullDetails(fullDetails);
  if (parsed.isEmpty) return fullDetails;

  // Clear all examples
  for (final posEntry in parsed) {
    final defs = posEntry['definitions'] as List;
    for (final def in defs) {
      def['example'] = '';
      def['examples'] = [];
    }
  }

  // Re-add all examples to the first definition
  final firstDefs = parsed.first['definitions'] as List<Map<String, dynamic>>;
  if (firstDefs.isNotEmpty) {
    firstDefs[0]['examples'] = allExamples;
  }

  return rebuildFullDetails(parsed);
}