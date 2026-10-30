import 'dart:async';

import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/tts_settings_service.dart';
import '../services/word_change_bus.dart';
import '../widgets/word_type_utils.dart';
import '../widgets/edit_word_sheet.dart';
import '../widgets/flip_word_card.dart';
import '../widgets/save_feedback.dart';
import '../services/word_details_parser.dart';
import 'review_page.dart';
import 'practice_page.dart';

class CategoryPage extends StatefulWidget {
  final int userId;
  final String category;

  const CategoryPage({
    super.key,
    required this.userId,
    required this.category,
  });

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final DatabaseService _db = DatabaseService();
  final TtsSettingsService _ttsSettings = TtsSettingsService();
  final Set<int> _flippedWords = {};
  List<Map<String, dynamic>> _words = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _filterTopicTag;
  Timer? _searchDebounce;
  StreamSubscription<WordChangeEvent>? _wordChangeSub;

  String get _categoryLabel => kWordTypeLabel[widget.category] ?? widget.category;
  int get _wordCount => _words.length;
  int get _dueCount => _words.where((w) {
    final next = w['next_review_date'] as DateTime?;
    return next == null || next.isBefore(DateTime.now());
  }).length;

  @override
  void initState() {
    super.initState();
    _loadWords();
    _searchController.addListener(_onSearchChanged);
    _wordChangeSub =
        WordChangeBus().stream.listen((_) => _loadWords(background: true));
  }

