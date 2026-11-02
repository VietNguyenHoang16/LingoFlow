import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Đẩy số từ đến hạn sang widget màn hình chính Android.
///
/// Widget native (`DueWidgetProvider`) chỉ hiển thị con số, không tự tính —
/// nó đọc giá trị đã lưu lần cuối. Vì vậy con số chỉ mới khi app mở và tải
/// lại review stats, đúng như cách widget được thiết kế (không đánh thức
/// app chạy nền chỉ để cập nhật một con số).
class DueWidgetService {
  static final DueWidgetService _instance = DueWidgetService._internal();
  factory DueWidgetService() => _instance;
  DueWidgetService._internal();

  static const MethodChannel _channel = MethodChannel('vocab/due_widget');

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> updateDueCount(int count) async {
    if (!_isAndroid) return;
    final safeCount = count < 0 ? 0 : count;
    try {
      await _channel.invokeMethod<bool>(
        'updateDueCount',
        {'count': safeCount},
      );
    } catch (e) {
      // Widget chưa được thêm vào màn hình chính vẫn cập nhật bình thường,
      // nên lỗi ở đây chỉ là bất thường của platform channel — không chặn UI.
      debugPrint('Due widget update failed: $e');
    }
  }
}
