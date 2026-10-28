/// Mot boi canh goi y cho cau vi du. `id` phai trung voi EXAMPLE_CONTEXTS
/// trong api/_lib/xai.js.
class AiExampleContext {
  final String id;
  final String label;

  /// Cum tieng Anh server chen vao prompt (phai khop EXAMPLE_CONTEXTS).
  final String english;

  const AiExampleContext(this.id, this.label, this.english);
}

const List<AiExampleContext> kAiExampleContexts = [
  AiExampleContext('daily', 'Đời sống hằng ngày', 'everyday life'),
  AiExampleContext('work', 'Công việc / văn phòng', 'work and the office'),
  AiExampleContext('it', 'IT & công nghệ', 'IT and technology'),
  AiExampleContext('study', 'Học tập / thi cử', 'study and exams'),
  AiExampleContext('travel', 'Du lịch', 'travel'),
  AiExampleContext('business', 'Kinh doanh', 'business'),
  AiExampleContext('health', 'Sức khoẻ', 'health and daily wellbeing'),
  AiExampleContext('media', 'Phim ảnh / giải trí', 'films, series and entertainment'),
];

AiExampleContext? aiExampleContextById(String id) {
  for (final context in kAiExampleContexts) {
    if (context.id == id) return context;
  }
  return null;
}

String _knownContext(String id) {
  final lower = id.trim().toLowerCase();
  for (final context in kAiExampleContexts) {
    if (context.id == lower) return context.id;
  }
  return '';
}

/// Cai dat "cach AI sinh vi du" cua mot tai khoan (luu o server).
class AiExampleStyle {
  static const int maxCustomLength = 300;
  static const List<String> defaultContextIds = ['daily', 'work', 'it'];

  static const AiExampleStyle defaults = AiExampleStyle(
    contexts: defaultContextIds,
  );

  /// Id boi canh da chon (co the rong = de AI tu chon).
  final List<String> contexts;

  /// Bo qua nghia hiem / nghia den it dung, lay nghia pho bien nhat.
  final bool skipRareSenses;

  /// Yeu cau rieng cua nguoi dung, ghep vao prompt.
  final String custom;

  const AiExampleStyle({
    required this.contexts,
    this.skipRareSenses = true,
    this.custom = '',
  });

  /// Gop khoang trang + cat 300 ky tu, giong server de UI va prompt luon khop.
  static String normalizeCustom(String raw) {
    final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.length > maxCustomLength
        ? collapsed.substring(0, maxCustomLength)
        : collapsed;
  }

  List<String> get contextLabels => [
    for (final context in kAiExampleContexts)
      if (contexts.contains(context.id)) context.label,
  ];

  bool get isDefault =>
      _sameIds(contexts, defaultContextIds) && skipRareSenses && custom.isEmpty;

  Map<String, dynamic> toApiJson() => {
    'contexts': [...contexts],
    'skipRareSenses': skipRareSenses,
    'custom': custom,
  };

  /// Doc lai du lieu tu server; du lieu hong -> quay ve mac dinh.
  factory AiExampleStyle.fromJson(Map<String, dynamic> json) {
    final rawContexts = json['contexts'];
    final contexts = <String>[];
    if (rawContexts is List) {
      for (final raw in rawContexts) {
        final id = _knownContext(raw?.toString() ?? '');
        if (id.isNotEmpty && !contexts.contains(id)) contexts.add(id);
      }
    } else {
      contexts.addAll(defaultContextIds);
    }
    final rawSkip = json['skipRareSenses'];
    return AiExampleStyle(
      contexts: contexts,
      skipRareSenses: rawSkip is bool ? rawSkip : true,
      custom: normalizeCustom((json['custom'] ?? '').toString()),
    );
  }

  AiExampleStyle copyWith({
    List<String>? contexts,
    bool? skipRareSenses,
    String? custom,
  }) {
    return AiExampleStyle(
      contexts: contexts ?? this.contexts,
      skipRareSenses: skipRareSenses ?? this.skipRareSenses,
      custom: custom ?? this.custom,
    );
  }

  /// Dòng tom tat hien tren the Cai dat.
  String get summary {
    final parts = <String>[];
    final labels = contextLabels;
    parts.add(labels.isEmpty ? 'AI tự chọn bối cảnh' : labels.join(', '));
    parts.add(skipRareSenses ? 'bỏ nghĩa hiếm' : 'mọi nghĩa');
    if (custom.isNotEmpty) parts.add('có yêu cầu riêng');
    return parts.join(' · ');
  }

  static bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (final id in a) {
      if (!b.contains(id)) return false;
    }
    return true;
  }
}

/// Xem truoc khoi "Learner preferences" se gui AI.
///
/// Phai giu khop voi buildStylePrompt() o api/_lib/xai.js de nguoi dung thay
/// dung chi dan that su duoc dung.
String buildAiExampleStylePreview(AiExampleStyle style) {
  final lines = <String>[];
  if (style.skipRareSenses) {
    lines.add(
      '- Teach the sense a Vietnamese learner actually needs, not the rarest or most literal one: '
      'for "concrete" use "cụ thể, rõ ràng" (not the building material), '
      'for "harness" use "tận dụng, khai thác" (not horse tack).',
    );
  }
  if (style.contexts.isNotEmpty) {
    final english = [
      for (final context in kAiExampleContexts)
        if (style.contexts.contains(context.id)) context.english,
    ];
    lines.add('- When it fits naturally, set the scene in: ${english.join(', ')}.');
  }
  if (style.custom.isNotEmpty) {
    lines.add('- Extra notes from the learner: ${style.custom}');
  }
  if (lines.isEmpty) return 'Không có chỉ dẫn thêm — AI dùng prompt gốc.';
  return 'Learner preferences:\n${lines.join('\n')}';
}

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
