// So khớp câu trả lời trong phiên Review / Practice: giữ nguyên ngữ nghĩa
// "đúng/sai" cũ (trim + lowercase, so chuỗi tuyệt đối) và bổ sung "dấu" cho
// từng ký tự để UI tô chỗ sai (thiếu / thừa / gõ lệch).
//
// Thuần Dart, không phụ thuộc Flutter -> test nhanh và tái dùng được cho
// Practice (spell mode) sau này.

/// Trạng thái của một ký tự so với đáp án.
enum CharMarkKind {
  /// Ký tự trùng khớp.
  keep,

  /// Ký tự có trong đáp án nhưng người dùng gõ thiếu.
  missing,

  /// Ký tự người dùng gõ thừa (không có trong đáp án).
  extra,

  /// Ký tự gõ sai (bị thay bằng ký tự khác).
  replaced,
}

/// Một ký tự kèm trạng thái so với đáp án.
///
/// [char] luôn là ký tự thật nằm trong chuỗi tương ứng, nên
/// `marks.map((m) => m.char).join()` luôn dựng lại đúng chuỗi gốc.
class CharMark {
  final String char;
  final CharMarkKind kind;

  /// Vị trí trong chuỗi gốc (đáp án hoặc chuỗi đã gõ, tùy phía sử dụng).
  final int index;

  const CharMark(this.char, this.kind, this.index);

  bool get isMismatch => kind != CharMarkKind.keep;

  @override
  String toString() => 'CharMark("$char", ${kind.name}, $index)';
}

/// Kết quả so sánh một câu trả lời với đáp án.
class AnswerDiff {
  /// Đúng theo đúng quy tắc cũ: `typed.trim().toLowerCase() ==
  /// expected.toLowerCase()`.
  final bool isCorrect;

  /// Khoảng cách Levenshtein (số phép sửa tối thiểu). 0 khi đúng.
  final int distance;

  /// Dấu cho từng ký tự của đáp án (dùng để tô chỗ thiếu/sai).
  final List<CharMark> expectedMarks;

  /// Dấu cho từng ký tự người dùng đã gõ (dùng để tô chỗ thừa/sai).
  final List<CharMark> typedMarks;

  const AnswerDiff({
    required this.isCorrect,
    required this.distance,
    required this.expectedMarks,
    required this.typedMarks,
  });

  /// Có chỗ nào lệch để tô đỏ hay không.
  bool get hasMismatch =>
      expectedMarks.any((m) => m.isMismatch) ||
      typedMarks.any((m) => m.isMismatch);

  /// Số ký tự lệch trên mặt đáp án.
  int get mismatchCount => expectedMarks.where((m) => m.isMismatch).length;

  /// Tỉ lệ giống nhau 0..1 (1 = giống hoàn toàn).
  double get similarity {
    final longest = expectedMarks.length > typedMarks.length
        ? expectedMarks.length
        : typedMarks.length;
    if (longest == 0) return isCorrect ? 1 : 0;
    final ratio = 1 - (distance / longest);
    if (ratio < 0) return 0;
    if (ratio > 1) return 1;
    return ratio;
  }
}

/// Chuỗi dài hơn ngưỡng này sẽ bỏ qua bước căn chỉnh ký tự (an toàn hiệu năng;
/// từ vựng thực tế không bao giờ tới ngưỡng này).
const int _maxAlignChars = 64;

/// Ngưỡng chặn tính Levenshtein cho input bất thường (dán nhầm cả đoạn văn).
const int _maxLevenshteinCells = 25000;

/// Tách chuỗi thành các ký tự theo code point (an toàn với ký tự ngoài BMP),
/// tránh cắt đôi surrogate pair như khi dùng `String[index]`.
List<String> _chars(String value) =>
    value.runes.map(String.fromCharCode).toList();

bool _sameChar(String a, String b) => a.toLowerCase() == b.toLowerCase();

List<CharMark> _allKeep(List<String> chars) => [
      for (var i = 0; i < chars.length; i++)
        CharMark(chars[i], CharMarkKind.keep, i),
    ];

enum _OpKind { keep, missing, extra }

class _Op {
  final _OpKind kind;
  final String char;
  final int expectedIndex;
  final int typedIndex;

  const _Op(this.kind, this.char, this.expectedIndex, this.typedIndex);

  factory _Op.keep(String char, int i, int j) => _Op(_OpKind.keep, char, i, j);
  factory _Op.missing(String char, int i) =>
      _Op(_OpKind.missing, char, i, -1);
  factory _Op.extra(String char, int j) => _Op(_OpKind.extra, char, -1, j);
}

/// Căn chỉnh 2 chuỗi bằng LCS (quy hoạch động, O(n*m) — với từ vựng chỉ vài
/// chục ký tự nên không đáng kể). Ưu tiên đánh dấu "thiếu" khi bằng điểm để lỗi
/// đọc tự nhiên hơn ("thiếu 1 chữ" thay vì "thừa 1 chữ").
List<_Op> _align(List<String> a, List<String> b) {
  final n = a.length;
  final m = b.length;
  final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      if (_sameChar(a[i], b[j])) {
        dp[i][j] = dp[i + 1][j + 1] + 1;
      } else {
        dp[i][j] = dp[i + 1][j] >= dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1];
      }
    }
  }

  final ops = <_Op>[];
  var i = 0;
  var j = 0;
  while (i < n && j < m) {
    if (_sameChar(a[i], b[j])) {
      ops.add(_Op.keep(a[i], i, j));
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      ops.add(_Op.missing(a[i], i));
      i++;
    } else {
      ops.add(_Op.extra(b[j], j));
      j++;
    }
  }
  while (i < n) {
    ops.add(_Op.missing(a[i], i));
    i++;
  }
  while (j < m) {
    ops.add(_Op.extra(b[j], j));
    j++;
  }
  return ops;
}

