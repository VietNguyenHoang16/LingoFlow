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
  String collocations; // cụm từ đi kèm do AI gợi ý ('' nếu không có).

  /// Các từ cùng nghĩa được gộp vào từ này (tối đa 3) -> `common_synonyms`.
  List<String> synonyms;

  /// Tên từ đã "nuốt" dòng này khi gộp từ đồng nghĩa ('' nếu không bị gộp).
  String mergedInto;

  String? error; // null = hợp lệ.

  static const String errorDuplicateInDb = 'Trùng từ';
  static const String errorDuplicateInList = 'Trùng trong danh sách';
  static const String errorAiMissing = 'AI không lấy được nghĩa';

  /// Dòng bị gộp vào một từ khác cùng nghĩa (vd `verbose/wordy`). Không phải
  /// lỗi nhập liệu: UI tô màu riêng và vẫn hiện nghĩa.
  static const String errorMergedPrefix = 'Gộp vào ';

  ImportLine({
    required this.lineNumber,
    required this.rawLine,
    required this.word,
    this.meaning = '',
    this.wordType,
    this.collocations = '',
    List<String>? synonyms,
    this.mergedInto = '',
    this.error,
  }) : synonyms = synonyms ?? <String>[];

  /// Hợp lệ = đã có nghĩa + loại từ (AI điền) và không có lỗi.
  bool get isValid =>
      error == null && meaning.isNotEmpty && (wordType ?? '').isNotEmpty;

  /// Từ bị trùng (đã có trong bộ từ, hoặc lặp lại trong danh sách dán vào).
  /// Không phải lỗi nhập liệu nên UI tô màu riêng, và vẫn hiện nghĩa.
  bool get isDuplicate =>
      error == errorDuplicateInDb || error == errorDuplicateInList;

  /// Dòng đã bị gộp vào từ khác cùng nghĩa trong lần import này.
  bool get isMerged => mergedInto.isNotEmpty;

  /// Chuỗi hiển thị/lưu vào `common_synonyms`.
  String get commonSynonyms => synonyms.join(' · ');

  ImportLine copyWith({
    String? meaning,
    String? wordType,
    String? collocations,
    List<String>? synonyms,
    String? mergedInto,
    String? error,
  }) {
    return ImportLine(
      lineNumber: lineNumber,
      rawLine: rawLine,
      word: word,
      meaning: meaning ?? this.meaning,
      wordType: wordType ?? this.wordType,
      collocations: collocations ?? this.collocations,
      synonyms: synonyms ?? this.synonyms,
      mergedInto: mergedInto ?? this.mergedInto,
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

      final parts = _splitGroup(_cleanWord(trimmed));
      if (parts.isEmpty) continue;
      final word = parts.first;
      final synonyms = parts.skip(1).toList(growable: false);
      if (word.isEmpty) continue;
      lineNumber++;

      final key = word.toLowerCase();
      if (!seen.add(key)) {
        lines.add(ImportLine(
          lineNumber: lineNumber,
          rawLine: trimmed,
          word: word,
          synonyms: synonyms,
          error: ImportLine.errorDuplicateInList,
        ));
        continue;
      }
      if (word.length > 60) {
        lines.add(ImportLine(
          lineNumber: lineNumber,
          rawLine: trimmed,
          word: word,
          synonyms: synonyms,
          error: 'Từ quá dài',
        ));
        continue;
      }
      lines.add(ImportLine(
        lineNumber: lineNumber,
        rawLine: trimmed,
        word: word,
        synonyms: synonyms,
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

  /// Tách nhóm từ đồng nghĩa viết trên cùng một dòng: `verbose/wordy`,
  /// `verbose = wordy`, `verbose / wordy / long-winded`. Từ đầu là từ chính,
  /// các từ còn lại vào `common_synonyms` (tối đa 3). Trả về đúng 1 phần tử
  /// khi dòng không phải nhóm (hoặc không nên tách, vd `24/7`).
  List<String> _splitGroup(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const [];
    final parts = text
        .split(RegExp(r'\s*[=/]\s*'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length == 1) return parts;
    // Chỉ tách khi cả hai vế đều là cụm chữ (24/7, 8/10 giữ nguyên).
    if (!parts.every(_isWordLike)) return [text];
    final head = parts.first;
    final extras = <String>[];
    for (final part in parts.skip(1)) {
      if (_hasWord(extras, part) || part.toLowerCase() == head.toLowerCase()) {
        continue;
      }
      extras.add(part);
      if (extras.length >= _maxSynonyms) break;
    }
    return [head, ...extras];
  }

  /// Một vế chỉ gồm chữ cái, khoảng trắng, gạch nối, nháy đơn.
  static bool _isWordLike(String value) {
    final v = value.trim();
    if (v.isEmpty || v.length > 60) return false;
    return RegExp(r"^[A-Za-z][A-Za-z'’,.\- ]*$").hasMatch(v);
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
    if (candidates.isEmpty) return _fillListDuplicates(lines);

    Map<String, AiWordInfo> byWord;
    try {
      final infos =
          await _db.enrichWords(candidates.map((l) => l.word).toList());
      byWord = {for (final info in infos) info.word.toLowerCase(): info};
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      return _fillListDuplicates(
        lines
            .map((l) => l.error == null ? l.copyWith(error: message) : l)
            .toList(),
      );
    }

    final enriched = lines.map((l) {
      if (l.error != null) return l;
      final info = byWord[l.word.toLowerCase()];
      if (info == null || !info.isUsable) {
        return l.copyWith(error: ImportLine.errorAiMissing);
      }
      return l.copyWith(
        meaning: info.meaning,
        wordType: info.wordType,
        collocations: info.collocations,
        synonyms: _mergeSynonyms(l.synonyms, info.synonyms),
      );
    }).toList();
    // Gộp từ cùng nghĩa (verbose + wordy) thành 1 card trước khi import.
    return _fillListDuplicates(_mergeSynonymGroups(enriched));
  }

  /// Dòng trùng trong danh sách dán vào không được AI phân tích; lấy nghĩa của
  /// dòng đầu tiên cùng từ để bảng import vẫn hiển thị nghĩa.
  List<ImportLine> _fillListDuplicates(List<ImportLine> lines) {
    final byWord = <String, ImportLine>{};
    for (final l in lines) {
      if (l.error == null && l.meaning.isNotEmpty) {
        byWord.putIfAbsent(l.word.toLowerCase(), () => l);
      }
    }
    return lines.map((l) {
      if (l.error != ImportLine.errorDuplicateInList) return l;
      final src = byWord[l.word.toLowerCase()];
      if (src == null) return l;
      return l.copyWith(
        meaning: src.meaning,
        wordType: src.wordType,
        collocations: src.collocations,
      );
    }).toList();
  }

  static const int _maxSynonyms = 3;

  /// Ghép từ đồng nghĩa AI trả về vào nhóm người dùng đã gõ, giữ tối đa 3.
  List<String> _mergeSynonyms(List<String> base, List<String> fromAi) {
    final result = <String>[];
    for (final item in [...base, ...fromAi]) {
      final value = item.trim();
      if (value.isEmpty || _hasWord(result, value)) continue;
      result.add(value);
      if (result.length >= _maxSynonyms) break;
    }
    return result;
  }

  /// Gộp các từ cùng nghĩa thành 1 card trước khi import. Hai dòng là cùng
  /// nghĩa khi từ của dòng này nằm trong danh sách đồng nghĩa của dòng kia (AI
  /// trả về) hoặc nghĩa tiếng Việt giống hệt nhau. Dòng đầu tiên làm từ chính,
  /// các từ còn lại vào `common_synonyms` và bị đánh dấu đã gộp; nhóm quá 4 từ
  /// thì các từ dư vẫn thành card riêng.
  List<ImportLine> _mergeSynonymGroups(List<ImportLine> lines) {
    final indexes = [
      for (var i = 0; i < lines.length; i++)
        if (lines[i].isValid) i,
    ];
    if (indexes.length < 2) return lines;

    final parent = <int, int>{for (final i in indexes) i: i};
    int find(int i) {
      var root = i;
      while (parent[root] != root) {
        root = parent[root]!;
      }
      while (parent[i] != root) {
        final next = parent[i]!;
        parent[i] = root;
        i = next;
      }
      return root;
    }

    bool sameMeaning(ImportLine a, ImportLine b) {
      final key = _meaningKey(a.meaning);
      return key.isNotEmpty && key == _meaningKey(b.meaning);
    }

    bool sameWord(ImportLine a, ImportLine b) =>
        _hasWord(a.synonyms, b.word) || _hasWord(b.synonyms, a.word);

    for (var x = 0; x < indexes.length; x++) {
      for (var y = x + 1; y < indexes.length; y++) {
        final a = lines[indexes[x]];
        final b = lines[indexes[y]];
        if (!sameWord(a, b) && !sameMeaning(a, b)) continue;
        final ra = find(indexes[x]);
        final rb = find(indexes[y]);
        if (ra != rb) parent[rb] = ra;
      }
    }

    final groups = <int, List<int>>{};
    for (final i in indexes) {
      groups.putIfAbsent(find(i), () => <int>[]).add(i);
    }

    final merged = List<ImportLine>.of(lines);
    for (final group in groups.values) {
      if (group.length < 2) continue;
      group.sort();
      final head = lines[group.first];
      final synonyms = List<String>.of(head.synonyms);
      for (final index in group.skip(1)) {
        // Nhóm đã đủ từ đồng nghĩa -> từ dư ở lại thành card riêng.
        if (synonyms.length >= _maxSynonyms) break;
        final other = lines[index];
        if (other.word.toLowerCase() != head.word.toLowerCase() &&
            !_hasWord(synonyms, other.word)) {
          synonyms.add(other.word);
        }
        merged[index] = other.copyWith(
          error: '${ImportLine.errorMergedPrefix}"${head.word}"',
          mergedInto: head.word,
        );
      }
      if (synonyms.length != head.synonyms.length) {
        merged[group.first] = head.copyWith(synonyms: synonyms);
      }
    }
    return merged;
  }

  static bool _hasWord(List<String> words, String word) {
    final key = word.trim().toLowerCase();
    if (key.isEmpty) return false;
    return words.any((w) => w.trim().toLowerCase() == key);
  }

  /// Chuẩn hoá nghĩa để so sánh: bỏ dấu câu, gộp khoảng trắng, lowercase.
  static String _meaningKey(String meaning) => meaning
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N} ]+', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Kiem tra tu trung bang 1 request duy nhat. Danh dau `Trùng từ`
  /// trên tất cả dòng có cùng word (case-insensitive), kèm nghĩa + loại từ
  /// đã lưu để bảng import hiển thị được.
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

    var existing = <String, ExistingWord>{};
    try {
      for (final word in await _db.findExistingWords(userId, candidates.toList())) {
        existing[word.word.toLowerCase()] = word;
      }
    } catch (_) {
      // API cũ / lỗi mạng: fallback action cũ (chỉ có tên từ, không nghĩa).
      try {
        final names = await _db.filterExistingWords(userId, candidates.toList());
        existing = {
          for (final name in names)
            name.toLowerCase(): ExistingWord(word: name),
        };
      } catch (_) {
        // Khong kiem tra duoc thi khong danh dau trung.
        return lines;
      }
    }

    if (existing.isEmpty) return lines;

    return lines.map((l) {
      if (l.error != null) return l;
      final hit = existing[l.word.toLowerCase()];
      if (hit == null) return l;
      return l.copyWith(
        error: ImportLine.errorDuplicateInDb,
        meaning: hit.meaning,
        wordType: hit.wordType,
      );
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

  /// Chỉ gửi dữ liệu AI đã điền; nhãn chủ đề để trống, từ đồng nghĩa gộp lấy
  /// từ nhóm người dùng gõ (`verbose/wordy`) hoặc AI gợi ý.
  List<Map<String, dynamic>> _payload(List<ImportLine> chunk) => chunk.map((l) => {
        'word': l.word,
        'pronunciation': pronunciations[l.word.toLowerCase()] ?? '',
        'meaning': l.meaning,
        'wordType': l.wordType,
        'topicTag': '',
        'commonSynonyms': l.commonSynonyms,
        'collocations': l.collocations,
      }).toList();

  bool _isAuthError(String message) =>
      message.contains('Phiên đăng nhập') ||
      message.contains('Phien dang nhap') ||
      message.contains('đăng nhập') ||
      message.contains('dang nhap');
}
