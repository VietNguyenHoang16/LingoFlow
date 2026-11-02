import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lingoflow/services/display_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => DisplaySettingsService.instance.resetForTest());

  test('man hinh rong (iPad/web) mac dinh chu to hon dien thoai', () {
    expect(DisplaySettingsService.defaultScaleForWidth(390), 1.0);
    expect(DisplaySettingsService.defaultScaleForWidth(600), 1.0);
    expect(
      DisplaySettingsService.defaultScaleForWidth(810),
      DisplaySettingsService.wideScreenDefaultScale,
    );
  });

  test('chua chon gi thi lay mac dinh theo be ngang', () async {
    SharedPreferences.setMockInitialValues({});
    final service = DisplaySettingsService.instance;
    await service.load(screenWidth: 810);
    expect(
        service.textScale.value, DisplaySettingsService.wideScreenDefaultScale);
  });

  test('lua chon duoc luu lai cho lan mo sau', () async {
    SharedPreferences.setMockInitialValues({'display_text_scale': 1.15});
    final service = DisplaySettingsService.instance;
    await service.load(screenWidth: 810);
    expect(service.textScale.value, 1.15);

    await service.setScale(1.45);
    expect(service.textScale.value, 1.45);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('display_text_scale'), 1.45);
  });

  test('co chu la luon duoc dua ve mot moc co san', () async {
    SharedPreferences.setMockInitialValues({'display_text_scale': 1.22});
    final service = DisplaySettingsService.instance;
    await service.load(screenWidth: 400);
    expect(service.textScale.value, 1.15);
  });
}
