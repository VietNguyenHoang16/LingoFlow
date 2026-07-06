import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/database_service.dart';
import '../services/tts_settings_service.dart';
import '../widgets/word_type_badge.dart';
import 'practice_page.dart';

class RecentPage extends StatefulWidget {
  final int userId;

  const RecentPage({super.key, required this.userId});

  @override
  State<RecentPage> createState() => _RecentPageState();
}

class _RecentPageState extends State<RecentPage> {
  final DatabaseService _db = DatabaseService();
  final FlutterTts _flutterTts = FlutterTts();
  final TtsSettingsService _ttsSettings = TtsSettingsService();
  final Set<int> _flippedWords = {};
  final Set<int> _selectedWords = {};

  List<Map<String, dynamic>> _words = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  String? _loadError;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _ttsSettings.applyTo(_flutterTts);
    _loadRecent();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
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

  Future<void> _speak(String text) async {
    try {
      await _flutterTts.stop();
      await _ttsSettings.applyTo(_flutterTts);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
  }

  Future<void> _loadRecent() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final words = await _db.getRecentWords(widget.userId, limit: 20);
      if (!mounted) return;
      setState(() {
        _words = words;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _deleteWord(int wordId, String wordText) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa từ này?'),
        content: Text('"$wordText" sẽ bị xóa khỏi danh sách của bạn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _db.deleteVocabularyWord(wordId);
      _flippedWords.remove(wordId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa "$wordText"')),
        );
      }
      await _loadRecent();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedWords.clear();
    });
  }

  void _toggleWordSelection(int wordId) {
    setState(() {
      if (_selectedWords.contains(wordId)) {
        _selectedWords.remove(wordId);
      } else {
        _selectedWords.add(wordId);
      }
    });
  }

