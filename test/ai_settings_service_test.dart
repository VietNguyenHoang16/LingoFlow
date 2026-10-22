import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/services/ai_settings_service.dart';

void main() {
  test('serialize va doc lai cau hinh', () {
    const config = AiProviderConfig(
      name: 'Xkiro',
      baseUrl: 'https://api.xkiro.com/v1',
      apiKey: 'sk-test',
      model: 'openai/gpt-5.6-sol',
    );

    final json = config.toApiJson();
    expect(json['name'], 'Xkiro');
    expect(json['baseUrl'], 'https://api.xkiro.com/v1');
    expect(json['apiKey'], 'sk-test');
    expect(json['model'], 'openai/gpt-5.6-sol');

    final restored = AiProviderConfig.fromJson(json);
    expect(restored.baseUrl, config.baseUrl);
    expect(restored.apiKey, config.apiKey);
    expect(restored.model, config.model);
  });

  test('cau hinh thieu truong bat buoc la khong hop le', () {
    const config = AiProviderConfig(
      baseUrl: 'https://api.xkiro.com/v1',
      apiKey: '',
      model: 'openai/gpt-5.6-sol',
    );

    expect(config.isComplete, isFalse);
  });

  test('toi da 3 API', () {
    expect(AiProviderConfig.maxProviders, 3);
  });
}
