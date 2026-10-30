import 'database_service.dart';
import 'dictionary_service.dart';

/// Một từ người dùng dán vào. Chỉ có `word` lúc parse; `meaning` / `wordType`
/// do AI điền sau khi phân tích.
class ImportLine {
  final int lineNumber; // 1-based
  final String rawLine;
  final String word;
  final String meaning;
  String? wordType; // resolved key (noun/verb/...). null khi AI chưa phân loại.
  String? error; // null = hợp lệ.

  ImportLine({
    required this.lineNumber,
    required this.rawLine,
    required this.word,
    this.meaning = '',
    this.wordType,
    this.error,
  });

  /// Hợp lệ = đã có nghĩa + loại từ (AI điền) và không có lỗi.
  bool get isValid =>
      error == null && meaning.isNotEmpty && (wordType ?? '').isNotEmpty;

  ImportLine copyWith({String? meaning, String? wordType, String? error}) {
    return ImportLine(
      lineNumber: lineNumber,
      rawLine: rawLine,
      word: word,
      meaning: meaning ?? this.meaning,
      wordType: wordType ?? this.wordType,
      error: error ?? this.error,
    );
  }
}

/// Kết quả import.
class ImportResult {
  final int insertedCount;
  final int totalValid;
  final bool cancelled;
  final List<BulkAddFailure> failedWords;

  const ImportResult({
    required this.insertedCount,
    required this.totalValid,
    required this.cancelled,
    this.failedWords = const [],
  });
}

/// Parse danh sách từ + nhờ AI lấy nghĩa / loại từ, check trùng, insert hàng loạt.
class BulkWordImporter {
  static final BulkWordImporter _instance = BulkWordImporter._internal();
  factory BulkWordImporter() => _instance;
  BulkWordImporter._internal();

  final DatabaseService _db = DatabaseService();
  final DictionaryService _dict = DictionaryService();

  /// Tách text người dùng dán thành từng từ: ngăn cách bằng dấu phẩy (chấp nhận
  /// cả dấu chấm phẩy và xuống dòng). Dòng bắt đầu `#` là comment.
  /// KHÔNG gọi API - nghĩa / loại từ do [enrichMeanings] điền.
  List<ImportLine> parseWords(String text) {
    final lines = <ImportLine>[];
    final seen = <String>{};
    int lineNumber = 0;

    for (final raw in text.split(RegExp(r'[,;\n]+'))) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('#')) continue;

      final word = _cleanWord(trimmed);
      if (word.isEmpty) continue;
      lineNumber++;