  void _startPractice() {
    if (_selectedWords.isEmpty) return;
    final selected = _words.where((w) => _selectedWords.contains(w['id'] as int)).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PracticePage(
          userId: widget.userId,
          listName: 'Recent (${selected.length} từ)',
          preloadedWords: selected,
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isSelectionMode = false);
        _selectedWords.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadError != null)
              Expanded(child: _buildErrorState(theme, _loadError!))
            else
              Expanded(
                child: RefreshIndicator(
                  color: theme.colorScheme.primary,
                  onRefresh: _loadRecent,
                  child: _words.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildList(theme),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _isSelectionMode && _selectedWords.isNotEmpty
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(80)),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _startPractice,
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: Text(
                      'Luyện tập (${_selectedWords.length})',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary, theme.colorScheme.primaryContainer],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withAlpha(60),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(Icons.history_rounded, color: theme.colorScheme.onPrimary, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_isSelectionMode ? 'Chọn từ để luyện' : 'Recent', style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 22, fontWeight: FontWeight.w800,
                      letterSpacing: -0.5, color: theme.colorScheme.onSurface,
                    )),
                    Text(_isSelectionMode
                        ? 'Đã chọn ${_selectedWords.length} từ'
                        : '20 từ mới nhất', style: TextStyle(
                      fontFamily: 'Be Vietnam Pro',
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                  ],
                ),
              ),
              if (!_isSelectionMode && _words.isNotEmpty)
                GestureDetector(
                  onTap: _toggleSelectionMode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: theme.colorScheme.primary, size: 18),
                        const SizedBox(width: 4),
                        Text('Luyện tập', style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        )),
                      ],
                    ),
                  ),
                ),
              if (_isSelectionMode)
                GestureDetector(
                  onTap: _toggleSelectionMode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Hủy', style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: theme.colorScheme.error,
                    )),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            style: TextStyle(
              fontFamily: 'Be Vietnam Pro', fontSize: 14,
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Tìm trong danh sách...',
              prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurfaceVariant),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    final isNetwork = error.contains('ket noi') || error.contains('mang') ||
        error.contains('Connection') || error.contains('Socket') || error.contains('Timeout');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: (isNetwork ? theme.colorScheme.primaryContainer : theme.colorScheme.errorContainer).withAlpha(60),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                size: 40,
                color: isNetwork ? theme.colorScheme.primary : theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(isNetwork ? 'No connection' : 'Failed to load',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 18, fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              )),
            const SizedBox(height: 8),
            Text(isNetwork ? 'Check your connection and try again' : error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Be Vietnam Pro', fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant, height: 1.5,
              )),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _loadRecent,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 80),
      children: [
        Center(
          child: Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.history_toggle_off_rounded, size: 44, color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text('Chưa có từ nào',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 18, fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            )),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text('Nhấn + ở trang chính để import từ đầu tiên',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Be Vietnam Pro', fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant, height: 1.5,
            )),
        ),
      ],
    );
  }

  Widget _buildList(ThemeData theme) {
    final filtered = _filteredWords;
    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          Center(
            child: Text('Không tìm thấy từ nào',
              style: TextStyle(
                fontFamily: 'Be Vietnam Pro',
                color: theme.colorScheme.onSurfaceVariant, fontSize: 15,
              )),
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final word = filtered[index];
        return _buildWordCard(word: word, index: index, theme: theme);
      },
    );
  }

  Widget _buildWordCard({
    required Map<String, dynamic> word,
    required int index,
    required ThemeData theme,
  }) {
    final wordText = word['word'] as String? ?? '';
    final meaning = word['meaning'] as String? ?? '';
    final pronunciation = word['pronunciation'] as String? ?? '';
    final wordType = (word['word_type'] as String? ?? '').trim();
    final createdAt = word['created_at'] as DateTime?;
    final wordId = word['id'] as int;
    final isFlipped = _flippedWords.contains(wordId);
    final isSelected = _selectedWords.contains(wordId);

    if (_isSelectionMode) {
      return GestureDetector(
        onTap: () => _toggleWordSelection(wordId),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withAlpha(10)
                : theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withAlpha(120)
                  : theme.colorScheme.outlineVariant,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleWordSelection(wordId),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(wordText, style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans', fontSize: 17, fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    )),
                    if (meaning.isNotEmpty)
                      Text(meaning, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(
                        fontFamily: 'Be Vietnam Pro', fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _speak(wordText),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.volume_up_rounded, color: theme.colorScheme.primary, size: 20),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isFlipped) {
            _flippedWords.remove(wordId);
          } else {
            _flippedWords.add(wordId);
          }
        });
      },
      onLongPress: () => _deleteWord(wordId, wordText),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Text('${index + 1}', textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans', fontSize: 15, fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary.withAlpha(150),
                )),
            ),
            Container(
              width: 1, height: 48,
              color: theme.colorScheme.outlineVariant.withAlpha(80),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: isFlipped
                    ? _buildCardBack(
                        key: ValueKey('back-$wordId'),
                        meaning: meaning, pronunciation: pronunciation, theme: theme,
                      )
                    : _buildCardFront(
                        key: ValueKey('front-$wordId'),
                        wordText: wordText, wordType: wordType,
                        createdAt: createdAt, theme: theme,
                      ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _speak(wordText),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.volume_up_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFront({
    required Key key,
    required String wordText,
    required String wordType,
    required DateTime? createdAt,
    required ThemeData theme,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(wordText,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans', fontSize: 22, fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface, letterSpacing: -0.3,
          )),
        const SizedBox(height: 8),
        Row(
          children: [
            if (wordType.isNotEmpty) ...[
              WordTypeBadge(typeKey: wordType, compact: true),
              const SizedBox(width: 8),
            ],
            if (createdAt != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded, size: 14,
                    color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(_formatRelative(createdAt),
                    style: TextStyle(
                      fontFamily: 'Be Vietnam Pro', fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardBack({
    required Key key,
    required String meaning,
    required String pronunciation,
    required ThemeData theme,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nghĩa:',
          style: TextStyle(
            fontFamily: 'Be Vietnam Pro', fontSize: 14, fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          )),
        const SizedBox(height: 4),
        Text(meaning,
          style: TextStyle(
            fontFamily: 'Be Vietnam Pro', fontSize: 18, fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          )),
        if (pronunciation.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(pronunciation,
            style: TextStyle(
              fontFamily: 'Be Vietnam Pro', fontSize: 14, fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
            )),
        ],
      ],
    );
  }

  String _formatRelative(DateTime then) {
    final now = DateTime.now();
    final diff = now.difference(then);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[then.month - 1]} ${then.day}';
  }
}
