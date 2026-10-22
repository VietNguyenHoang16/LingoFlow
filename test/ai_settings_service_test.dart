import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lingoflow/services/ai_settings_service.dart';

const _a = AiProviderConfig(
  name: 'A',
  baseUrl: 'https://a.example/v1',
  apiKey: 'ka',
  model: 'm1',
);
const _b = AiProviderConfig(
  name: 'B',
  baseUrl: 'https://b.example/v1',
  apiKey: 'kb',
  model: 'm2',
);
const _c = AiProviderConfig(
  name: 'C',
  baseUrl: 'https://c.example/v1',
  apiKey: 'kc',
  model: 'm3',
);
const _d = AiProviderConfig(
  name: 'D',
  baseUrl: 'https://d.example/v1',
  apiKey: 'kd',
  model: 'm4',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('luu va doc lai dung thu tu uu tien', () async {
    final service = AiSettingsService();
    await service.save([_a, _b, _c]);

    final loaded = await service.load();
    expect(loaded.map((config) => config.model), ['m1', 'm2', 'm3']);
    expect(loaded.first.apiKey, 'ka');
    expect(loaded.first.name, 'A');
  });

  test('chi giu toi da 3 va bo cau hinh thieu', () async {
    final service = AiSettingsService();
    await service.save([
      _a,
      const AiProviderConfig(
        baseUrl: 'https://x.example/v1',
        apiKey: '',
        model: 'x',
      ),
      _b,
      _c,
      _d,
    ]);

    final loaded = await service.load();
    expect(loaded.length, 3);
    expect(loaded.map((config) => config.model), ['m1', 'm2', 'm3']);
  });

  test('json hong tra ve danh sach rong', () async {
    SharedPreferences.setMockInitialValues({
      AiSettingsService.storageKey: 'not-json',
    });
    expect(await AiSettingsService().load(), isEmpty);
  });

  test('luu danh sach rong thi xoa cau hinh', () async {
    final service = AiSettingsService();
    await service.save([_a]);
    await service.save(const []);

    expect(await service.load(), isEmpty);
  });

  test('apiPayload chi gom cau hinh hop le', () async {
    final service = AiSettingsService();
    await service.save([_a]);
    final payload = await service.apiPayload();

    expect(payload.length, 1);
    expect(payload.first['baseUrl'], 'https://a.example/v1');
    expect(payload.first['model'], 'm1');
  });
}
