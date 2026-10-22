import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/word_details_parser.dart';

/// Quản lý một câu ví dụ cho từ vựng: xem, nhờ AI gợi ý, sửa và lưu.
class ExampleManagerSheet extends StatefulWidget {
  final int wordId;
  final String word;
  final String fullDetails;
  final String meaning;
  final String pronunciation;
  final String wordType;
  final String topicTag;
  final String exampleSentence;
  final String exampleTranslation;

  const ExampleManagerSheet({
    super.key,
    required this.wordId,
    required this.word,
    required this.fullDetails,
    required this.meaning,
    required this.pronunciation,
    required this.wordType,
    required this.topicTag,
    this.exampleSentence = '',
    this.exampleTranslation = '',
  });

  static Future<bool?> show({
    required BuildContext context,
    required int wordId,
    required String word,
    required String fullDetails,
    required String meaning,
    required String pronunciation,
    required String wordType,
    required String topicTag,
    String exampleSentence = '',
    String exampleTranslation = '',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => ExampleManagerSheet(
        wordId: wordId,
        word: word,
        fullDetails: fullDetails,
        meaning: meaning,
        pronunciation: pronunciation,
        wordType: wordType,
        topicTag: topicTag,
        exampleSentence: exampleSentence,
        exampleTranslation: exampleTranslation,
      ),
    );
  }

  @override
  State<ExampleManagerSheet> createState() => _ExampleManagerSheetState();
}

class _ExampleManagerSheetState extends State<ExampleManagerSheet> {
  final DatabaseService _db = DatabaseService();
  late final TextEditingController _sentenceController;
  late final TextEditingController _translationController;
  bool _isGenerating = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final fallback = extractFirstExample(parseFullDetails(widget.fullDetails));
    _sentenceController = TextEditingController(
      text: widget.exampleSentence.isNotEmpty ? widget.exampleSentence : fallback,
    );
    _translationController =
        TextEditingController(text: widget.exampleTranslation);
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  Future<void> _generate() async {
    setState(() {
      _isGenerating = true;
      _error = null;
    });
    try {
      final example = await _db.generateWordExample(widget.wordId);
      if (!mounted) return;
      setState(() {
        _sentenceController.text = example['sentence'] ?? '';
        _translationController.text = example['translation'] ?? '';
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
    final sentence = _sentenceController.text.trim();
    final translation = _translationController.text.trim();
    if (sentence.isEmpty) {
      setState(() => _error = 'Nhập câu ví dụ tiếng Anh.');
      return;
    }
    if (translation.isEmpty) {
      setState(() => _error = 'Nhập bản dịch tiếng Việt.');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await _db.updateWordExample(
        widget.wordId,
        sentence: sentence,
        translation: translation,
        target: widget.word,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã lưu ví dụ!')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = _cleanError(error);
      });
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa ví dụ?'),
        content: Text('Xóa câu ví dụ của "${widget.word}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await _db.updateWordExample(
        widget.wordId,
        sentence: '',
        translation: '',
      );
      if (!mounted) return;
      setState(() {
        _sentenceController.clear();
        _translationController.clear();
        _isSaving = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã xóa ví dụ.')),
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
  void dispose() {
    _sentenceController.dispose();
    _translationController.dispose();
    super.dispose();
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
              Expanded(
                child: Text(
                  'Ví dụ cho "${widget.word}"',
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
          if (widget.meaning.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              widget.meaning,
              style: TextStyle(
                fontFamily: 'Be Vietnam Pro',
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _sentenceController,
            maxLines: 4,
            minLines: 2,
            enabled: !busy,
            decoration: InputDecoration(
              labelText: 'Câu ví dụ tiếng Anh',
              hintText: 'AI sẽ tự tạo một câu tự nhiên và dễ hiểu',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _translationController,
            maxLines: 3,
            minLines: 2,
            enabled: !busy,
            decoration: InputDecoration(
              labelText: 'Bản dịch tiếng Việt',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
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
              OutlinedButton.icon(
                onPressed: busy ? null : _generate,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(_isGenerating ? 'Đang tạo...' : 'AI gợi ý'),
              ),
              const Spacer(),
              TextButton(
                onPressed: busy ? null : _delete,
                child: Text(
                  'Xóa',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
              const SizedBox(width: 4),
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
