import 'package:flutter/services.dart';

class DownloadService {
  static Future<void> downloadJson({
    required String filename,
    required String jsonContent,
  }) async {
    await Clipboard.setData(ClipboardData(text: jsonContent));
  }
}
