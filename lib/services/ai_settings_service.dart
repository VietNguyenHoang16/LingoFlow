import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AiProviderConfig {
  final String name;
  final String baseUrl;
  final String apiKey;
  final String model;

  const AiProviderConfig({
    this.name = '',
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  bool get isComplete =>
      baseUrl.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty &&
      model.trim().isNotEmpty;

  Map<String, dynamic> toApiJson() => {
    'name': name.trim(),
    'baseUrl': baseUrl.trim(),
    'apiKey': apiKey.trim(),
    'model': model.trim(),
  };

  factory AiProviderConfig.fromJson(Map<String, dynamic> json) {
    return AiProviderConfig(
      name: (json['name'] ?? '').toString(),
      baseUrl: (json['baseUrl'] ?? '').toString(),
      apiKey: (json['apiKey'] ?? '').toString(),
      model: (json['model'] ?? '').toString(),
    );
  }
}

class AiSettingsService {
  static const String storageKey = 'ai_provider_configs';
  static const int maxProviders = 3;

  Future<List<AiProviderConfig>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map(
            (row) => AiProviderConfig.fromJson(Map<String, dynamic>.from(row)),
          )
          .where((config) => config.isComplete)
          .take(maxProviders)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<AiProviderConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = configs
        .where((config) => config.isComplete)
        .take(maxProviders)
        .toList();
    if (cleaned.isEmpty) {
      await prefs.remove(storageKey);
      return;
    }
    await prefs.setString(
      storageKey,
      jsonEncode(cleaned.map((config) => config.toApiJson()).toList()),
    );
  }

  Future<List<Map<String, dynamic>>> apiPayload() async {
    final configs = await load();
    return configs.map((config) => config.toApiJson()).toList();
  }
}
