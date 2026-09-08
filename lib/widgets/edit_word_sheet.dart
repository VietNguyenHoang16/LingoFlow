import 'package:flutter/material.dart';

import 'word_type_utils.dart';

/// Kết quả trả về từ [showEditWordSheet]. null = người dùng hủy.
class EditWordResult {
  final String word;
  final String meaning;
  final String pronunciation;
  final String fullDetails;
  final String wordType;
  final String topicTag;

  const EditWordResult({
    required this.word,
    required this.meaning,
    required this.pronunciation,
    required this.fullDetails,
    required this.wordType,
    required this.topicTag,
  });
}

/// Bottom sheet sửa từ dùng chung cho 3 màn hình (Recent, danh mục, bộ từ).
/// Thiết kế gọn để hiển thị đủ nội dung không cần cuộn trên điện thoại phổ thông:
/// field dense 1 dòng, chip loại từ cuộn ngang, Chi tiết thu gọn mặc định.
Future<EditWordResult?> showEditWordSheet({
  required BuildContext context,
  required String word,
  required String meaning,
  required String pronunciation,
  required String fullDetails,
  required String wordType,
  required String topicTag,
  bool showWordType = true,
  bool showDetails = true,
  bool requireMeaning = true,
}) {
  final wordCtl = TextEditingController(text: word);
  final meaningCtl = TextEditingController(text: meaning);
  final pronCtl = TextEditingController(text: pronunciation);
  final detailsCtl = TextEditingController(text: fullDetails);
  final topicCtl = TextEditingController(text: topicTag);
  final selectedTypes = <String>{
    ...wordType.split(',').map((t) => t.trim()).where(kWordTypeLabel.containsKey),
  };

  InputDecoration dense(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: const OutlineInputBorder(),
      );

  return showModalBottomSheet<EditWordResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: StatefulBuilder(
        builder: (ctx, setSheetState) {
          String? error;
          void save() {
            final w = wordCtl.text.trim();
            final m = meaningCtl.text.trim();
            final err = w.isEmpty
                ? 'Vui lòng nhập từ'
                : (requireMeaning && m.isEmpty ? 'Vui lòng nhập nghĩa' : null);
            if (err != null) {
              setSheetState(() => error = err);
              return;
            }
            Navigator.pop(
              ctx,
              EditWordResult(
                word: w,
                meaning: m,
                pronunciation: pronCtl.text.trim(),
                fullDetails: detailsCtl.text.trim(),
                wordType: selectedTypes.toList().join(','),
                topicTag: topicCtl.text.trim(),
              ),
            );
          }

          final theme = Theme.of(ctx);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Chỉnh sửa từ',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: wordCtl,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: dense('Từ', 'Nhập từ'),
                    onSubmitted: (_) => save(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: meaningCtl,
                    textInputAction: TextInputAction.next,
                    decoration: dense('Nghĩa', 'Nhập nghĩa'),
                    onSubmitted: (_) => save(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: pronCtl,
                          textInputAction: TextInputAction.next,
                          decoration: dense('Phát âm', 'Tùy chọn'),
                          onSubmitted: (_) => save(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: topicCtl,
                          textInputAction: TextInputAction.done,
                          decoration: dense('Nhãn chủ đề', 'vd: gym'),
                          onSubmitted: (_) => save(),
                        ),
                      ),
                    ],
                  ),
                  if (showWordType) ...[
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: kWordTypeKeys.map((key) {
                          final config = wordTypeConfig(key, ctx);
                          final color = config['color'] as Color;
                          final isSelected = selectedTypes.contains(key);
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () => setSheetState(() {
                                isSelected ? selectedTypes.remove(key) : selectedTypes.add(key);
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? color.withAlpha(40) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? color.withAlpha(180) : color.withAlpha(60),
                                  ),
                                ),
                                child: Text(
                                  config['shortLabel'] as String,
                                  style: TextStyle(
                                    fontFamily: 'Be Vietnam Pro',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  if (showDetails)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        'Chi tiết (tùy chọn)',
                        style: TextStyle(
                          fontFamily: 'Be Vietnam Pro',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      children: [
                        TextField(
                          controller: detailsCtl,
                          maxLines: 3,
                          minLines: 1,
                          decoration: dense('Chi tiết', 'Ví dụ, ghi chú...'),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  if (error != null) ...[
                    const SizedBox(height: 6),
                    Text(error!, style: TextStyle(fontSize: 12, color: theme.colorScheme.error)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Hủy'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(onPressed: save, child: const Text('Lưu')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  ).whenComplete(() {
    wordCtl.dispose();
    meaningCtl.dispose();
    pronCtl.dispose();
    detailsCtl.dispose();
    topicCtl.dispose();
  });
}
