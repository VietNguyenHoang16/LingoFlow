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
///
/// LƯU Ý: body là StatefulWidget riêng, KHÔNG dùng StatefulBuilder.
/// StatefulBuilder + autofocus TextField + wrapper (SafeArea/scroll/MediaQuery)
/// gây crash framework (`_dependents.isEmpty`) khi đóng sheet.
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
  // Controller do State của body sở hữu và dispose (KHÔNG dispose trong
  // whenComplete: route pop xong future hoàn thành ngay nhưng animation
  // thoát vẫn rebuild TextField -> crash addListener trên controller disposed).
  return showModalBottomSheet<EditWordResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _EditWordSheetBody(
        initialWord: word,
        initialMeaning: meaning,
        initialPronunciation: pronunciation,
        initialFullDetails: fullDetails,
        initialTopicTag: topicTag,
        initialWordType: wordType,
        showWordType: showWordType,
        showDetails: showDetails,
        requireMeaning: requireMeaning,
      ),
    ),
  );
}

class _EditWordSheetBody extends StatefulWidget {
  final String initialWord;
  final String initialMeaning;
  final String initialPronunciation;
  final String initialFullDetails;
  final String initialTopicTag;
  final String initialWordType;
  final bool showWordType;
  final bool showDetails;
  final bool requireMeaning;

  const _EditWordSheetBody({
    required this.initialWord,
    required this.initialMeaning,
    required this.initialPronunciation,
    required this.initialFullDetails,
    required this.initialTopicTag,
    required this.initialWordType,
    required this.showWordType,
    required this.showDetails,
    required this.requireMeaning,
  });

  @override
  State<_EditWordSheetBody> createState() => _EditWordSheetBodyState();
}

class _EditWordSheetBodyState extends State<_EditWordSheetBody> {
  late final TextEditingController wordCtl = TextEditingController(text: widget.initialWord);
  late final TextEditingController meaningCtl = TextEditingController(text: widget.initialMeaning);
  late final TextEditingController pronCtl = TextEditingController(text: widget.initialPronunciation);
  late final TextEditingController detailsCtl =
      TextEditingController(text: widget.initialFullDetails);
  late final TextEditingController topicCtl = TextEditingController(text: widget.initialTopicTag);
  late final Set<String> selectedTypes = {
    ...widget.initialWordType.split(',').map((t) => t.trim()).where(kWordTypeLabel.containsKey),
  };
  String? error;

  @override
  void dispose() {
    wordCtl.dispose();
    meaningCtl.dispose();
    pronCtl.dispose();
    detailsCtl.dispose();
    topicCtl.dispose();
    super.dispose();
  }

  InputDecoration _dense(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: const OutlineInputBorder(),
      );

  void _save() {
    final w = wordCtl.text.trim();
    final m = meaningCtl.text.trim();
    final err = w.isEmpty
        ? 'Vui lòng nhập từ'
        : (widget.requireMeaning && m.isEmpty ? 'Vui lòng nhập nghĩa' : null);
    if (err != null) {
      setState(() => error = err);
      return;
    }
    // Unfocus trước khi pop: tránh race focus-teardown khi route thoát
    // (gây crash framework `_dependents.isEmpty`).
    FocusScope.of(context).unfocus();
    Navigator.pop(
      context,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              decoration: _dense('Từ', 'Nhập từ'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: meaningCtl,
              textInputAction: TextInputAction.next,
              decoration: _dense('Nghĩa', 'Nhập nghĩa'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: pronCtl,
                    textInputAction: TextInputAction.next,
                    decoration: _dense('Phát âm', 'Tùy chọn'),
                    onSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: topicCtl,
                    textInputAction: TextInputAction.done,
                    decoration: _dense('Nhãn chủ đề', 'vd: gym'),
                    onSubmitted: (_) => _save(),
                  ),
                ),
              ],
            ),
            if (widget.showWordType) ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: kWordTypeKeys.map((key) {
                    final config = wordTypeConfig(key, context);
                    final color = config['color'] as Color;
                    final isSelected = selectedTypes.contains(key);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() {
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
            if (widget.showDetails)
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
                    decoration: _dense('Chi tiết', 'Ví dụ, ghi chú...'),
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
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    Navigator.pop(context);
                  },
                  child: const Text('Hủy'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(onPressed: _save, child: const Text('Lưu')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
