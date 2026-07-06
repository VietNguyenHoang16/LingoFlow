import 'package:flutter/foundation.dart';

import 'database_service.dart';
import '../widgets/word_type_utils.dart';

/// Một dòng sau khi parse từ text. Lưu cả dữ liệu thô và kết quả validate.
class ImportLine {
  final int lineNumber; // 1-based
  final String rawLine;
  final String word;
  final String posNumber;
  final String meaning;
  String? wordType; // resolved key (noun/verb/...). null nếu POS không hợp lệ.
  String? error; // null = hợp lệ.

  ImportLine({
    required this.lineNumber,
    required this.rawLine,
    required this.word,
    required this.posNumber,
    required this.meaning,
    this.wordType,
    this.error,
  });

  bool get isValid => error == null;
}

/// Kết quả import.
class ImportResult {
  final int insertedCount;
  final int totalValid;
  final bool cancelled;

  const ImportResult({
    required this.insertedCount,
    required this.totalValid,
    required this.cancelled,
  });
}

/// Parse text + validate format, check trùng, insert hàng loạt.
class BulkWordImporter {
  static final BulkWordImporter _instance = BulkWordImporter._internal();
  factory BulkWordImporter() => _instance;
  BulkWordImporter._internal();

  final DatabaseService _db = DatabaseService();

  // Match `word/pos/meaning` với chỉ 2 dấu `/` phân cách đầu/cuối.
  // Lý do anchor ^ và $: nghĩa tiếng Việt có thể chứa `/` (vd: "đây / đó").
  static final RegExp _linePattern = RegExp(r'^([^/]+)/([^/]+)/(.*)$');

  /// Tách text thành các dòng, bỏ dòng trống + dòng comment (bắt đầu `#`).
  /// Validate format. KHÔNG gọi API.
  List<ImportLine> parseLines(String text) {
    final lines = <ImportLine>[];
    final rawLines = text.split('\n');
    int lineNumber = 0;
    for (final raw in rawLines) {
      // Bỏ qua carriage return cuối dòng (Windows).
      final trimmed = raw.trim().replaceAll(RegExp(r'\r$'), '');
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('#')) continue;

      lineNumber++;
      final match = _linePattern.firstMatch(trimmed);
      if (match == null) {
        lines.add(ImportLine(
          lineNumber: lineNumber,
          rawLine: trimmed,
          word: '',
          posNumber: '',
          meaning: '',
          error: 'Sai định dạng. Cần: từ / số_POS / nghĩa',
        ));
        continue;
      }

      final word = match.group(1)!.trim();
      final posStr = match.group(2)!.trim();
      final meaning = match.group(3)!.trim();
      final wordType = parsePosNumber(posStr);

      if (word.isEmpty) {
        lines.add(ImportLine(
          lineNumber: lineNumber,
          rawLine: trimmed,
          word: word,
          posNumber: posStr,
          meaning: meaning,
          wordType: wordType,
          error: 'Thiếu từ',
        ));
        continue;
      }
      if (meaning.isEmpty) {
        lines.add(ImportLine(
          lineNumber: lineNumber,
          rawLine: trimmed,
          word: word,
          posNumber: posStr,
          meaning: meaning,
          wordType: wordType,
          error: 'Thiếu nghĩa',
        ));
        continue;
      }
      if (wordType == null) {
        lines.add(ImportLine(
          lineNumber: lineNumber,
          rawLine: trimmed,
          word: word,
          posNumber: posStr,
          meaning: meaning,
          wordType: null,
          error: 'Số POS không hợp lệ (1-12)',
        ));
        continue;
      }

      lines.add(ImportLine(
        lineNumber: lineNumber,
        rawLine: trimmed,
        word: word,
        posNumber: posStr,
        meaning: meaning,
        wordType: wordType,
      ));
    }
    return lines;
  }

  /// Gọi searchWord cho từng từ unique. Đánh dấu `Trùng từ` trên tất cả dòng
  /// có cùng word (case-insensitive) nếu từ đó đã tồn tại trong DB.
  /// Bỏ qua dòng đã có lỗi khác.
  Future<List<ImportLine>> checkDuplicates(
    int userId,
    List<ImportLine> lines,
  ) async {
    final candidates = <String>{};
    for (final l in lines) {
      if (l.isValid) {
        candidates.add(l.word.toLowerCase());
      }
    }
    if (candidates.isEmpty) return lines;

    final existing = <String>{};
    for (final word in candidates) {
      try {
        final matches = await _db.searchWord(userId, word);
        for (final m in matches) {
          final w = (m['word'] as String? ?? '').toLowerCase();
          if (w == word) {
            existing.add(word);
            break;
          }
        }
      } catch (_) {
        // Skip nếu lỗi 1 từ — không chặn cả batch.
      }
    }

    if (existing.isEmpty) return lines;

    return lines.map((l) {
      if (!l.isValid) return l;
      if (existing.contains(l.word.toLowerCase())) {
        return ImportLine(
          lineNumber: l.lineNumber,
          rawLine: l.rawLine,
          word: l.word,
          posNumber: l.posNumber,
          meaning: l.meaning,
          wordType: l.wordType,
          error: 'Trùng từ',
        );
      }
      return l;
    }).toList();
  }

  /// Insert tuần tự các dòng hợp lệ. Check cancel mỗi vòng.
  /// Caller đã chạy `parseLines` + `checkDuplicates` trước đó.
  /// Trả về [isCancelled] cho caller — nếu true, caller set cờ cancel
  /// (qua [onCancel]) trước vòng lặp tiếp theo.
  Future<ImportResult> importBatch(
    int userId,
    List<ImportLine> lines, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final valid = lines.where((l) => l.isValid).toList();
    if (valid.isEmpty) {
      return const ImportResult(insertedCount: 0, totalValid: 0, cancelled: false);
    }

    int inserted = 0;
    for (int i = 0; i < valid.length; i++) {
      if (isCancelled?.call() ?? false) {
        return ImportResult(
          insertedCount: inserted,
          totalValid: valid.length,
          cancelled: true,
        );
      }
      final l = valid[i];
      try {
        await _db.addWordToCategory(
          userId,
          l.wordType!,
          l.word,
          '', // pronunciation
          l.meaning,
          wordType: l.wordType,
        );
        inserted++;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('BulkWordImporter: failed to insert "${l.word}" → $e');
        }
        // Tiếp tục dòng tiếp theo — lỗi insert từng từ không chặn batch.
      }
      onProgress?.call(i + 1, valid.length);
    }
    return ImportResult(
      insertedCount: inserted,
      totalValid: valid.length,
      cancelled: false,
    );
  }
}
