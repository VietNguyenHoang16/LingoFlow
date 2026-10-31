import 'dart:async';

import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/tts_settings_service.dart';
import '../services/word_change_bus.dart';
import '../widgets/edit_word_sheet.dart';
import '../widgets/bulk_import_dialog.dart';
import '../widgets/flip_word_card.dart';
import '../widgets/word_type_badge.dart';
import '../widgets/save_feedback.dart';
import '../services/word_details_parser.dart';
import '../services/word_enrichment_service.dart';
import 'practice_page.dart';
import 'passive_review_page.dart';
import 'profile_page.dart';
import 'review_page.dart';

class RecentPage extends StatefulWidget {
  final int userId;

  const RecentPage({super.key, required this.userId});

  @override
  State<RecentPage> createState() => _RecentPageState();
}

class _RecentPageState extends State<RecentPage> {
  final DatabaseService _db = DatabaseService();
  final TtsSettingsService _ttsSettings = TtsSettingsService();
  final WordEnrichmentService _enrichment = WordEnrichmentService();
  final Set<int> _flippedWords = {};
  final Set<int> _selectedWords = {};
  StreamSubscription<WordChangeEvent>? _wordChangeSub;

  List<Map<String, dynamic>> _words = [];
  /// Tab đang xem: 'active' (Học ngay) hoặc 'passive' (Nên biết).
  String _mode = 'active';
  // Kết quả tìm trên toàn bộ từ đã lưu (server), tách khỏi 20 từ gần nhất.
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;
  int _searchSeq = 0;
  Map<String, dynamic> _reviewStats = const {};
  bool _isLoading = true;
  bool _isSelectionMode = false;
  /// Mốc chọn khoảng: chạm từ đầu, rồi chạm từ cuối -> chọn cả khoảng ở giữa.
  int? _selectionAnchor;
  String? _loadError;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadRecent();
    _loadReviewStats();
    _searchController.addListener(_onSearchChanged);
    // Them/sua/xoa tu o trang khac -> tai lai nen, khong can doi tab.
    _wordChangeSub = WordChangeBus().stream.listen((_) {
      _refreshActiveList();
      _loadReviewStats();
    });
  }

  void _onSearchChanged() {
    // Debounce để không gọi server mỗi ký tự.
    _searchDebounce?.cancel();
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _searchSeq++;
      setState(() {
        _searchQuery = '';
        _searchResults = [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }
    // Mở panel kết quả ngay khi gõ (danh sách bên dưới không đổi), xoá kết quả
    // cũ để không hiện nhầm kết quả của từ khoá trước.
    _searchSeq++;
    setState(() {
      _searchQuery = query;
      _searchResults = [];
      _isSearching = true;
      _searchError = null;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _runSearch(query);
    });
  }

  /// Tìm trên toàn bộ từ đã lưu (word / nghĩa / nhãn chủ đề) thay vì chỉ lọc
  /// trong 20 từ gần nhất đang hiện ở danh sách.
  Future<void> _runSearch(String query) async {
    final seq = ++_searchSeq;
    setState(() {
      _searchQuery = query;
      _isSearching = true;
      _searchError = null;
    });
    try {
      final results = await _db.searchWord(widget.userId, query);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _isSearching = false;
        _searchError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Đang tìm kiếm -> kết quả toàn bộ từ; ngược lại danh sách 20 từ gần nhất.
  Future<void> _refreshActiveList() async {
    if (_searchQuery.isEmpty) {
      await _loadRecent(background: true);
    } else {
      await _runSearch(_searchQuery);
    }
  }

  @override
  void dispose() {
    _wordChangeSub?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Danh sách từ hiện tại LUÔN giữ nguyên — kết quả tìm kiếm hiển thị ở panel
  /// riêng ngay dưới ô tìm kiếm, không thay thế danh sách này. Nhờ vậy người
  /// dùng vừa thấy kết quả vừa thấy danh sách (và giữ nguyên vị trí cuộn) để
  /// đối chiếu xem từ đã tồn tại chưa.
  List<Map<String, dynamic>> get _visibleWords => _words;

  Future<void> _speak(String text) async {
    try {
      await _ttsSettings.speakWith(text);
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
  }

  Future<void> _loadRecent({bool background = false}) async {
    if (!background) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final words = await _db.getRecentWords(widget.userId, limit: 50, mode: _mode);
      if (!mounted) return;
      setState(() {
        _words = words;
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadReviewStats() async {
    try {
      final data = await _db.getDashboardStats(widget.userId);
      if (!mounted) return;
      setState(() => _reviewStats = data.reviewStats);
    } catch (e) {
      debugPrint('Review stats load failed: $e');
    }
  }

  int get _dueWords => (_reviewStats['dueToday'] as int?) ?? 0;
  int get _dueGrammar => (_reviewStats['grammarDue'] as int?) ?? 0;
  /// Số từ "Nên biết" đến hạn ôn nhẹ.
  int get _passiveDue => (_reviewStats['passiveDue'] as int?) ?? 0;

  Future<void> _openReview({bool grammar = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewPage(userId: widget.userId, grammarReview: grammar),
      ),
    );
    if (!mounted) return;
    await _loadRecent(background: true);
    await _loadReviewStats();
  }

  /// Đổi tab Học ngay / Nên biết.
  void _switchMode(String mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _words = [];
      _isLoading = true;
      _loadError = null;
      _isSelectionMode = false;
      _selectedWords.clear();
      _selectionAnchor = null;
    });
    _loadRecent();
  }

  /// Mở phiên ôn nhẹ cho từ Nên biết (4 đáp án, không gõ).
  Future<void> _openPassiveReview() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PassiveReviewPage(userId: widget.userId),
      ),
    );
    if (!mounted) return;
    await _loadRecent(background: true);
    await _loadReviewStats();
  }

  /// Đổi loại 1 từ: Học ngay <-> Nên biết (server reset lịch ôn theo loại).
  Future<void> _toggleWordMode(Map<String, dynamic> word) async {
    final id = word['id'] as int;
    final current = (word['learning_mode'] ?? 'active').toString();
    final next = current == 'passive' ? 'active' : 'passive';
    try {
      await _db.setWordLearningMode(id, next);
      if (!mounted) return;
      setState(() {
        final idx = _words.indexWhere((w) => w['id'] == id);
        if (idx != -1) {
          _words[idx] = {..._words[idx], 'learning_mode': next};
        }
        final sidx = _searchResults.indexWhere((w) => w['id'] == id);
        if (sidx != -1) {
          _searchResults[sidx] = {..._searchResults[sidx], 'learning_mode': next};
        }
      });
      await _loadReviewStats();
      await _loadRecent(background: true);
      WordChangeBus().notifyChanged('word-mode');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            next == 'passive'
                ? 'Đã chuyển "${(word['word'] ?? '').toString()}" sang Nên biết'
                : 'Đã chuyển "${(word['word'] ?? '').toString()}" sang Học ngay',
          )),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfilePage(userId: widget.userId)),
    );
    if (!mounted) return;
    await _loadReviewStats();
  }

  Future<void> _bulkImport() async {
    final inserted = await BulkImportDialog.show(
      context,
      userId: widget.userId,
    );
    if (inserted > 0 && mounted) {
      await _loadRecent();
      WordChangeBus().notifyChanged('bulk-import');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã thêm $inserted từ')),
        );
      }
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
      WordChangeBus().notifyChanged('delete-word');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa "$wordText"')),
        );
      }
      await _refreshActiveList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  void _showWordOptions(Map<String, dynamic> word) {
    final theme = Theme.of(context);
    final wordText = word['word'] as String? ?? '';
    final meaning = word['meaning'] as String? ?? '';
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
              leading: Icon(
                (word['learning_mode'] ?? 'active') == 'passive'
                    ? Icons.bolt_rounded
                    : Icons.visibility_outlined,
                color: (word['learning_mode'] ?? 'active') == 'passive'
                    ? theme.colorScheme.primary
                    : theme.colorScheme.tertiary,
              ),
              title: Text(
                (word['learning_mode'] ?? 'active') == 'passive'
                    ? 'Chuyển sang Học ngay'
                    : 'Chuyển sang Nên biết',
                style: const TextStyle(
                    fontFamily: 'Be Vietnam Pro', fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                (word['learning_mode'] ?? 'active') == 'passive'
                    ? 'Ôn bằng gõ từ, tính vào "cần ôn hôm nay"'
                    : 'Ôn nhẹ bằng 4 đáp án, không tính due',
                style: TextStyle(
                  fontFamily: 'Be Vietnam Pro',
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _toggleWordMode(word);
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_rounded, color: theme.colorScheme.primary),
              title: const Text('Chinh sua / them nhan',
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
                _deleteWord(word['id'] as int, wordText);
              },
            ),
          ],
        ),
      ),
    );
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
      allowEmptyMeaningOnWordChange: true,
    );
    if (result == null || !mounted) return;

    final id = word['id'] as int;
    final previous = Map<String, dynamic>.from(word);
    final wordChanged = result.word != (previous['word'] ?? '').toString();

    try {
      await runWithSaveFeedback<void>(
        context: context,
        word: result.word,
        action: () async {
          // Đổi Từ -> tự lấy phát âm / chi tiết từ từ điển, nghĩa + loại từ từ
          // AI (giống màn Review). Hai request chạy song song.
          WordEnrichment? enrichment;
          AiWordInfo? aiInfo;
          if (wordChanged) {
            final enrichmentFuture = _enrichment.fetch(result.word);
            final aiFuture = _enrichment.fetchAiInfo(result.word);
            enrichment = await enrichmentFuture;
            aiInfo = await aiFuture;
            if (!mounted) return;
          }

          final meaning = (aiInfo?.meaning.isNotEmpty ?? false)
              ? aiInfo!.meaning
              : result.meaning;
          if (meaning.isEmpty) {
            throw const SaveAborted(
              'Không lấy được nghĩa mới. Vui lòng nhập nghĩa.',
            );
          }

          final pronunciation = (enrichment?.pronunciation.isNotEmpty ?? false)
              ? enrichment!.pronunciation
              : result.pronunciation;
          final fullDetails = (enrichment?.fullDetails.isNotEmpty ?? false)
              ? enrichment!.fullDetails
              : result.fullDetails;
          final wordType = (aiInfo?.wordType.isNotEmpty ?? false)
              ? aiInfo!.wordType
              : ((enrichment?.wordType.isNotEmpty ?? false)
                  ? enrichment!.wordType
                  : (previous['word_type'] ?? '').toString());

          // Optimistic update: vá tại chỗ, không reload toàn trang nên không giật.
          setState(() {
            _patchWord(id, {
              ...previous,
              'word': result.word,
              'meaning': meaning,
              'pronunciation': pronunciation,
              'full_details': fullDetails,
              'word_type': wordType,
              'topic_tag': result.topicTag,
              'common_synonyms': result.commonSynonyms,
            });
          });
          _flippedWords.remove(id);
          await _db.updateVocabularyWord(
            wordId: id,
            word: result.word,
            meaning: meaning,
            pronunciation: pronunciation,
            fullDetails: fullDetails,
            wordType: wordType,
            topicTag: result.topicTag,
            commonSynonyms: result.commonSynonyms,
          );
          // Đồng bộ nền để khớp server (ví dụ mới), giữ nguyên vị trí cuộn.
          await _refreshActiveList();
        },
      );
      WordChangeBus().notifyChanged('edit-word');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wordChanged
                ? 'Đã sửa "${result.word}" (AI cập nhật nghĩa + loại từ)'
                : 'Đã sửa!',
          ),
        ),
      );
    } on SaveAborted catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      // Rollback khi lỗi mạng.
      if (mounted) {
        setState(() => _patchWord(id, previous));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Loi: $e')));
      }
    }
  }

  /// Cập nhật row theo id ở cả danh sách gần nhất và kết quả tìm kiếm.
  void _patchWord(int id, Map<String, dynamic> row) {
    final i = _words.indexWhere((w) => w['id'] == id);
    if (i != -1) _words[i] = row;
    final j = _searchResults.indexWhere((w) => w['id'] == id);
    if (j != -1) _searchResults[j] = row;
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectionAnchor = null;
      if (!_isSelectionMode) _selectedWords.clear();
    });
  }

  /// Ô checkbox: bật/tắt đúng một từ (không nối khoảng) để tinh chỉnh lẻ.
  void _toggleWordSelection(int wordId) {
    setState(() {
      if (_selectedWords.contains(wordId)) {
        _selectedWords.remove(wordId);
        if (_selectionAnchor == wordId) _selectionAnchor = null;
      } else {
        _selectedWords.add(wordId);
        _selectionAnchor = wordId;
      }
    });
  }

  /// Chạm thân thẻ: từ đầu tiên làm mốc, chạm từ khác chọn cả khoảng giữa hai từ.
  void _handleWordTap(int index) {
    final filtered = _visibleWords;
    if (index < 0 || index >= filtered.length) return;
    final wordId = filtered[index]['id'] as int;
    final anchorIndex = _selectionAnchor == null
        ? -1
        : filtered.indexWhere((w) => w['id'] == _selectionAnchor);

    setState(() {
      // Chạm từ đã chọn -> bỏ chọn nó và bắt đầu mốc mới.
      if (_selectedWords.contains(wordId)) {
        _selectedWords.remove(wordId);
        _selectionAnchor = null;
        return;
      }
      // Chưa có mốc (hoặc mốc không còn trong danh sách): chọn đúng từ này.
      if (anchorIndex == -1) {
        _selectedWords.add(wordId);
        _selectionAnchor = wordId;
        return;
      }
      // Chọn cả khoảng từ mốc tới từ vừa chạm.
      final from = anchorIndex < index ? anchorIndex : index;
      final to = anchorIndex < index ? index : anchorIndex;
      for (var i = from; i <= to; i++) {
        _selectedWords.add(filtered[i]['id'] as int);
      }
      _selectionAnchor = wordId;
    });
  }

  void _startPractice() {
    if (_selectedWords.isEmpty) return;
    final selected =
        _visibleWords.where((w) => _selectedWords.contains(w['id'] as int)).toList();
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
        setState(() {
          _isSelectionMode = false;
          _selectionAnchor = null;
        });
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
      bottomNavigationBar: _buildBottomBar(theme),
    );
  }

  /// Bottom bar: chon tu de luyen khi dang selection mode, con lai la CTA on tap
  /// luon hien so tu den han (thay cho tab Review cu).
  Widget _buildBottomBar(ThemeData theme) {
    if (_isSelectionMode && _selectedWords.isNotEmpty) {
      return SafeArea(
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
      );
    }

    final due = _dueWords;
    final grammarDue = _dueGrammar;
    final hasDue = due > 0;
    final compactCta = MediaQuery.sizeOf(context).width < 360;
    final ctaLabel = hasDue
        ? (compactCta ? 'Ôn tập' : 'Ôn tập hôm nay')
        : (compactCta ? 'Đã xong' : 'Hôm nay đã xong');

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(80)),
          ),
        ),
        child: Row(
          children: [
            // Nút ôn nhẹ cho từ Nên biết: tách riêng khỏi "ôn tập hôm nay".
            if (_passiveDue > 0) ...[
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _openPassiveReview,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    foregroundColor: theme.colorScheme.tertiary,
                    side: BorderSide(color: theme.colorScheme.tertiary.withAlpha(130)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Gặp lại nhẹ',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                      Text(
                        '$_passiveDue',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _openReview(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        hasDue ? theme.colorScheme.primary : theme.colorScheme.primaryContainer,
                    foregroundColor:
                        hasDue ? theme.colorScheme.onPrimary : theme.colorScheme.onPrimaryContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(hasDue ? Icons.play_arrow_rounded : Icons.check_rounded, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          ctaLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (hasDue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onPrimary.withAlpha(35),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$due từ',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (grammarDue > 0) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => _openReview(grammar: true),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Cấu trúc',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '$grammarDue',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    // Man hinh hep (<=360dp): Import chi con icon, tieu de nho lai de khong wrap.
    final compact = MediaQuery.sizeOf(context).width < 360;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSelectionMode ? 'Chọn từ để luyện' : 'Từ vựng',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: compact ? 20 : 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isSelectionMode
                          ? (_selectedWords.isEmpty
                              ? 'Chạm từ đầu, rồi chạm từ cuối để chọn cả khoảng'
                              : 'Đã chọn ${_selectedWords.length} từ · chạm từ khác để mở rộng')
                          : (_mode == 'passive'
                              ? '${_visibleWords.length} từ nên biết'
                              : '${_visibleWords.length} từ học ngay'),
                      style: TextStyle(
                        fontFamily: 'Be Vietnam Pro',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isSelectionMode) ...[
                GestureDetector(
                  onTap: _bulkImport,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, color: theme.colorScheme.onSurface, size: 16),
                        if (!compact) ...[
                          const SizedBox(width: 4),
                          Text(
                            'Import',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_words.isNotEmpty && _mode == 'active') ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Luyện tập',
                    child: GestureDetector(
                      onTap: _toggleSelectionMode,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.play_arrow_rounded, color: theme.colorScheme.onPrimary, size: 18),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Cài đặt',
                  child: GestureDetector(
                    onTap: _openSettings,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Icon(Icons.settings_outlined, color: theme.colorScheme.onSurfaceVariant, size: 18),
                    ),
                  ),
                ),
              ],
              if (_isSelectionMode)
                GestureDetector(
                  onTap: _toggleSelectionMode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
                    ),
                    child: Text(
                      'Hủy',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildModeTabs(theme),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            style: TextStyle(
              fontFamily: 'Be Vietnam Pro',
              fontSize: 14,
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Tìm từ đã lưu…',
              prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurfaceVariant, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
            ),
          ),
          // Panel kết quả nằm ngay dưới ô tìm kiếm; danh sách từ bên dưới giữ
          // nguyên (không lọc, không đổi vị trí cuộn) để đối chiếu cả 2 phần.
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _searchQuery.isEmpty
                ? const SizedBox(width: double.infinity)
                : _buildSearchPanel(theme),
          ),
        ],
      ),
    );
  }

  /// Hai tab lớn: Học ngay (active) / Nên biết (passive).
  Widget _buildModeTabs(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _modeTab(theme, 'Học ngay', 'active', Icons.bolt_rounded, _dueWords),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _modeTab(theme, 'Nên biết', 'passive', Icons.visibility_outlined, _passiveDue),
        ),
      ],
    );
  }

  Widget _modeTab(
    ThemeData theme,
    String label,
    String mode,
    IconData icon,
    int due,
  ) {
    final selected = _mode == mode;
    final color = mode == 'passive'
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    return GestureDetector(
      key: ValueKey('mode-tab-$mode'),
      onTap: () => _switchMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(22) : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color.withAlpha(150) : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? color : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Be Vietnam Pro',
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? color : theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (due > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withAlpha(35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$due',
                  style: TextStyle(
                    fontFamily: 'Be Vietnam Pro',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Panel kết quả tìm kiếm (giới hạn chiều cao, tự cuộn) — không thay thế
  /// danh sách từ hiện tại.
  Widget _buildSearchPanel(ThemeData theme) {
    final maxHeight =
        (MediaQuery.sizeOf(context).height * 0.38).clamp(150.0, 380.0);
    final showCount = !_isSearching && _searchError == null && _searchResults.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 2, 6),
            child: Row(
              children: [
                Icon(Icons.manage_search_rounded,
                    size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Kết quả cho “${_searchController.text.trim()}”',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Be Vietnam Pro',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (showCount)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(24),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_searchResults.length}',
                      style: TextStyle(
                        fontFamily: 'Be Vietnam Pro',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Xóa tìm kiếm',
                  onPressed: () => _searchController.clear(),
                  icon: Icon(Icons.close_rounded,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: _buildSearchPanelBody(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanelBody(ThemeData theme) {
    if (_searchError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _searchError!,
              style: TextStyle(
                fontFamily: 'Be Vietnam Pro',
                fontSize: 12,
                color: theme.colorScheme.error,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _runSearch(_searchQuery),
                child: const Text('Thử lại'),
              ),
            ),
          ],
        ),
      );
    }
    if (_isSearching && _searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Đang tìm trong toàn bộ từ đã lưu…',
              style: TextStyle(
                fontFamily: 'Be Vietnam Pro',
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.search_off_rounded,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chưa có từ này trong bộ từ của bạn',
                    style: TextStyle(
                      fontFamily: 'Be Vietnam Pro',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: FilledButton.icon(
                onPressed: _addSearchedWord,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Thêm từ'),
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      shrinkWrap: true,
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        indent: 14,
        endIndent: 14,
        color: theme.colorScheme.outlineVariant.withAlpha(120),
      ),
      itemBuilder: (ctx, i) {
        final word = _searchResults[i];
        return _SearchResultRow(
          key: ValueKey('search-result-${word['id']}'),
          word: (word['word'] ?? '').toString(),
          meaning: (word['meaning'] ?? '').toString(),
          pronunciation: (word['pronunciation'] ?? '').toString(),
          wordType: (word['word_type'] ?? '').toString(),
          learningMode: (word['learning_mode'] ?? 'active').toString(),
          onTap: () => _speak((word['word'] ?? '').toString()),
          onLongPress: () => _showWordOptions(word),
        );
      },
    );
  }

  /// Chưa có từ trong bộ từ: mở dialog import với từ đã điền sẵn + AI phân tích
  /// ngay để lấy nghĩa/loại từ, rồi thêm.
  Future<void> _addSearchedWord() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    final inserted = await BulkImportDialog.show(
      context,
      userId: widget.userId,
      initialText: query,
      autoAnalyze: true,
      closeOnSuccess: true,
    );
    if (!mounted || inserted <= 0) return;
    _searchController.clear();
    await _loadRecent();
    WordChangeBus().notifyChanged('add-word-from-search');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thêm $inserted từ')),
      );
    }
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
          child: Text(
            _mode == 'passive' ? 'Chưa có từ Nên biết' : 'Chưa có từ nào',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 18, fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            )),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _mode == 'passive'
                ? 'AI sẽ xếp từ vào đây khi phân tích/import nếu chỉ cần hiểu khi đọc'
                : 'Nhấn + ở trang chính để import từ đầu tiên',
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
    // Danh sách luôn là danh sách từ hiện tại; trạng thái tìm kiếm (đang tải /
    // lỗi / không thấy) đã chuyển lên panel dưới ô tìm kiếm.
    final filtered = _visibleWords;
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
      final timeAgo = createdAt == null ? null : _formatRelative(createdAt);
      final timeStyle = TextStyle(
        fontFamily: 'Be Vietnam Pro', fontSize: 11, fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurfaceVariant.withAlpha(170),
      );
      return GestureDetector(
        onTap: () => _handleWordTap(index),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(wordText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans', fontSize: 17, fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          )),
                        ),
                        if (meaning.isEmpty && timeAgo != null) ...[
                          const SizedBox(width: 6),
                          Text(timeAgo, style: timeStyle),
                        ],
                      ],
                    ),
                    if (meaning.isNotEmpty)
                      Row(
                        children: [
                          Expanded(
                            child: Text(meaning, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(
                              fontFamily: 'Be Vietnam Pro', fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
                          ),
                          if (timeAgo != null) ...[
                            const SizedBox(width: 6),
                            Text(timeAgo, style: timeStyle),
                          ],
                        ],
                      ),
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
      createdLabel: createdAt != null ? _formatRelative(createdAt) : null,
      example: resolved['sentence'] ?? '',
      exampleTranslation: (resolved['translation'] ?? '').isEmpty
          ? null
          : resolved['translation'],
      exampleTarget: exampleTarget.isEmpty ? null : exampleTarget,
      commonSynonyms: (word['common_synonyms'] ?? '').toString(),
      accent: theme.colorScheme.primary,
      isDifficult: word['is_difficult'] == true,
      learningMode: (word['learning_mode'] ?? 'active').toString(),
      onTap: () {
        setState(() {
          if (isFlipped) {
            _flippedWords.remove(wordId);
          } else {
            _flippedWords.add(wordId);
          }
        });
      },
      onLongPress: () {
        if (_isSelectionMode) return;
        _showWordOptions(word);
      },
      onSpeak: () => _speak(wordText),
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

/// Mot dong ket qua tim kiem trong panel duoi o tim kiem.
///
/// Muc dich chinh: cho biet tu DA TON TAI (chip "Da co") + nghia + loai tu de
/// doi chieu voi danh sach ben duoi, va phat am nhanh khi cham.
class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    super.key,
    required this.word,
    required this.meaning,
    required this.pronunciation,
    required this.wordType,
    this.learningMode = 'active',
    required this.onTap,
    required this.onLongPress,
  });

  final String word;
  final String meaning;
  final String pronunciation;
  final String wordType;
  final String learningMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = wordType.trim();
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        word,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (type.isNotEmpty)
                        WordTypeBadge(typeKey: type, compact: true),
                      Builder(builder: (context) {
                        final isPassive = learningMode == 'passive';
                        final color = isPassive
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.primary;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color.withAlpha(80)),
                          ),
                          child: Text(
                            isPassive ? 'Nên biết' : 'Học ngay',
                            style: TextStyle(
                              fontFamily: 'Be Vietnam Pro',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        );
                      }),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiary.withAlpha(24),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: theme.colorScheme.tertiary.withAlpha(90),
                          ),
                        ),
                        child: Text(
                          'Đã có',
                          style: TextStyle(
                            fontFamily: 'Be Vietnam Pro',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (pronunciation.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        '/${pronunciation.trim()}/',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Be Vietnam Pro',
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (meaning.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        meaning.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Be Vietnam Pro',
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Nghe phát âm',
              visualDensity: VisualDensity.compact,
              onPressed: onTap,
              icon: Icon(Icons.volume_up_rounded,
                  size: 18, color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
