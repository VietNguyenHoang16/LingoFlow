import 'database_service.dart';
import 'dictionary_service.dart';
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
  final DictionaryService _dict = DictionaryService();

  // Các format được hỗ trợ (thử theo thứ tự):
  //   1. Ưu tiên: số_POS :: từ :: nghĩa       (dấu `::` chắc chắn không nhầm)
  //   2. Dự phòng: số_POS || từ || nghĩa      (pipe kép)
  //   3. Cũ: từ / số_POS / nghĩa              (backward compat)
  static final RegExp _fmtNew = RegExp(r'^(\d{1,2})\s*::\s*(.*?)\s*::\s*(.*)$');
  static final RegExp _fmtPipe = RegExp(r'^(\d{1,2})\s*\|\|\s*(.*?)\s*\|\|\s*(.*)$');
  static final RegExp _fmtOld = RegExp(r'^(.*)\/(\d{1,2})\/(.*)$');

  /// Thử lần lượt các format, trả về (word, pos, meaning) nếu match, null nếu không.
  static ({String word, String pos, String meaning})? _parseFormat(String line) {
    // Format 1: POS :: word :: meaning
    var m = _fmtNew.firstMatch(line);
    if (m != null) {
      return (word: m.group(2)!, pos: m.group(1)!, meaning: m.group(3)!);
    }
    // Format 2: POS || word || meaning
    m = _fmtPipe.firstMatch(line);
    if (m != null) {
      return (word: m.group(2)!, pos: m.group(1)!, meaning: m.group(3)!);
    }
    // Format cũ: word / POS / meaning
    m = _fmtOld.firstMatch(line);
    if (m != null) {
      return (word: m.group(1)!, pos: m.group(2)!, meaning: m.group(3)!);
    }
    return null;
  }

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

      String word = '', posStr = '', meaning = '';
      final match = _parseFormat(trimmed);
      if (match == null) {
        lines.add(ImportLine(
          lineNumber: lineNumber,
          rawLine: trimmed,
          word: '',
          posNumber: '',
          meaning: '',
          error: 'Sai định dạng. Cần: số_POS :: từ :: nghĩa',
        ));
        continue;
      }
      word = match.word.trim();
      posStr = match.pos.trim();
      meaning = match.meaning.trim();
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

  /// Kiem tra tu trung bang 1 request duy nhat. Danh dau `Trùng từ`
  /// trên tất cả dòng có cùng word (case-insensitive).
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

    Set<String> existing;
    try {
      existing = await _db.filterExistingWords(userId, candidates.toList());
    } catch (_) {
      // Khong kiem tra duoc thi khong danh dau trung.
      return lines;
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

  /// Fetch phát âm song song, báo tiến độ từng từ để UI mượt.
  /// Dedup theo lowercase để không fetch trùng. Timeout ngắn cho import.
  Future<void> _fetchPronunciations(
    List<ImportLine> words, {
    void Function(int fetched, int total)? onFetchProgress,
    Duration fetchTimeout = const Duration(seconds: 4),
    bool Function()? isCancelled,
  }) async {
    final unique = <String, ImportLine>{};
    for (final l in words) {
      unique.putIfAbsent(l.word.toLowerCase(), () => l);
    }
    final targets = unique.values.toList();
    if (targets.isEmpty) return;

    int fetched = 0;
    onFetchProgress?.call(0, targets.length);

    Future<void> fetchOne(ImportLine l) async {
      if (isCancelled?.call() ?? false) return;
      try {
        final p = await _dict.fetchPronunciation(l.word, timeout: fetchTimeout);
        pronunciations[l.word.toLowerCase()] = p;
      } catch (_) {
        pronunciations[l.word.toLowerCase()] = '';
      }
      fetched++;
      onFetchProgress?.call(fetched, targets.length);
    }

    // <20 từ: 1 batch duy nhất cho nhanh nhất. Nhiều hơn: chia batch 10.
    const batchSize = 10;
    for (int i = 0; i < targets.length; i += batchSize) {
      if (isCancelled?.call() ?? false) return;
      final batch = targets.sublist(i, (i + batchSize).clamp(0, targets.length));
      await Future.wait(batch.map(fetchOne));
    }
  }

  final Map<String, String> pronunciations = {};

  /// Insert các dòng hợp lệ theo lô. Check cancel giữa các lô.
  Future<ImportResult> importBatch(
    int userId,
    List<ImportLine> lines, {
    void Function(int done, int total)? onProgress,
    void Function(int fetched, int total)? onFetchProgress,
    bool Function()? isCancelled,
  }) async {
    final valid = lines.where((l) => l.isValid).toList();
    if (valid.isEmpty) {
      return const ImportResult(insertedCount: 0, totalValid: 0, cancelled: false);
    }

    if (isCancelled?.call() ?? false) {
      return ImportResult(insertedCount: 0, totalValid: valid.length, cancelled: true);
    }

    // Giai doan 1: fetch phat am song song (có progress từng từ)
    pronunciations.clear();
    onProgress?.call(0, valid.length);
    onFetchProgress?.call(0, valid.length);
    await _fetchPronunciations(
      valid,
      onFetchProgress: onFetchProgress,
      isCancelled: isCancelled,
    );

    if (isCancelled?.call() ?? false) {
      return ImportResult(insertedCount: 0, totalValid: valid.length, cancelled: true);
    }

    // Giai doan 2: chen theo lo 100 dong / request, nhom theo wordType
    int inserted = 0;
    const chunkSize = 100;
    final groups = <String, List<ImportLine>>{};
    for (final l in valid) {
      groups.putIfAbsent(l.wordType!, () => []).add(l);
    }
    int done = 0;
    for (final entry in groups.entries) {
      final group = entry.value;
      for (int i = 0; i < group.length; i += chunkSize) {
        if (isCancelled?.call() ?? false) {
          return ImportResult(
            insertedCount: inserted,
            totalValid: valid.length,
            cancelled: true,
          );
        }
        final chunk = group.sublist(i, (i + chunkSize).clamp(0, group.length));
        final payload = chunk.map((l) => {
              'word': l.word,
              'pronunciation': pronunciations[l.word.toLowerCase()] ?? '',
              'meaning': l.meaning,
              'wordType': l.wordType,
            }).toList();
        try {
          inserted += await _db.bulkAddCategoryWords(userId, entry.key, payload);
        } catch (_) {
          // Loi ca lo - thu tung dong de giu toi da du lieu.
          for (final line in chunk) {
            try {
              await _db.addWordToCategory(
                userId,
                line.wordType!,
                line.word,
                pronunciations[line.word.toLowerCase()] ?? '',
                line.meaning,
                wordType: line.wordType,
              );
              inserted++;
            } catch (_) {}
          }
        }
        done += chunk.length;
        onProgress?.call(done.clamp(0, valid.length), valid.length);
      }
    }
    return ImportResult(
      insertedCount: inserted,
      totalValid: valid.length,
      cancelled: false,
    );
  }
}
