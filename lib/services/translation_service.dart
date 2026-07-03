import 'package:http/http.dart' as http;
import 'dart:convert';

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  Future<String> translateText(String text) async {
    if (text.trim().isEmpty) return '';
    try {
      final response = await http.get(
        Uri.parse('https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(text)}&langpair=en|vi'),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['responseStatus'] == 200) {
          return data['responseData']['translatedText'] ?? text;
        }
      }
    } catch (_) {}
    return text;
  }

  Future<Map<String, String>> translateWords(List<String> words) async {
    Map<String, String> results = {};
    
    for (String word in words) {
      String trimmedWord = word.trim();
      if (trimmedWord.isEmpty) continue;
      
      try {
        final response = await http.get(
          Uri.parse('https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(trimmedWord)}&langpair=en|vi'),
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['responseStatus'] == 200) {
            results[trimmedWord.toLowerCase()] = data['responseData']['translatedText'] ?? trimmedWord;
          } else {
            results[trimmedWord.toLowerCase()] = trimmedWord;
          }
        } else {
          results[trimmedWord.toLowerCase()] = trimmedWord;
        }
      } catch (e) {
        results[trimmedWord.toLowerCase()] = trimmedWord;
      }
    }
    
    return results;
  }

  String getPronunciation(String word) {
    return word;
  }
}