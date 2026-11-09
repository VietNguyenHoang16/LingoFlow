import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../services/word_change_bus.dart';

/// Sheet nhỏ chỉ để thêm/sửa Mẹo nhớ. Trả về chuỗi mới (rỗng = đã xoá),
/// null = người dùng huỷ.
Future<String?> showMnemonicEditor({
  required BuildContext context,
  required int wordId,
  required String word,
  required String pronunciation,
  required String meaning,
  required String mnemonic,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => _MnemonicEditorSheet(
      wordId: wordId,
      word: word,
      pronunciation: pronunciation,
      meaning: meaning,
      initialMnemonic: mnemonic,
    ),
  );
}

/// Mở editor từ một map từ đã có (dùng ở thẻ lật / ôn tập / luyện tập).
Future<String?> showMnemonicEditorForWord(
  BuildContext context,
  Map<String, dynamic> word,
) {
  final rawId = word['id'];
  final wordId = rawId is int ? rawId : int.tryParse('$rawId') ?? 0;
  if (wordId <= 0) return Future.value(null);
  return showMnemonicEditor(
    context: context,
    wordId: wordId,
    word: (word['word'] ?? '').toString(),
    pronunciation: (word['pronunciation'] ?? '').toString(),
    meaning: (word['meaning'] ?? '').toString(),
    mnemonic: (word['mnemonic'] ?? '').toString(),
  );
}

class _MnemonicEditorSheet extends StatefulWidget {
  final int wordId;
  final String word;
  final String pronunciation;
  final String meaning;
  final String initialMnemonic;

  const _MnemonicEditorSheet({
    required this.wordId,
    required this.word,
    required this.pronunciation,
    required this.meaning,
    required this.initialMnemonic,
  });

  @override
  State<_MnemonicEditorSheet> createState() => _MnemonicEditorSheetState();
}

class _MnemonicEditorSheetState extends State<_MnemonicEditorSheet> {
  final DatabaseService _db = DatabaseService();
  late final TextEditingController _controller;
  bool _isGenerating = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialMnemonic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  Future<void> _generate() async {
    setState(() {
      _isGenerating = true;
      _error = null;
    });
    try {
      final mnemonic = await _db.generateWordMnemonic(widget.wordId);
      if (!mounted) return;
      setState(() {
        _controller.text = mnemonic;
        _isGenerating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _error = _cleanError(error);
      });
    }
  }

  Future<void> _save() async {
    final mnemonic = _controller.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await _db.updateWordMnemonic(widget.wordId, mnemonic: mnemonic);
      WordChangeBus().notifyChanged('mnemonic');
      if (!mounted) return;
      Navigator.pop(context, mnemonic);
      messenger.showSnackBar(
        SnackBar(
          content: Text(mnemonic.isEmpty ? 'Đã xoá mẹo nhớ.' : 'Đã lưu mẹo nhớ!'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = _cleanError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _isGenerating || _isSaving;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Icon(
                Icons.lightbulb_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mẹo nhớ cho "${widget.word}"',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Đóng',
              ),
            ],
          ),
          if (widget.pronunciation.isNotEmpty || widget.meaning.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              [
                if (widget.pronunciation.isNotEmpty)
                  '/${widget.pronunciation}/',
                if (widget.meaning.isNotEmpty) widget.meaning,
              ].join(' · '),
              style: TextStyle(
                fontFamily: 'Be Vietnam Pro',
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 8,
            minLines: 4,
            maxLength: 1200,
            enabled: !busy,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Mẹo nhớ',
              hintText:
                  'immune ← Latin immunis "được miễn nghĩa vụ": cả xóm cúm, riêng bà Lan vẫn bán rau vì cơ thể đã được miễn.',
              helperText: 'Để trống rồi Lưu để xoá mẹo nhớ.',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: busy ? null : _generate,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(_isGenerating ? 'Đang tạo...' : 'AI gợi ý mẹo nhớ'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(
                fontFamily: 'Be Vietnam Pro',
                fontSize: 13,
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Huỷ'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: busy ? null : _save,
                child: Text(_isSaving ? 'Đang lưu...' : 'Lưu'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