  void _onSearchChanged() {
    // Debounce de khong rebuild ca trang moi ky tu.
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _wordChangeSub?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredWords {
    Iterable<Map<String, dynamic>> words = _words;
    if (_filterTopicTag != null) {
      words = words.where((w) =>
          (w['topic_tag'] as String? ?? '').trim() == _filterTopicTag);
    }
    if (_searchQuery.isEmpty) return words.toList();
    return words.where((w) =>
      (w['word'] as String? ?? '').toLowerCase().contains(_searchQuery) ||
      (w['meaning'] as String? ?? '').toLowerCase().contains(_searchQuery) ||
      (w['topic_tag'] as String? ?? '').toLowerCase().contains(_searchQuery)
    ).toList();
  }

  /// Các nhãn chủ đề distinct (sắp xếp A-Z).
  List<String> get _topicTagOptions {
    final tags = <String>{};
    for (final w in _words) {
      final tag = (w['topic_tag'] as String? ?? '').trim();
      if (tag.isNotEmpty) tags.add(tag);
    }
    final options = tags.toList()..sort();
    return options;
  }

  Future<void> _speak(String text) async {
    try {
      await _ttsSettings.speakWith(text);
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
  }

  Future<void> _loadWords({bool background = false}) async {
    if (!background && mounted) setState(() => _isLoading = true);
    try {
      final words = await _db.getWordsByCategory(widget.userId, widget.category);
      if (!mounted) return;
      setState(() {
        _words = words;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Loi: $e')));
      }
    }
  }

  Future<void> _editWord(Map<String, dynamic> word) async {
    final result = await showEditWordSheet(
      context: context,
      word: (word['word'] ?? '').toString(),
      meaning: (word['meaning'] ?? '').toString(),
      pronunciation: (word['pronunciation'] ?? '').toString(),
      fullDetails: (word['full_details'] ?? '').toString(),
      wordType: (word['word_type'] ?? '').toString(),
      topicTag: (word['topic_tag'] ?? '').toString(),
      commonSynonyms: (word['common_synonyms'] ?? '').toString(),
      showWordType: false,
      showDetails: false,
    );
    if (result == null || !mounted) return;

    final id = word['id'] as int;
    final previous = Map<String, dynamic>.from(word);
    // Optimistic update: vá tại chỗ, không giật trang.
    setState(() {
      word['word'] = result.word;
      word['meaning'] = result.meaning;
      word['pronunciation'] = result.pronunciation;
      word['topic_tag'] = result.topicTag;
    });
    try {
      final example = await runWithSaveFeedback<Map<String, String>?>(
        context: context,
        word: result.word,
        action: () => _db.updateVocabularyWord(
          wordId: id,
          word: result.word,
          meaning: result.meaning,
          pronunciation: result.pronunciation,
          wordType: (previous['word_type'] as String?)?.trim() ?? widget.category,
          topicTag: result.topicTag,
          commonSynonyms: result.commonSynonyms,
        ),
      );
      if (!mounted) return;
      if (example != null) {
        // Vá tại chỗ: không reload cả trang (reload làm màn hình nhảy).
        setState(() {
          word['example_sentence'] = example['sentence'] ?? '';
          word['example_translation'] = example['translation'] ?? '';
          word['example_target'] = example['target'] ?? '';
        });
      }
      WordChangeBus().notifyChanged('edit-word');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Da sua!')));
    } catch (e) {
      if (mounted) {
        setState(() {
          final i = _words.indexWhere((w) => w['id'] == id);
          if (i != -1) _words[i] = previous;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Loi: $e')));
      }
    }
  }

  Future<void> _deleteWord(int wordId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoa tu?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Xoa')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _db.deleteVocabularyWord(wordId);
        await _loadWords();
        WordChangeBus().notifyChanged('delete-word');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Da xoa!')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Loi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = wordTypeConfig(widget.category, context);
    final catColor = config['color'] as Color;
    final filtered = _filteredWords;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: theme.colorScheme.primary,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(color: theme.colorScheme.onPrimary.withAlpha(40), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onPrimary, size: 22),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  // Header emerald chu trang: an mau theo theme, khong con den/xam.
                  color: theme.colorScheme.primary,
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? theme.colorScheme.outlineVariant
                        : theme.colorScheme.primary,
                    width: 1,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: theme.colorScheme.onPrimary.withAlpha(30), borderRadius: BorderRadius.circular(8)),
                          child: Text('Chu de tu vung', style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onPrimary.withAlpha(190))),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(config['icon'] as IconData, color: theme.colorScheme.onPrimary, size: 28),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_categoryLabel, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 26, fontWeight: FontWeight.w800, color: theme.colorScheme.onPrimary, letterSpacing: -0.4, height: 1.2)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildStatChip('$_wordCount', 'tu vung'),
                            const SizedBox(width: 10),
                            if (_dueCount > 0)
                              GestureDetector(
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ReviewPage(
                                        userId: widget.userId,
                                        category: widget.category,
                                        listName: _categoryLabel,
                                      ),
                                    ),
                                  );
                                  if (result == true) _loadWords();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: theme.colorScheme.secondary, borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bolt_rounded, color: theme.colorScheme.onSecondary, size: 14),
                                      const SizedBox(width: 4),
                                      Text('$_dueCount can on tap', style: TextStyle(fontFamily: 'Be Vietnam Pro', color: theme.colorScheme.onSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PracticePage(
                                      userId: widget.userId,
                                      listName: _categoryLabel,
                                      category: widget.category,
                                      studyMode: true,
                                    ),
                                  ),
                                );
                                _loadWords();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: theme.colorScheme.onPrimary.withAlpha(40), borderRadius: BorderRadius.circular(20)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.play_arrow_rounded, color: theme.colorScheme.onPrimary, size: 14),
                                    const SizedBox(width: 4),
                                    Text('Luyen tap', style: TextStyle(fontFamily: 'Be Vietnam Pro', color: theme.colorScheme.onPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            sliver: SliverToBoxAdapter(
              child: TextField(
                controller: _searchController,
                style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 14, color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Tim trong chu de...',
                  prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          if (_topicTagOptions.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              sliver: SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTopicFilterChip(null, 'Tat ca'),
                      const SizedBox(width: 8),
                      ..._topicTagOptions.map((t) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildTopicFilterChip(t, t),
                          )),
                    ],
                  ),
                ),
              ),
            ),

          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 88, height: 88,
                        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(24)),
                        child: Icon(config['icon'] as IconData, size: 44, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      Text(_searchQuery.isNotEmpty ? 'Khong tim thay tu nao' : 'Chua co tu vung nao',
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 18, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
                      const SizedBox(height: 8),
                      Text(_searchQuery.isNotEmpty ? 'Thu lai voi tu khoa khac' : 'Nhan + de them tu dau tien',
                        style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final word = filtered[index];
                    return _buildWordCard(word: word, index: index, theme: theme, catColor: catColor);
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String value, String label) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: theme.colorScheme.onPrimary.withAlpha(30), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontFamily: 'Plus Jakarta Sans', color: theme.colorScheme.onPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontFamily: 'Be Vietnam Pro', color: theme.colorScheme.onPrimary.withAlpha(180), fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTopicFilterChip(String? tag, String label) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.tertiary;
    final isSelected = _filterTopicTag == tag;
    return GestureDetector(
      onTap: () => setState(() => _filterTopicTag = tag),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(35) : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color.withAlpha(160) : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sell_outlined, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Be Vietnam Pro',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWordOptions(Map<String, dynamic> word) {
    final theme = Theme.of(context);
    final wordText = (word['word'] ?? '').toString();
    final meaning = (word['meaning'] ?? '').toString();
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              wordText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (meaning.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                meaning,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Be Vietnam Pro',
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const Divider(),
            ListTile(
              leading: Icon(Icons.edit_rounded, color: theme.colorScheme.primary),
              title: const Text('Chinh sua',
                  style: TextStyle(fontFamily: 'Be Vietnam Pro', fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _editWord(word);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
              title: const Text('Xoa tu',
                  style: TextStyle(fontFamily: 'Be Vietnam Pro', fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteWord(word['id'] as int);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordCard({required Map<String, dynamic> word, required int index, required ThemeData theme, required Color catColor}) {
    final wordText = word['word'] as String? ?? '';
    final meaning = word['meaning'] as String? ?? '';
    final pronunciation = word['pronunciation'] as String? ?? '';
    final wordType = (word['word_type'] as String? ?? '').trim();
    final wordId = word['id'] as int;
    final isFlipped = _flippedWords.contains(wordId);

    final resolved = resolveExample(word);
    final exampleTarget = (word['example_target'] ?? '').toString();
    return FlipWordCard(
      key: ValueKey('flip-$wordId'),
      isFlipped: isFlipped,
      word: wordText,
      pronunciation: pronunciation,
      meaning: meaning,
      wordType: wordType,
      topicTag: (word['topic_tag'] as String?) ?? '',
      example: resolved['sentence'] ?? '',
      exampleTranslation: (resolved['translation'] ?? '').isEmpty
          ? null
          : resolved['translation'],
      exampleTarget: exampleTarget.isEmpty ? null : exampleTarget,
      commonSynonyms: (word['common_synonyms'] ?? '').toString(),
      accent: catColor,
      isDifficult: word['is_difficult'] == true,
      onTap: () {
        if (isFlipped) {
          _flippedWords.remove(wordId);
        } else {
          _flippedWords.add(wordId);
        }
        setState(() {});
      },
      onLongPress: () => _showWordOptions(word),
      onSpeak: () => _speak(wordText),
    );
  }

}
