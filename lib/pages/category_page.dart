import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/word_type_utils.dart';
import '../widgets/mastery_badge.dart';
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
  final Set<int> _flippedWords = {};
  List<Map<String, dynamic>> _words = [];
  bool _isLoading = true;
  bool _isAdding = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredWords {
    if (_searchQuery.isEmpty) return _words;
    return _words.where((w) =>
      (w['word'] as String? ?? '').toLowerCase().contains(_searchQuery) ||
      (w['meaning'] as String? ?? '').toLowerCase().contains(_searchQuery)
    ).toList();
  }

  Future<void> _loadWords() async {
    try {
      final words = await _db.getWordsByCategory(widget.userId, widget.category);
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

  Future<void> _addWord() async {
    if (_isAdding) return;
    final wordCtl = TextEditingController();
    final meaningCtl = TextEditingController();
    final pronCtl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Them tu moi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: wordCtl, autofocus: true, decoration: const InputDecoration(labelText: 'Tu', hintText: 'hello')),
              const SizedBox(height: 8),
              TextField(controller: meaningCtl, decoration: const InputDecoration(labelText: 'Nghia', hintText: 'xin chao')),
              const SizedBox(height: 8),
              TextField(controller: pronCtl, decoration: const InputDecoration(labelText: 'Phat am', hintText: '/həˈloʊ/')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huy')),
          FilledButton(onPressed: () {
            if (wordCtl.text.trim().isNotEmpty && meaningCtl.text.trim().isNotEmpty) Navigator.pop(ctx, true);
          }, child: const Text('Luu')),
        ],
      ),
    );

    if (saved != true) return;
    setState(() => _isAdding = true);
    try {
      await _db.addWordToCategory(
        widget.userId, widget.category,
        wordCtl.text.trim(), pronCtl.text.trim(), meaningCtl.text.trim(),
        wordType: widget.category,
      );
      await _loadWords();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Da them!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Loi: $e')));
    } finally {
      setState(() => _isAdding = false);
    }
  }

  Future<void> _editWord(Map<String, dynamic> word) async {
    final wordCtl = TextEditingController(text: word['word'] ?? '');
    final meaningCtl = TextEditingController(text: word['meaning'] ?? '');
    final pronCtl = TextEditingController(text: word['pronunciation'] ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sua tu'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: wordCtl, autofocus: true, decoration: const InputDecoration(labelText: 'Tu')),
              const SizedBox(height: 8),
              TextField(controller: meaningCtl, decoration: const InputDecoration(labelText: 'Nghia')),
              const SizedBox(height: 8),
              TextField(controller: pronCtl, decoration: const InputDecoration(labelText: 'Phat am')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huy')),
          FilledButton(onPressed: () {
            if (wordCtl.text.trim().isNotEmpty && meaningCtl.text.trim().isNotEmpty) Navigator.pop(ctx, true);
          }, child: const Text('Luu')),
        ],
      ),
    );

    if (saved != true) return;
    try {
      await _db.updateVocabularyWord(
        wordId: word['id'] as int,
        word: wordCtl.text.trim(),
        meaning: meaningCtl.text.trim(),
        pronunciation: pronCtl.text.trim(),
        wordType: (word['word_type'] as String?)?.trim() ?? widget.category,
      );
      await _loadWords();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Da sua!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Loi: $e')));
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Da xoa!')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Loi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.lingoColors;
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
            backgroundColor: catColor,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [catColor, catColor.withAlpha(200)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
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
                          decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(8)),
                          child: const Text('Chu de tu vung', style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(config['icon'] as IconData, color: Colors.white, size: 28),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_categoryLabel, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4, height: 1.2)),
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
                                  decoration: BoxDecoration(color: colors.reviewBannerDue[0].withAlpha(180), borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.bolt_rounded, color: Colors.white, size: 14),
                                      const SizedBox(width: 4),
                                      Text('$_dueCount can on tap', style: const TextStyle(fontFamily: 'Be Vietnam Pro', color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
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
                                decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(20)),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text('Luyen tap', style: TextStyle(fontFamily: 'Be Vietnam Pro', color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
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
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: catColor.withAlpha(80), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: FloatingActionButton(
          onPressed: _isAdding ? null : _addWord,
          backgroundColor: catColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: _isAdding
              ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: theme.colorScheme.onPrimary, strokeWidth: 2.5))
              : Icon(Icons.add_rounded, color: theme.colorScheme.onPrimary, size: 28),
        ),
      ),
    );
  }

  Widget _buildStatChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontFamily: 'Be Vietnam Pro', color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildWordCard({required Map<String, dynamic> word, required int index, required ThemeData theme, required Color catColor}) {
    final wordText = word['word'] as String? ?? '';
    final meaning = word['meaning'] as String? ?? '';
    final pronunciation = word['pronunciation'] as String? ?? '';
    final mastery = word['mastery_level'] as int? ?? 0;
    final isDifficult = word['is_difficult'] as bool? ?? false;
    final wordId = word['id'] as int;
    final isFlipped = _flippedWords.contains(wordId);

    return GestureDetector(
      onTap: () {
        if (isFlipped) {
          _flippedWords.remove(wordId);
        } else {
          _flippedWords.add(wordId);
        }
        setState(() {});
      },
      onLongPress: () => _editWord(word),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              child: Text('${index + 1}', textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, fontWeight: FontWeight.w700, color: catColor.withAlpha(150))),
            ),
            Container(width: 1, height: 36, color: theme.colorScheme.outlineVariant.withAlpha(80)),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: isFlipped
                    ? _buildWordCardBack(
                        key: ValueKey('back-$wordId'),
                        wordText: wordText,
                        meaning: meaning,
                        pronunciation: pronunciation,
                        mastery: mastery,
                        isDifficult: isDifficult,
                        wordId: wordId,
                        catColor: catColor,
                        theme: theme,
                      )
                    : _buildWordCardFront(
                        key: ValueKey('front-$wordId'),
                        wordText: wordText,
                        meaning: meaning,
                        pronunciation: pronunciation,
                        mastery: mastery,
                        isDifficult: isDifficult,
                        catColor: catColor,
                        theme: theme,
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: catColor.withAlpha(isFlipped ? 25 : 10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.flip_rounded,
                color: catColor.withAlpha(isFlipped ? 180 : 100),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordCardFront({
    required Key key,
    required String wordText,
    required String meaning,
    required String pronunciation,
    required int mastery,
    required bool isDifficult,
    required Color catColor,
    required ThemeData theme,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(wordText, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface, letterSpacing: -0.1)),
            ),
            if (isDifficult)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.whatshot_rounded, size: 16, color: Colors.orange),
              ),
            const SizedBox(width: 6),
            MasteryBadge(level: mastery),
          ],
        ),
        const SizedBox(height: 2),
        Text(meaning, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
        if (pronunciation.isNotEmpty)
          Text(pronunciation, style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 11, color: theme.colorScheme.onSurfaceVariant.withAlpha(150))),
      ],
    );
  }

  Widget _buildWordCardBack({
    required Key key,
    required String wordText,
    required String meaning,
    required String pronunciation,
    required int mastery,
    required bool isDifficult,
    required int wordId,
    required Color catColor,
    required ThemeData theme,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nghia:', style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 11, fontWeight: FontWeight.w600, color: catColor)),
        const SizedBox(height: 2),
        Text(meaning, style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
        if (pronunciation.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(pronunciation, style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 12, fontStyle: FontStyle.italic, color: theme.colorScheme.onSurfaceVariant.withAlpha(160))),
        ],
      ],
    );
  }
}
