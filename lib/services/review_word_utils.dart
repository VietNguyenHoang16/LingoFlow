/// Utilities an toan cho du lieu tu vung trong phien review.
/// Regression cho bug RangeError (index ngoai pham vi) va
/// TypeError (cast cung `as int` tren map chua chuan hoa).

import 'word_details_parser.dart';

/// Tra ve tu tai vi tri [index], hoac null neu index nam ngoai danh sach.
Map<String, dynamic>? wordAt(List<Map<String, dynamic>> words, int index) {
  if (index < 0 || index >= words.length) return null;
  return words[index];
}

int _safeInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is bool) return value ? 1 : 0;
  return int.tryParse(value.toString()) ?? 0;
}

double _safeDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}

String _safeString(dynamic value) => value?.toString() ?? '';

bool _safeBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final s = value?.toString().toLowerCase();
  return s == 'true' || s == '1';
}

DateTime? _safeDate(dynamic value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

/// Chuan hoa mot row tu vung: moi truong so/boolean/date deu la kieu an toan,
/// khong bao gio lam crash UI khi server tra ve du lieu thieu / sai kieu.
Map<String, dynamic> normalizeWord(Map<String, dynamic> raw) {
  final word = Map<String, dynamic>.from(raw);
  for (final key in [
    'review_count',
    'correct_streak',
    'interval_days',
    'mastery_level',
    'lapse_count',
  ]) {
    word[key] = _safeInt(word[key]);
  }
  word['ease_factor'] = _safeDouble(word['ease_factor']);
  word['is_mastered'] = _safeBool(word['is_mastered']);
  word['is_difficult'] = _safeBool(word['is_difficult']);
  word['pronunciation'] = _safeString(word['pronunciation']);
  word['meaning'] = _safeString(word['meaning']);
  word['full_details'] = _safeString(word['full_details']);
  word['word_type'] = _safeString(word['word_type']);
  word['next_review_date'] = _safeDate(word['next_review_date']);
  word['last_reviewed_at'] = _safeDate(word['last_reviewed_at']);
  // Parse full_details for structured data and extract first example.
  final parsed = parseFullDetails(word['full_details'] ?? '');
  word['details_parsed'] = parsed;
  word['example'] = extractFirstExample(parsed);
  return word;
}
