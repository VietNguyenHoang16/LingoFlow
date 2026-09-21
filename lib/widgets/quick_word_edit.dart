import 'package:flutter/material.dart';

/// Kết quả trả về từ [showQuickWordEdit]. null = người dùng hủy / không đổi.
class WordEditResult {
  final String word;
  final String meaning;

  const WordEditResult({required this.word, required this.meaning});
}

/// Dialog sửa nhanh Từ + Nghĩa dùng cho màn Ôn tập (ở đó Nghĩa chính là câu hỏi
/// hiển thị trên thẻ nên bắt buộc phải có). Các field còn lại (phát âm, chi
/// tiết, loại từ) được lấy tự động từ từ điển sau khi lưu.
Future<WordEditResult?> showQuickWordEdit({
  required BuildContext context,
  required String word,
  required String meaning,
}) {
  return showDialog<WordEditResult>(
    context: context,
    builder: (ctx) => _QuickWordDialog(word: word, meaning: meaning),
  );
}

class _QuickWordDialog extends StatefulWidget {
  final String word;
  final String meaning;

  const _QuickWordDialog({required this.word, required this.meaning});

  @override
  State<_QuickWordDialog> createState() => _QuickWordDialogState();
}

class _QuickWordDialogState extends State<_QuickWordDialog> {
  late final TextEditingController wordCtl =
      TextEditingController(text: widget.word);
  late final TextEditingController meaningCtl =
      TextEditingController(text: widget.meaning);
  String? wordError;
  String? meaningError;

  @override
  void dispose() {
    wordCtl.dispose();
    meaningCtl.dispose();
    super.dispose();
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    Navigator.pop(context);
  }

  void _save() {
    final nextWord = wordCtl.text.trim();
    final nextMeaning = meaningCtl.text.trim();
    if (nextWord.isEmpty || nextMeaning.isEmpty) {
      setState(() {
        wordError = nextWord.isEmpty ? 'Vui lòng nhập từ' : null;
        meaningError = nextMeaning.isEmpty ? 'Vui lòng nhập nghĩa' : null;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    if (nextWord == widget.word.trim() &&
        nextMeaning == widget.meaning.trim()) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(
      context,
      WordEditResult(word: nextWord, meaning: nextMeaning),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sửa từ & nghĩa'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: wordCtl,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Từ',
              hintText: 'Nhập từ',
              border: const OutlineInputBorder(),
              errorText: wordError,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: meaningCtl,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Nghĩa',
              hintText: 'Nhập nghĩa',
              border: const OutlineInputBorder(),
              errorText: meaningError,
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _cancel, child: const Text('Hủy')),
        FilledButton(onPressed: _save, child: const Text('Lưu')),
      ],
    );
  }
}
