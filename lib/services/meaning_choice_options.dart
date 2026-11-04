import 'dart:math';

/// Mot lua chon nghia tren the cau hoi che do "nhin tu chon nghia".
class MeaningOption {
  final String meaning;
  final bool isCorrect;
  const MeaningOption({required this.meaning, required this.isCorrect});
}

/// Dung bo lua chon cho mot cau: 1 dap an dung + toi da 3 nhiu lay **ngau nhien**
/// tu [poolMeanings] (thuong la ngia cua toan bo tu vung — list tong).
///
/// - Loai bo nghia rong, nghia trung dap an dung (so sanh khong phan biet
///   hoa/viet hoa va khoang trang hai dau) va nghia trung nhau.
/// - Nhiu duoc chon ngau nhien (shuffle ung vien truoc khi lay 3) de moi lan
///   ra de lai khac nhau, khong lap lai mot bo co dinh theo thu tu danh sach.
/// - Thu tra list da shuffle; so luong = 1 + so nhiu co duoc (1..4).
///   Goi voi pool qua it thi tra it lua chon hon — trang tu dong ve che do
///   gõ tu khi chi con 1 dap an (khong the ra de).
List<MeaningOption> buildMeaningOptions({
  required String correctMeaning,
  required Iterable<String> poolMeanings,
  required Random random,
}) {
  final correct = correctMeaning.trim();
  final seen = <String>{_normalize(correct)};
  final candidates = <String>[];
  for (final raw in poolMeanings) {
    final meaning = raw.trim();
    if (meaning.isEmpty) continue;
    final key = _normalize(meaning);
    if (seen.contains(key)) continue;
    seen.add(key);
    candidates.add(meaning);
  }
  candidates.shuffle(random);
  final options = <MeaningOption>[
    MeaningOption(meaning: correct, isCorrect: true),
    for (final d in candidates.take(3))
      MeaningOption(meaning: d, isCorrect: false),
  ];
  options.shuffle(random);
  return options;
}

String _normalize(String s) => s.toLowerCase();