      final key = word.toLowerCase();
      if (!seen.add(key)) {
        lines.add(ImportLine(
          lineNumber: lineNumber,
          rawLine: trimmed,
          word: word,
          error: 'Trùng trong danh sách',
        ));
        continue;
      }
      if (word.length > 60) {
        lines.add(ImportLine(
          lineNumber: lineNumber,
          rawLine: trimmed,
          word: word,
          error: 'Từ quá dài',
        ));
        continue;
      }
      lines.add(ImportLine(
        lineNumber: lineNumber,
        rawLine: trimmed,
        word: word,
      ));
    }
    return lines;
  }

  /// Bỏ dấu nháy và gạch đầu dòng thường gặp khi copy-paste.
  String _cleanWord(String raw) {
    var word = raw.trim();
    word = word.replaceFirst(RegExp(r'^[-*•]+\s*'), '');
    word = word.replaceAll(RegExp(r'''^["'“”]+|["'“”]+$'''), '');
    word = stripLeadingNumber(word);
    return word.trim();
  }

  /// Bỏ số thứ tự ở đầu dòng khi user dán danh sách đánh số:
  /// "29. asset" -> "asset", "3) give up" -> "give up", "(4) commute" ->
  /// "commute", "29 - take off" -> "take off". Dấu gạch ngang phải có khoảng
  /// trắng sau đó để không phá từ ghép bắt đầu bằng số ("8-bit"); phần sau
  /// số mà vẫn là số thì giữ nguyên ("3.14"). Dòng chỉ còn số thứ tự trả về
  /// '' để bị bỏ qua.
  static String stripLeadingNumber(String input) {
    var text = input.trim();
    // Lặp tối đa 3 lần cho kiểu "1. 2. asset".
    for (var i = 0; i < 3; i++) {
      String? rest;
      for (final pattern in _numberPrefixes) {
        final match = pattern.matchAsPrefix(text);
        if (match == null) continue;
        rest = text.substring(match.end).trimLeft();
        break;
      }
      if (rest == null || rest == text) break;
      if (RegExp(r'^\d').hasMatch(rest)) break;
      text = rest;
    }
    return text;
  }

  /// `29. asset`, `29) asset`, `29: asset` và `29 - take off`.
  static final List<RegExp> _numberPrefixes = [
    RegExp(r'^[#(]?\s*\d+\s*[.):]\s*'),
    RegExp(r'^[#(]?\s*\d+\s*[-–—]\s+'),
  ];

  /// Nhờ AI lấy nghĩa tiếng Việt + loại từ cho các dòng hợp lệ. Từ nào AI không
  /// trả về được sẽ bị đánh dấu lỗi (ui bỏ qua và báo lại).
  Future<List<ImportLine>> enrichMeanings(
    int userId,
    List<ImportLine> lines,
  ) async {
    final candidates =
        lines.where((l) => l.error == null && l.word.isNotEmpty).toList();
    if (candidates.isEmpty) return lines;

    Map<String, AiWordInfo> byWord;
    try {
      final infos =
          await _db.enrichWords(candidates.map((l) => l.word).toList());
      byWord = {for (final info in infos) info.word.toLowerCase(): info};
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      return lines
          .map((l) => l.error == null ? l.copyWith(error: message) : l)
          .toList();
    }

    return lines.map((l) {
      if (l.error != null) return l;
      final info = byWord[l.word.toLowerCase()];
      if (info == null || !info.isUsable) {
        return l.copyWith(error: 'AI không lấy được nghĩa');
      }
      return l.copyWith(meaning: info.meaning, wordType: info.wordType);
    }).toList();
  }

  /// Kiem tra tu trung bang 1 request duy nhat. Danh dau `Trùng từ`
  /// trên tất cả dòng có cùng word (case-insensitive).
  Future<List<ImportLine>> checkDuplicates(
    int userId,
    List<ImportLine> lines,
  ) async {
    // Chay truoc khi AI điền nghĩa nên chỉ cần dòng chưa có lỗi.
    final candidates = <String>{};
    for (final l in lines) {
      if (l.error == null && l.word.isNotEmpty) {
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
      if (l.error != null) return l;
      if (existing.contains(l.word.toLowerCase())) {
        return l.copyWith(error: 'Trùng từ');
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
    void Function(int round, int remaining)? onRetry,
    Future<BulkAddResult> Function(
      int userId,
      String category,
      List<Map<String, dynamic>> words,
    )? bulkAdd,
    Map<String, String>? pronunciationsOverride,
  }) async {
    final valid = lines.where((l) => l.isValid).toList();
    if (valid.isEmpty) {
      return const ImportResult(insertedCount: 0, totalValid: 0, cancelled: false);
    }

    if (isCancelled?.call() ?? false) {
      return ImportResult(insertedCount: 0, totalValid: valid.length, cancelled: true);
    }

    final failures = <BulkAddFailure>[];
    final addBulk = bulkAdd ?? _db.bulkAddCategoryWords;

    // Giai doan 1: fetch phat am song song (có progress từng từ)
    pronunciations.clear();
    onProgress?.call(0, valid.length);
    onFetchProgress?.call(0, valid.length);
    if (pronunciationsOverride != null) {
      pronunciations.addAll(pronunciationsOverride);
      onFetchProgress?.call(valid.length, valid.length);
    } else {
      await _fetchPronunciations(
        valid,
        onFetchProgress: onFetchProgress,
        isCancelled: isCancelled,
      );
    }

    if (isCancelled?.call() ?? false) {
      return ImportResult(
        insertedCount: 0,
        totalValid: valid.length,
        cancelled: true,
        failedWords: failures,
      );
    }

    // Giai doan 2: chen theo lo, tu dong retry loi tam thoi qua request moi.
    final lineByWord = {
      for (final line in valid) line.word.toLowerCase(): line,
    };
    const maxRetryRounds = 2;
    var remaining = valid;
    var inserted = 0;
    var resolved = 0;
    var round = 0;

    while (remaining.isNotEmpty && round <= maxRetryRounds) {
      if (round > 0) {
        onRetry?.call(round, remaining.length);
        await Future.delayed(const Duration(seconds: 1));
      }
      if (isCancelled?.call() ?? false) {
        return ImportResult(
          insertedCount: inserted,
          totalValid: valid.length,
          cancelled: true,
          failedWords: failures,
        );
      }

      final nextRound = <ImportLine>[];
      final groups = <String, List<ImportLine>>{};
      for (final line in remaining) {
        groups.putIfAbsent(line.wordType!, () => []).add(line);
      }
      final chunkSize = round == 0 ? 100 : 25;
      var cancelled = false;

      for (final entry in groups.entries) {
        final group = entry.value;
        for (var i = 0; i < group.length; i += chunkSize) {
          if (isCancelled?.call() ?? false) {
            cancelled = true;
            break;
          }
          final chunk = group.sublist(i, (i + chunkSize).clamp(0, group.length));
          final result = await _importChunk(
            addBulk,
            userId,
            entry.key,
            chunk,
            allowSplit: round == 0,
          );
          inserted += result.insertedCount;
          resolved += result.insertedCount;
          for (final failure in result.failed) {
            final line = lineByWord[failure.word.toLowerCase()];
            if (failure.retryable && round < maxRetryRounds && line != null) {
              nextRound.add(line);
            } else {
              failures.add(failure);
              resolved += 1;
            }
          }
          onProgress?.call(resolved.clamp(0, valid.length), valid.length);
        }
        if (cancelled) break;
      }

      if (cancelled) {
        return ImportResult(
          insertedCount: inserted,
          totalValid: valid.length,
          cancelled: true,
          failedWords: failures,
        );
      }

      remaining = nextRound;
      round += 1;
    }

    // Mot so tu co the bi server coi la trung sau request mat phan hoi.
    onProgress?.call(valid.length, valid.length);
    return ImportResult(
      insertedCount: inserted,
      totalValid: valid.length,
      cancelled: false,
      failedWords: failures,
    );
  }

  Future<BulkAddResult> _importChunk(
    Future<BulkAddResult> Function(
      int userId,
      String category,
      List<Map<String, dynamic>> words,
    ) addBulk,
    int userId,
    String category,
    List<ImportLine> chunk, {
    required bool allowSplit,
  }) async {
    try {
      return await addBulk(userId, category, _payload(chunk));
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      if (allowSplit && chunk.length > 10 && !_isAuthError(message)) {
        final mid = chunk.length ~/ 2;
        final first = await _importChunk(
          addBulk,
          userId,
          category,
          chunk.sublist(0, mid),
          allowSplit: false,
        );
        final second = await _importChunk(
          addBulk,
          userId,
          category,
          chunk.sublist(mid),
          allowSplit: false,
        );
        return BulkAddResult(
          insertedCount: first.insertedCount + second.insertedCount,
          failed: [...first.failed, ...second.failed],
        );
      }
      return BulkAddResult(
        insertedCount: 0,
        failed: chunk
            .map((line) => BulkAddFailure(
                  word: line.word,
                  message: message,
                  retryable:
                      !_isAuthError(message) &&
                      !message.contains('Khong co quyen'),
                ))
            .toList(),
      );
    }
  }

  /// Chỉ gửi dữ liệu AI đã điền; nhãn chủ đề / common synonyms để trống.
  List<Map<String, dynamic>> _payload(List<ImportLine> chunk) => chunk.map((l) => {
        'word': l.word,
        'pronunciation': pronunciations[l.word.toLowerCase()] ?? '',
        'meaning': l.meaning,
        'wordType': l.wordType,
        'topicTag': '',
        'commonSynonyms': '',
      }).toList();

  bool _isAuthError(String message) =>
      message.contains('Phiên đăng nhập') ||
      message.contains('Phien dang nhap') ||
      message.contains('đăng nhập') ||
      message.contains('dang nhap');
}
