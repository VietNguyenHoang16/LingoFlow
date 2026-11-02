import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mot moc co chu nguoi dung chon duoc trong Settings > Co chu.
class TextSizeOption {
  final double scale;
  final String label;

  const TextSizeOption(this.scale, this.label);
}

/// Co chu toan app (chinh trong Settings > Co chu).
///
/// Tren iPad / web man hinh rong, cung mot co chu (logical px) nhung mat doc
/// xa hon nhieu so voi dien thoai -> chu mac dinh phai lon hon, neu khong se
/// rat kho doc. Nguoi dung chinh duoc va lua chon duoc luu lai, nen chi can
/// chon mot lan.
class DisplaySettingsService {
  DisplaySettingsService._();

  static final DisplaySettingsService instance = DisplaySettingsService._();

  static const String _textScaleKey = 'display_text_scale';

  /// Be ngang tu muc nay tro len duoc coi la man hinh rong (iPad / web).
  static const double wideScreenBreakpoint = 600;

  /// He so mac dinh cho man hinh rong khi nguoi dung chua tu chon.
  static const double wideScreenDefaultScale = 1.3;

  static const List<TextSizeOption> options = <TextSizeOption>[
    TextSizeOption(1.0, 'Chuẩn'),
    TextSizeOption(1.15, 'Lớn'),
    TextSizeOption(1.3, 'Rất lớn'),
    TextSizeOption(1.45, 'Tối đa'),
  ];

  static double scaleForOption(TextSizeOption option) => option.scale;

  /// Mac dinh theo be ngang man hinh: iPad / web rong thi chu to hon.
  static double defaultScaleForWidth(double width) =>
      width > wideScreenBreakpoint ? wideScreenDefaultScale : 1.0;

  /// Co chu dang dung. Widget nghe bang ValueListenableBuilder de doi ngay
  /// khong can khoi dong lai app.
  final ValueNotifier<double> textScale = ValueNotifier<double>(1.0);

  bool _loaded = false;

  /// Doc lua chon da luu; chua co thi lay mac dinh theo be ngang man hinh.
  Future<void> load({required double screenWidth}) async {
    if (_loaded) return;
    final fallback = defaultScaleForWidth(screenWidth);
    double scale = fallback;
    try {
      final prefs = await SharedPreferences.getInstance();
      scale = _snap(prefs.getDouble(_textScaleKey) ?? fallback);
    } catch (_) {
      scale = fallback;
    }
    textScale.value = scale;
    _loaded = true;
  }

  /// Luu lua chon moi va ap dung ngay cho toan app.
  Future<void> setScale(double scale) async {
    final snapped = _snap(scale);
    textScale.value = snapped;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_textScaleKey, snapped);
    } catch (_) {
      // Khong luu duoc (che do rieng tu / het cho) thi van giu co chu trong
      // phien nay, chi la lan mo sau quay ve mac dinh.
    }
  }

  /// Test seam: cho phep test nap lai tu SharedPreferences nhieu lan.
  @visibleForTesting
  void resetForTest() {
    _loaded = false;
    textScale.value = 1.0;
  }

  /// Dua ve dung mot moc co san de UI luon chon dung o.
  static double _snap(double value) {
    var best = options.first.scale;
    var bestDelta = (value - best).abs();
    for (final option in options) {
      final delta = (value - option.scale).abs();
      if (delta < bestDelta) {
        best = option.scale;
        bestDelta = delta;
      }
    }
    return best;
  }
}