/// Sinh dấu cho 2 phía, gộp cặp (thiếu + thừa) liền kề thành "gõ lệch" để câu
/// hiển thị không bị nhiễu khi người dùng chỉ sai 1 ký tự.
void _collectMarks(
  List<_Op> ops,
  List<CharMark> expectedMarks,
  List<CharMark> typedMarks,
) {
  var k = 0;
  while (k < ops.length) {
    if (k + 1 < ops.length) {
      final op = ops[k];
      final next = ops[k + 1];
      final isPair = (op.kind == _OpKind.missing && next.kind == _OpKind.extra) ||
          (op.kind == _OpKind.extra && next.kind == _OpKind.missing);
      if (isPair) {
        final missing = op.kind == _OpKind.missing ? op : next;
        final extra = op.kind == _OpKind.extra ? op : next;
        expectedMarks.add(
          CharMark(missing.char, CharMarkKind.replaced, missing.expectedIndex),
        );
        typedMarks.add(
          CharMark(extra.char, CharMarkKind.replaced, extra.typedIndex),
        );
        k += 2;
        continue;
      }
    }

    final op = ops[k];
    switch (op.kind) {
      case _OpKind.keep:
        expectedMarks
            .add(CharMark(op.char, CharMarkKind.keep, op.expectedIndex));
        typedMarks.add(CharMark(op.char, CharMarkKind.keep, op.typedIndex));
        break;
      case _OpKind.missing:
        expectedMarks
            .add(CharMark(op.char, CharMarkKind.missing, op.expectedIndex));
        break;
      case _OpKind.extra:
        typedMarks.add(CharMark(op.char, CharMarkKind.extra, op.typedIndex));
        break;
    }
    k++;
  }
}

/// Phiên bản Levenshtein dùng 2 hàng (bộ nhớ O(min(n,m))).
int _levenshtein(List<String> a, List<String> b) {
  final n = a.length;
  final m = b.length;
  if (n == 0) return m;
  if (m == 0) return n;

  var prev = List<int>.generate(m + 1, (j) => j);
  var cur = List<int>.filled(m + 1, 0);
  for (var i = 1; i <= n; i++) {
    cur[0] = i;
    for (var j = 1; j <= m; j++) {
      final cost = _sameChar(a[i - 1], b[j - 1]) ? 0 : 1;
      var best = prev[j - 1] + cost;
      if (prev[j] + 1 < best) best = prev[j] + 1;
      if (cur[j - 1] + 1 < best) best = cur[j - 1] + 1;
      cur[j] = best;
    }
    final swap = prev;
    prev = cur;
    cur = swap;
  }
  return prev[m];
}

int _safeDistance(List<String> a, List<String> b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  if (a.length * b.length > _maxLevenshteinCells) {
    return (a.length - b.length).abs();
  }
  return _levenshtein(a, b);
}

/// So khớp [typed] với [expected] và trả về dấu từng ký tự để UI tô chỗ sai.
///
/// Không bao giờ ném exception. Người dùng chưa gõ gì (chuỗi rỗng / chỉ khoảng
/// trắng) sẽ không có dấu lệch — chỉ hiện icon sai như cũ.
AnswerDiff diffAnswer({required String typed, required String expected}) {
  final expectedChars = _chars(expected);
  final typedChars = _chars(typed);
  final isCorrect = typed.trim().toLowerCase() == expected.toLowerCase();

  // Đúng, hoặc chưa gõ gì, hoặc dữ liệu quá dài -> không tô gì cả.
  if (isCorrect ||
      typed.trim().isEmpty ||
      expectedChars.isEmpty ||
      typedChars.isEmpty ||
      expectedChars.length > _maxAlignChars ||
      typedChars.length > _maxAlignChars) {
    return AnswerDiff(
      isCorrect: isCorrect,
      distance: isCorrect ? 0 : _safeDistance(expectedChars, typedChars),
      expectedMarks: _allKeep(expectedChars),
      typedMarks: _allKeep(typedChars),
    );
  }

  final expectedMarks = <CharMark>[];
  final typedMarks = <CharMark>[];
  _collectMarks(_align(expectedChars, typedChars), expectedMarks, typedMarks);

  // Khác hẳn đáp án (không chung ký tự nào): tô kín cả từ chỉ gây nhiễu, giữ
  // cách hiển thị cũ (hai chuỗi bình thường).
  if (!expectedMarks.any((m) => m.kind == CharMarkKind.keep)) {
    return AnswerDiff(
      isCorrect: false,
      distance: _safeDistance(expectedChars, typedChars),
      expectedMarks: _allKeep(expectedChars),
      typedMarks: _allKeep(typedChars),
    );
  }

  return AnswerDiff(
    isCorrect: false,
    distance: _safeDistance(expectedChars, typedChars),
    expectedMarks: expectedMarks,
    typedMarks: typedMarks,
  );
}
