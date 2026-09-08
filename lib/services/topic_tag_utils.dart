/// Tách nhãn chủ đề khỏi cuối chuỗi nghĩa theo rule:
/// nhãn = phần sau dấu ` - ` CUỐI CÙNG, VD: `dùng hết sạch - gym` -> (dùng hết sạch, gym).
/// Không có suffix -> nhãn rỗng, nghĩa giữ nguyên.
({String meaning, String topicTag}) splitTopicTag(String input) {
  const sep = ' - ';
  final idx = input.lastIndexOf(sep);
  if (idx == -1) return (meaning: input.trim(), topicTag: '');
  final tag = input.substring(idx + sep.length).trim();
  if (tag.isEmpty) return (meaning: input.substring(0, idx).trim(), topicTag: '');
  return (
    meaning: input.substring(0, idx).trim(),
    topicTag: tag.length > 100 ? tag.substring(0, 100) : tag,
  );
}
