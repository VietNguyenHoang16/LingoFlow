class AiProviderConfig {
  static const int maxProviders = 3;

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
