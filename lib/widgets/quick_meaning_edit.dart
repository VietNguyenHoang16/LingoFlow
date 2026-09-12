import 'package:flutter/material.dart';

/// Dialog sửa nghĩa nhanh dùng chung. null = hủy / không đổi.
Future<String?> showQuickMeaningEdit({
  required BuildContext context,
  required String word,
  required String meaning,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _QuickMeaningDialog(word: word, meaning: meaning),
  );
}

class _QuickMeaningDialog extends StatefulWidget {
  final String word;
  final String meaning;

  const _QuickMeaningDialog({required this.word, required this.meaning});

  @override
  State<_QuickMeaningDialog> createState() => _QuickMeaningDialogState();
}

class _QuickMeaningDialogState extends State<_QuickMeaningDialog> {
  late final TextEditingController ctl =
      TextEditingController(text: widget.meaning);
  String? error;

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    Navigator.pop(context);
  }

  void _save() {
    final trimmed = ctl.text.trim();
    if (trimmed.isEmpty) {
      setState(() => error = 'Vui lòng nhập nghĩa');
      return;
    }
    if (trimmed == widget.meaning.trim()) {
      FocusScope.of(context).unfocus();
      Navigator.pop(context);
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.pop(context, trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Sửa nghĩa nhanh "${widget.word}"'),
      content: TextField(
        controller: ctl,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: 'Nhập nghĩa',
          border: const OutlineInputBorder(),
          errorText: error,
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(onPressed: _cancel, child: const Text('Hủy')),
        FilledButton(onPressed: _save, child: const Text('Lưu')),
      ],
    );
  }
}
