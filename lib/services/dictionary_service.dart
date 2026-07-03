import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class DictionaryService {
  static final DictionaryService _instance = DictionaryService._internal();
  factory DictionaryService() => _instance;
  DictionaryService._internal();

  Future<Map<String, dynamic>?> getWordInfo(String word) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/$word'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          return _parseWordData(data[0]);
        }
      }
    } catch (e) {
      debugPrint('Dictionary API error: $e');
    }
    return null;
  }

  Map<String, dynamic>? _parseWordData(dynamic entry) {
    try {
      final phonetics = entry['phonetics'] as List?;
      String? pronunciation;
      String? audioUrl;
      
      if (phonetics != null) {
        for (var p in phonetics) {
          if (p['text'] != null && p['text'].toString().isNotEmpty) {
            pronunciation = p['text'];
          }
          if (p['audio'] != null && p['audio'].toString().isNotEmpty) {
            audioUrl = p['audio'];
          }
          if (pronunciation != null && audioUrl != null) break;
        }
      }

      final meanings = entry['meanings'] as List?;
      List<Map<String, dynamic>> types = [];
      
      if (meanings != null) {
        for (var m in meanings) {
          String? partOfSpeech = m['partOfSpeech'];
          if (partOfSpeech != null) {
            List<Map<String, String>> defsWithExamples = [];
            final defs = m['definitions'] as List?;
            if (defs != null && defs.isNotEmpty) {
              for (var d in defs.take(3)) {
                if (d['definition'] != null) {
                  String? example = d['example'];
                  defsWithExamples.add({
                    'definition': d['definition'],
                    'example': example ?? '',
                  });
                }
              }
            }
            if (defsWithExamples.isNotEmpty) {
              types.add({
                'type': partOfSpeech,
                'definitions': defsWithExamples,
              });
            }
          }
        }
      }

      return {
        'pronunciation': pronunciation,
        'audioUrl': audioUrl,
        'types': types,
      };
    } catch (e) {
      debugPrint('Parse error: $e');
      return null;
    }
  }
}