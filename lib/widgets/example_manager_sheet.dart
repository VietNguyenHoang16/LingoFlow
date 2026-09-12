import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../services/word_details_parser.dart';

/// Dialog quản lý ví dụ cho từ vựng.
/// Cho phép xem, sửa, xóa và thêm ví dụ.
class ExampleManagerSheet extends StatefulWidget {
  final int wordId;
  final String word;
  final String fullDetails;
  final String meaning;
  final String pronunciation;
  final String wordType;
  final String topicTag;

  const ExampleManagerSheet({
    super.key,
    required this.wordId,
    required this.word,
    required this.fullDetails,
    required this.meaning,
    required this.pronunciation,
    required this.wordType,
    required this.topicTag,
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
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ExampleManagerSheet(
          wordId: wordId,
          word: word,
          fullDetails: fullDetails,
          meaning: meaning,
          pronunciation: pronunciation,
          wordType: wordType,
          topicTag: topicTag,
        ),
      ),
    );
  }

  @override
  State<ExampleManagerSheet> createState() => _ExampleManagerSheetState();
}

class _ExampleManagerSheetState extends State<ExampleManagerSheet> {
  final DatabaseService _db = DatabaseService();
  late List<String> _examples;
  final TextEditingController _newExampleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _examples = extractAllExamples(widget.fullDetails);
  }

  Future<void> _saveChanges() async {
    // Rebuild fullDetails từ danh sách examples
    final updatedFullDetails = _examples.isEmpty
        ? widget.fullDetails
        : _rebuildFullDetailsWithExamples(widget.fullDetails, _examples);
    try {
      await _db.updateVocabularyWord(
        wordId: widget.wordId,
        word: widget.word,
        meaning: widget.meaning,
        pronunciation: widget.pronunciation,
        fullDetails: updatedFullDetails,
        wordType: widget.wordType,
        topicTag: widget.topicTag,
      );
      Navigator.pop(context, true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu ví dụ!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _deleteExample(int index) async {
    final example = _examples[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa ví dụ?'),
        content: Text('Bạn có chắc muốn xóa ví dụ "${example.substring(0, example.length > 50 ? 50 : example.length)}..." không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _examples.removeAt(index);
      });
    }
  }

  Future<void> _editExample(int index) async {
    final controller = TextEditingController(text: _examples[index]);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sửa ví dụ'),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            maxLines: 5,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Nhập ví dụ mới...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Lưu')),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _examples[index] = result;
      });
    }
  }

  void _addExample() {
    final text = _newExampleController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _examples.add(text);
      });
      _newExampleController.clear();
    }
  }

  /// Rebuild fullDetails chỉ với examples, giữ nguyên definition và cấu trúc
  String _rebuildFullDetailsWithExamples(String fullDetails, List<String> examples) {
    final parsed = parseFullDetails(fullDetails);
    if (parsed.isEmpty) return fullDetails;

    // Đặt lại examples trong definition đầu tiên
    final firstDefs = parsed.first['definitions'] as List<Map<String, dynamic>>;
    if (firstDefs.isNotEmpty) {
      firstDefs[0]['examples'] = List<String>.from(examples);
    }

    return rebuildFullDetails(parsed);
  }

  @override
  void dispose() {
    _newExampleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Grab handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              const SizedBox(width: 8),
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
              TextButton(
                onPressed: _examples.isEmpty ? null : _saveChanges,
                child: Text(
                  'Lưu',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    color: _examples.isEmpty
                        ? theme.colorScheme.onSurfaceVariant.withAlpha(120)
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Example list
        if (_examples.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              children: [
                Icon(Icons.book_rounded, size: 40, color: theme.colorScheme.onSurfaceVariant.withAlpha(80)),
                const SizedBox(height: 12),
                Text(
                  'Chưa có ví dụ nào',
                  style: TextStyle(
                    fontFamily: 'Be Vietnam Pro',
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              itemCount: _examples.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final example = _examples[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(100)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleChild(
                        color: theme.colorScheme.primary,
                        text: '${index + 1}',
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          example,
                          style: TextStyle(
                            fontFamily: 'Be Vietnam Pro',
                            fontSize: 14,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              onPressed: () => _editExample(index),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              color: Colors.blue,
                            ),
                          ),
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: IconButton(
                              icon: const Icon(Icons.delete_rounded, size: 18),
                              onPressed: () => _deleteExample(index),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        // Add example section
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newExampleController,
                  decoration: InputDecoration(
                    hintText: 'Thêm ví dụ mới...',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withAlpha(120)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  maxLines: 3,
                  minLines: 1,
                  onSubmitted: (_) => _addExample(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _addExample,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Icon(Icons.add_rounded, size: 24),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CircleChild extends StatelessWidget {
  final Color color;
  final String text;

  const CircleChild({super.key, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withAlpha(30),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}