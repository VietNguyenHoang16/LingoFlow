import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/word_change_bus.dart';
import 'edit_word_sheet.dart';
import 'word_type_badge.dart';

class SearchBottomSheet extends StatefulWidget {
  final int userId;

  const SearchBottomSheet({super.key, required this.userId});

  @override
  State<SearchBottomSheet> createState() => _SearchBottomSheetState();
}

class _SearchBottomSheetState extends State<SearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _allWords = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoadingIndex = false;
  bool _indexFailed = false;

  @override
  void initState() {
    super.initState();
    _loadIndex();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadIndex() async {
    setState(() {
      _isLoadingIndex = true;
      _indexFailed = false;
    });
    try {
      final words = await _db.wordIndex(widget.userId);
      if (!mounted) return;
      setState(() {
        _allWords = words;
        _isLoadingIndex = false;
      });
      _applyFilter(_searchController.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingIndex = false;
        _indexFailed = true;
      });
    }
  }

  void _onQueryChanged(String query) {
    setState(() {});
    _applyFilter(query);
  }

  void _applyFilter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _searchResults = [];
        return;
      }
      _searchResults = _allWords
          .where((w) =>
              (w['word'] as String? ?? '').toLowerCase().contains(q) ||
              (w['topic_tag'] as String? ?? '').toLowerCase().contains(q))
          .toList();
    });
  }

  Future<void> _editSearchResult(Map<String, dynamic> word) async {
    Map<String, dynamic>? details;
    try {
      details = await _db.getWordDetails(word['id'] as int);
    } catch (_) {
      details = null;
    }
    if (!mounted) return;
    if (details == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tải được chi tiết từ, thử lại sau')),
      );
      return;
    }

    final result = await showEditWordSheet(
      context: context,
      word: (word['word'] as String?)?.trim() ?? '',
      meaning: (word['meaning'] as String?)?.trim() ?? '',
      pronunciation: (word['pronunciation'] as String?)?.trim() ?? '',
      fullDetails: (details['full_details'] as String?)?.trim() ?? '',
      wordType: (word['word_type'] as String?)?.trim() ?? '',
      topicTag: (word['topic_tag'] as String?)?.trim() ?? '',
      commonSynonyms: (details['common_synonyms'] as String?)?.trim() ?? '',
    );
    if (result == null || !mounted) return;

    try {
      await _db.updateVocabularyWord(
        wordId: word['id'] as int,
        word: result.word,
        meaning: result.meaning,
        pronunciation: result.pronunciation,
        fullDetails: result.fullDetails,
        wordType: result.wordType,
        topicTag: result.topicTag,
        commonSynonyms: result.commonSynonyms,
      );

      word['word'] = result.word;
      word['meaning'] = result.meaning;
      word['word_type'] = result.wordType;
      word['topic_tag'] = result.topicTag;
      _applyFilter(_searchController.text);
      WordChangeBus().notifyChanged('edit-word');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã chỉnh sửa từ')),
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

  Future<void> _deleteSearchResult(Map<String, dynamic> word) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa từ?'),
        content: Text('Bạn có chắc chắn muốn xóa "${word['word']}" không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await _db.deleteVocabularyWord(word['id'] as int);

      setState(() {
        _searchResults.removeWhere((w) => w['id'] == word['id']);
        _allWords.removeWhere((w) => w['id'] == word['id']);
      });
      WordChangeBus().notifyChanged('delete-word');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa từ')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: _onQueryChanged,
                    style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 16, color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search words...',
                      prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.primary, size: 22),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurfaceVariant),
                              onPressed: () { _searchController.clear(); _onQueryChanged(''); },
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingIndex
                ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                : _indexFailed
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Không tải được danh sách từ',
                                style: TextStyle(fontFamily: 'Be Vietnam Pro', color: theme.colorScheme.onSurfaceVariant, fontSize: 15)),
                            const SizedBox(height: 8),
                            TextButton(onPressed: _loadIndex, child: const Text('Thử lại')),
                          ],
                        ),
                      )
                    : _searchResults.isEmpty && _searchController.text.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text('No word found', style: TextStyle(fontFamily: 'Be Vietnam Pro', color: theme.colorScheme.onSurfaceVariant, fontSize: 16)),
                          ],
                        ),
                      )
                    : _searchResults.isEmpty
                        ? Center(
                            child: Text('Type to search', style: TextStyle(fontFamily: 'Be Vietnam Pro', color: theme.colorScheme.onSurfaceVariant, fontSize: 15)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final word = _searchResults[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(word['word'] as String, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 17, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.edit_rounded, size: 20, color: theme.colorScheme.onSurface),
                                          onPressed: () => _editSearchResult(word),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_rounded, size: 20, color: Colors.red),
                                          onPressed: () => _deleteSearchResult(word),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(word['meaning'] as String, style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
                                    if ((word['word_type'] as String? ?? '').trim().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Builder(builder: (context) {
                                        final tokens = (word['word_type'] as String).split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                                        return Wrap(spacing: 4, runSpacing: 4, children: tokens.map((t) => WordTypeBadge(typeKey: t, compact: true)).toList());
                                      }),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.folder_outlined, size: 13, color: theme.colorScheme.onSurfaceVariant),
                                        const SizedBox(width: 5),
                                        Icon(Icons.label_outline, size: 13, color: theme.colorScheme.onSurfaceVariant),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text('${word['category'] ?? ''} / ${word['list_name'] ?? ''}',
                                            style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
                                            overflow: TextOverflow.ellipsis),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}