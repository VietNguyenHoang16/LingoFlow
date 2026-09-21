import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../services/answer_comparison.dart';
import '../services/database_service.dart';
import '../services/review_word_utils.dart';
import '../widgets/answer_diff_text.dart';
import '../widgets/review_example_panel.dart';
import '../services/srs_service.dart';
import '../services/tts_settings_service.dart';
import '../services/word_enrichment_service.dart';
import '../widgets/quick_meaning_edit.dart';
import '../widgets/quick_word_edit.dart';
import '../theme/app_theme.dart';
import '../widgets/mastery_badge.dart';
import '../widgets/word_type_badge.dart';
import '../widgets/topic_tag_badge.dart';

/// Màu tô ký tự gõ sai trên nền gradient của thẻ đáp án (indigo khi gần đúng,
/// đỏ khi sai): amber sáng đủ tương phản cho cả hai nền.
const Color _answerMismatchColor = Color(0xFFFFD54F);

/// Hanh dong trong menu an cua the cau hoi (nhan giu the / Shift+F10).
enum _WordMenuAction { edit, delete }

class ReviewPage extends StatefulWidget {
  final int userId;
  final int? listId;
  final String? listName;
  final String? category;

  /// ON tap cau truc (grammar): nap cac tu co 'grammar' trong word_type
  /// (bao gom tu lai loai 'noun,grammar') thay vi danh sach SRS thong thuong.
  final bool grammarReview;

  const ReviewPage({
    super.key,
    required this.userId,
    this.listId,
    this.listName,
    this.category,
    this.grammarReview = false,
  });

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  final SrsService _srs = SrsService();
  final TtsSettingsService _ttsSettings = TtsSettingsService();
  final WordEnrichmentService _enrichment = WordEnrichmentService();

  final TextEditingController _answerController = TextEditingController();
  final FocusNode _answerFocusNode = FocusNode();
  final FocusNode _pageFocusNode = FocusNode();
  final GlobalKey _answerFieldKey = GlobalKey();
  final GlobalKey _questionCardKey = GlobalKey();
  final ScrollController _bodyScrollController = ScrollController();
  bool? _isAnswerCorrect;
  // Dấu từng ký tự của lần trả lời hiện tại để tô chỗ gõ thiếu / thừa / sai
  // (null = không tô gì, ví dụ chế độ grammar tự chấm).
  AnswerDiff? _answerDiff;
  // Safari iPad khong bao viewInsets.bottom (keyboard phu overlay) -> dung
  // focus de biet keyboard dang mo, thay vi chi dua vao viewInsets.
  bool _inputFocused = false;

  List<Map<String, dynamic>> _dueWords = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  bool _showAnswer = false;
  int _hintLevel = 0;
  bool _isCompleted = false;

  int _totalReviewed = 0;
  int _masteryUps = 0;
  final List<Map<String, dynamic>> _sessionResults = [];
  final List<Future<void>> _pendingUpdates = [];
  bool _isPopping = false;
  bool _wordOptionsOpen = false;
  /// Dang xoa tu hoac dang luu phan chinh sua -> chan pop / cham diem / thao tac
  /// trung de du lieu trong phien khong bi ghi de sai.
  bool _isWordBusy = false;

  Map<int, String> _calculatedIntervals = {};

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    // Phím Enter (grammar review) can phan hoi ca khi khong node nao focus,
    // nen dung handler toan cuc giong practice_page thay vi KeyboardListener.
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    _answerFocusNode.addListener(_handleAnswerFocusChange);
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _loadDueWords();
  }

  Future<void> _speak(String text) async {
    try {
      await _ttsSettings.speakWith(text);
    } catch (e) {
      debugPrint('Review TTS error: $e');
    }
  }

  Future<void> _flushUpdates() async {
    if (_pendingUpdates.isEmpty) return;
    await Future.wait(List<Future<void>>.from(_pendingUpdates));
  }

  /// Dam bao cac ghi SRS da luu xong truoc khi roi man hinh,
  /// tranh mat du lieu tien do neu app bi tat.
  /// Guard _isPopping: chan double-tap Done / Done + back cung luc gay
  /// double Navigator.pop trong luc Navigator dang locked (!vidu _debugLocked).
  Future<void> _popWithFlush([bool result = false]) async {
    if (_isPopping || _isWordBusy) return;
    _isPopping = true;
    try {
      await _flushUpdates();
    } catch (_) {}
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;
    navigator.pop(result);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    unawaited(_flushUpdates());
    _answerFocusNode.removeListener(_handleAnswerFocusChange);
    _answerController.dispose();
    _answerFocusNode.dispose();
    _pageFocusNode.dispose();
    _bodyScrollController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _loadDueWords() async {
    try {
      List<Map<String, dynamic>> words;
      if (widget.grammarReview) {
        words = await _db.getWordsDueForReviewGrammar(widget.userId);
      } else if (widget.category != null) {
        words = await _db.getWordsDueForReviewByCategory(widget.userId, widget.category!);
      } else if (widget.listId != null) {
        words = await _db.getWordsDueForReview(widget.listId!);
      } else {
        words = await _db.getAllWordsDueForReview(widget.userId);
      }
      words.shuffle();

      setState(() {
        // Chuan hoa kieu du lieu ngay tu dau - cac cast phia sau luon an toan.
        _dueWords = words.map(normalizeWord).toList();
        _currentIndex = 0;
        _isLoading = false;
      });
      _requestInputFocus();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _requestInputFocus({bool immediate = false}) {
    // Che do grammar khong co o nhap: khong focus keyboard, chi cuon the cau hoi
    // len dau vung nhin thay duoc.
    if (widget.grammarReview) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_showAnswer && !_isCompleted) _scrollQuestionIntoView();
      });
      return;
    }
    void focusAndReveal() {
      if (!mounted || _showAnswer || _isCompleted || _dueWords.isEmpty) return;
      // Safari: page node giu focus se chan answer node, phai nha truoc.
      if (_pageFocusNode.hasFocus) _pageFocusNode.unfocus();
      _answerFocusNode.requestFocus();
      _scrollAnswerIntoView();
    }

    if (immediate) {
      focusAndReveal();
    }

    // Chi 1 fallback postFrame de sua focus-state. Retry delay khong bao gio
    // goi duoc keyboard Safari (can gesture) nen bo, tranh nhieu.
    SchedulerBinding.instance.addPostFrameCallback((_) => focusAndReveal());
  }

  void _scrollAnswerIntoView() {
    final answerContext = _answerFieldKey.currentContext;
    if (answerContext == null) return;

    Scrollable.ensureVisible(
      answerContext,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: 0.7,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }

  void _scrollQuestionIntoView() {
    final questionContext = _questionCardKey.currentContext;
    if (questionContext == null) return;

    // Dua the cau hoi len dau vung nhin thay duoc, ke ca khi Safari khong
    // bao viewInsets (keyboard phu overlay phia duoi).
    Scrollable.ensureVisible(
      questionContext,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: 0.0,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  void _handleAnswerFocusChange() {
    final focused = _answerFocusNode.hasFocus;
    if (_inputFocused != focused) {
      setState(() => _inputFocused = focused);
    }
    if (!focused) return;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_answerFocusNode.hasFocus) return;
      _scrollQuestionIntoView();
      _scrollAnswerIntoView();
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _answerFocusNode.hasFocus) {
          _scrollQuestionIntoView();
        }
      });
    });
  }

  void _queueUpdate(int wordId, SrsResult result) {
    final future = _db
        .updateWordReview(
          wordId: wordId,
          reviewCount: result.newReviewCount,
          correctStreak: result.newCorrectStreak,
          easeFactor: result.newEaseFactor,
          intervalDays: result.newInterval,
          nextReviewDate: result.nextReviewDate,
          masteryLevel: result.newMasteryLevel,
          lapseCount: result.newLapseCount,
        )
        .catchError((e) {
          debugPrint('Failed to update word review: $e');
        });

    _pendingUpdates.add(future);
    future.whenComplete(() => _pendingUpdates.remove(future));
  }

  /// Tu hien tai - null neu index ngoai pham vi (khong bao gio RangeError).
  Map<String, dynamic>? get _currentWordSafe => wordAt(_dueWords, _currentIndex);

  /// Menu an cua the cau hoi (nhan giu the / Shift+F10): `Chinh sua tu`
  /// (sua Tu + Nghia, cac field khac lay tu dong tu tu dien) va `Xoa tu`.
  Future<void> _showWordOptions() async {
    final word = _currentWordSafe;
    if (word == null || _wordOptionsOpen || _isCompleted || _isPopping) return;
    _wordOptionsOpen = true;
    _answerFocusNode.unfocus();
    final wordId = word['id'] as int;
    final wordText = (word['word'] ?? '').toString();
    try {
      final action = await showModalBottomSheet<_WordMenuAction>(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.edit_rounded, color: Theme.of(ctx).colorScheme.primary),
                  title: const Text('Chỉnh sửa từ'),
                  onTap: () => Navigator.pop(ctx, _WordMenuAction.edit),
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
                  title: const Text('Xóa từ'),
                  onTap: () => Navigator.pop(ctx, _WordMenuAction.delete),
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted) return;
      if (action == _WordMenuAction.edit) {
        await _editCurrentWord(word);
        return;
      }
      if (action != _WordMenuAction.delete) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Xóa từ này?'),
          content: Text('"$wordText" sẽ bị xóa khỏi thư viện của bạn, không chỉ bỏ qua trong phiên ôn tập. Không thể hoàn tác.'),
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
      if (confirm != true || !mounted) return;
      setState(() => _isWordBusy = true);
      // Finish earlier Again writes before deleting the same database row.
      await _flushUpdates();
      if (!mounted) return;
      await _db.deleteVocabularyWord(wordId);
      if (!mounted) return;
      setState(() {
        final removedBefore = _dueWords.take(_currentIndex)
            .where((w) => w['id'] == wordId).length;
        _dueWords.removeWhere((w) => w['id'] == wordId);
        _currentIndex -= removedBefore;
        _isCompleted = _currentIndex >= _dueWords.length;
        _resetCardAnswerState();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xóa "$wordText"')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể xóa từ. Vui lòng thử lại.')),
        );
      }
    } finally {
      _wordOptionsOpen = false;
      if (mounted) {
        setState(() => _isWordBusy = false);
        if (!_isCompleted) {
          if (_showAnswer) {
            _pageFocusNode.requestFocus();
          } else {
            _requestInputFocus();
          }
        }
      }
    }
  }

  /// Sua Tu + Nghia ngay trong phien on tap.
  /// Doi chu cua Tu -> tu dong lay phat am / chi tiet / loai tu tu tu dien de
  /// nguoi dung khong phai nhap tay. Loi mang -> van luu Tu + Nghia.
  Future<void> _editCurrentWord(Map<String, dynamic> word) async {
    final wordId = word['id'] as int;
    final previous = Map<String, dynamic>.from(word);
    final result = await showQuickWordEdit(
      context: context,
      word: (previous['word'] ?? '').toString(),
      meaning: (previous['meaning'] ?? '').toString(),
    );
    // Huy / dong dialog / khong doi gi -> khong goi API nao.
    if (result == null || !mounted) return;

    final wordChanged = result.word != (previous['word'] ?? '').toString();
    setState(() => _isWordBusy = true);
    try {
      // Doi nghia khong dung toi field khac -> chi lay tu dien khi Tu doi.
      final enrichment =
          wordChanged ? await _fetchEnrichment(result.word) : null;
      if (!mounted) return;

      final updated = <String, dynamic>{
        ...previous,
        'word': result.word,
        'meaning': result.meaning,
      };
      if (enrichment != null) {
        if (enrichment.pronunciation.isNotEmpty) {
          updated['pronunciation'] = enrichment.pronunciation;
        }
        if (enrichment.fullDetails.isNotEmpty) {
          updated['full_details'] = enrichment.fullDetails;
        }
        if (enrichment.wordType.isNotEmpty) {
          updated['word_type'] = enrichment.wordType;
        }
      }

      setState(() {
        // normalizeWord: refresh details_parsed / example cho panel vi du.
        _replaceWordInSession(wordId, normalizeWord(updated));
      });

      if (wordChanged) {
        await _db.updateVocabularyWord(
          wordId: wordId,
          word: result.word,
          meaning: result.meaning,
          pronunciation: (updated['pronunciation'] ?? '').toString(),
          fullDetails: (updated['full_details'] ?? '').toString(),
          wordType: (updated['word_type'] ?? '').toString(),
          topicTag: (updated['topic_tag'] ?? '').toString(),
          commonSynonyms: (updated['common_synonyms'] ?? '').toString(),
        );
      } else {
        await _db.updateVocabularyWordDetails(
          wordId: wordId,
          meaning: result.meaning,
          pronunciation: (previous['pronunciation'] ?? '').toString(),
          fullDetails: (previous['full_details'] ?? '').toString(),
          wordType: (previous['word_type'] ?? '').toString(),
          topicTag: (previous['topic_tag'] ?? '').toString(),
          commonSynonyms: (previous['common_synonyms'] ?? '').toString(),
        );
      }
      if (!mounted) return;
      setState(() {
        // Chi reset khi chu cua Tu doi: dap an da go va dau sai tinh theo tu cu
        // nen khong con dung nua.
        if (wordChanged) _resetCardAnswerState();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editSavedMessage(result.word, wordChanged, enrichment)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Rollback theo id (khong theo _currentIndex) de khong ghi nham tu khac.
      setState(() => _replaceWordInSession(wordId, previous));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isWordBusy = false);
    }
  }

  /// Lay du lieu phu tu tu dien; loi mang / tu khong co -> null (khong nem).
  Future<WordEnrichment?> _fetchEnrichment(String word) async {
    try {
      return await _enrichment.fetch(word);
    } catch (e) {
      debugPrint('Review enrichment error: $e');
      return null;
    }
  }

  /// Thay row cua [wordId] trong phien on tap, tim theo id thay vi index de
  /// khong ghi nham khi vi tri hien tai da doi.
  void _replaceWordInSession(int wordId, Map<String, dynamic> row) {
    final index = _dueWords.indexWhere((w) => w['id'] == wordId);
    if (index != -1) _dueWords[index] = row;
  }

  /// Xoa trang thai tra loi cua the hien tai (goi trong setState).
  void _resetCardAnswerState() {
    _showAnswer = false;
    _isAnswerCorrect = null;
    _answerDiff = null;
    _answerController.clear();
    _flipController.reset();
    _calculatedIntervals = {};
    _hintLevel = 0;
  }

  String _editSavedMessage(
    String word,
    bool wordChanged,
    WordEnrichment? enrichment,
  ) {
    if (!wordChanged) return 'Đã cập nhật nghĩa "$word"';
    if (enrichment == null) {
      return 'Đã cập nhật "$word" (chưa lấy được phát âm / chi tiết)';
    }
    final parts = <String>[
      if (enrichment.pronunciation.isNotEmpty) 'phát âm',
      if (enrichment.fullDetails.isNotEmpty) 'chi tiết',
      if (enrichment.wordType.isNotEmpty) 'loại từ',
    ];
    if (parts.isEmpty) return 'Đã cập nhật "$word"';
    return 'Đã cập nhật "$word" + ${parts.join(', ')} từ từ điển';
  }

  void _rateWord(int quality) {
    if (_wordOptionsOpen || _isCompleted) return;
    // Safari chi bat keyboard cho focus DONG BO trong gesture: xin focus
    // truoc moi tinh toan/setState. De cuoi handler + qua unfocus/refocus
    // 2 node la mat keyboard (element focused nhung keyboard khong len).
    if (_pageFocusNode.hasFocus) _pageFocusNode.unfocus();
    if (!_isCompleted) _answerFocusNode.requestFocus();

    final word = _currentWordSafe;
    if (word == null) return;

    final oldMastery = word['mastery_level'] as int;

    final result = _srs.calculateNextReview(
      quality: quality,
      currentInterval: word['interval_days'] as int,
      easeFactor: (word['ease_factor'] as num).toDouble(),
      correctStreak: word['correct_streak'] as int,
      reviewCount: word['review_count'] as int,
      lapseCount: word['lapse_count'] as int? ?? 0,
    );

    _queueUpdate(word['id'] as int, result);

    _totalReviewed++;
    if (result.newMasteryLevel > oldMastery) _masteryUps++;

    _sessionResults.add({
      'word': word['word'],
      'quality': quality,
      'oldMastery': oldMastery,
      'newMastery': result.newMasteryLevel,
      'nextInterval': result.newInterval,
    });

    setState(() {
      if (quality == SrsService.qualityAgain) {
        _dueWords.add(word);
      }

      _resetCardAnswerState();

      if (_currentIndex < _dueWords.length - 1) {
        _currentIndex++;
      } else {
        _isCompleted = true;
      }
    });

    if (!_isCompleted) {
      _requestInputFocus();
    }
  }

  void _showAnswerCard() {
    if (_wordOptionsOpen || _isCompleted) return;
    final word = _currentWordSafe;
    if (word == null) return;

    _answerFocusNode.unfocus();
    _pageFocusNode.requestFocus();

    final intervals = <int, String>{};
    for (final q in [
      SrsService.qualityAgain,
      SrsService.qualityHard,
      SrsService.qualityGood,
      SrsService.qualityEasy,
    ]) {
      final res = _srs.calculateNextReview(
        quality: q,
        currentInterval: word['interval_days'] as int,
        easeFactor: (word['ease_factor'] as num).toDouble(),
        correctStreak: word['correct_streak'] as int,
        reviewCount: word['review_count'] as int,
      );
      intervals[q] = res.newInterval == 0 ? '< 1m' : '${res.newInterval}d';
    }

    setState(() {
      _showAnswer = true;
      // Grammar tu cham: khong so sanh chuoi go -> giu _isAnswerCorrect = null.
      if (!widget.grammarReview) {
        // Giữ nguyên kết luận đúng/sai như trước, đồng thời lưu dấu từng ký tự
        // để tô chỗ người dùng gõ thiếu / thừa / sai.
        _answerDiff = diffAnswer(
          typed: _answerController.text,
          expected: (word['word'] ?? '').toString(),
        );
        _isAnswerCorrect = _answerDiff!.isCorrect;
      }
      _calculatedIntervals = intervals;
    });

    _flipController.forward();
    unawaited(_speak((word['word'] ?? '').toString()));
  }

  /// Enter = "Show answer" cho che do grammar (khong co o nhap de onSubmitted).
  /// Global handler giong practice_page: activity key doc lap voi focus,
  /// cho phep bam Enter ngay sau khi mo man hinh (page node chua focus).
  bool _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return false;
    }
    // Khong mode grammar: Enter thuoc ve o nhap (onSubmitted) - khong chan.
    if (!widget.grammarReview) return false;
    // Dang hien dap an roi hoac phien ket thuc: de phim di, khong flip lai.
    if (_showAnswer || _isCompleted) return true;
    // Dialog / bottom sheet dang mo (sua nghia, xoa tu): Enter thuoc ve ho,
    // tranh nuot phim cua hop thoai (nut mac dinh nhan Enter).
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    _showAnswerCard();
    return true;
  }

  void _tapHint() {
    if (_showAnswer || _wordOptionsOpen) return;
    final wordStr = (_currentWordSafe?['word'] ?? '').toString();
    if (wordStr.isEmpty) return;
    final maxHints = (wordStr.length - 2).clamp(0, wordStr.length);
    if (_hintLevel < maxHints) {
      // Tap nut cuop focus lam Safari tat keyboard -> giu lai neu dang mo.
      final hadFocus = _answerFocusNode.hasFocus;
      setState(() => _hintLevel++);
      if (hadFocus) _answerFocusNode.requestFocus();
    }
  }

  Future<void> _quickEditMeaning() async {
    final w = _currentWordSafe;
    if (w == null || !mounted || _wordOptionsOpen) return;
    final next = await showQuickMeaningEdit(
      context: context,
      word: (w['word'] ?? '').toString(),
      meaning: (w['meaning'] ?? '').toString(),
    );
    if (next == null || !mounted) return;
    final previous = Map<String, dynamic>.from(w);
    setState(() {
      _dueWords[_currentIndex] = {...w, 'meaning': next};
    });
    try {
      await _db.updateVocabularyWordDetails(
        wordId: w['id'] as int,
        meaning: next,
        pronunciation: (w['pronunciation'] ?? '').toString(),
        fullDetails: (w['full_details'] ?? '').toString(),
        wordType: (w['word_type'] ?? '').toString(),
        topicTag: (w['topic_tag'] ?? '').toString(),
        commonSynonyms: (w['common_synonyms'] ?? '').toString(),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _dueWords[_currentIndex] = previous);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      // Đang hiện đáp án: giữ focus page để phím tắt 1-4 chấm SRS tiếp.
      // Chưa hiện đáp án: trả focus ô nhập như cũ.
      if (mounted) {
        if (_showAnswer) {
          _pageFocusNode.requestFocus();
        } else {
          _requestInputFocus();
        }
      }
    }
  }

  String _getMaskedWord(String word, {int hintLevel = 0}) {
    if (word.length <= 2) return word;
    final buffer = StringBuffer();
    for (int i = 0; i < word.length; i++) {
      if (i == 0 || i == word.length - 1 || word[i] == ' ') {
        buffer.write(word[i]);
      } else if (i <= hintLevel) {
        buffer.write(word[i]);
      } else {
        buffer.write(' _ ');
      }
    }
    return buffer.toString().replaceAll('  ', ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.lingoColors;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardOpen = keyboardInset > 0;
    // Focus = keyboard dang mo (cho ca truong hop Safari khong bao inset).
    final compactMode = keyboardOpen || _inputFocused;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    if (_isCompleted) return _buildCompletedScreen();

    if (_dueWords.isEmpty) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Review',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 72,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'All caught up!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No words are due for review right now.\nKeep learning new words!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentWord = _currentWordSafe;
    if (currentWord == null) {
      // Index ngoai pham vi (du lieu thay doi giua chay) - ket thuc phien
      // mot cach an toan thay vi crash RangeError.
      return _buildCompletedScreen();
    }
    final progress = (_currentIndex + 1) / _dueWords.length;

    return PopScope(
      canPop: !_isWordBusy,
      child: AbsorbPointer(
        absorbing: _isWordBusy,
        child: CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.f10, shift: true): _showWordOptions,
        const SingleActivator(LogicalKeyboardKey.digit0): _tapHint,
        const SingleActivator(LogicalKeyboardKey.numpad0): _tapHint,
      },
      child: KeyboardListener(
        focusNode: _pageFocusNode,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (_showAnswer) {
            if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
              _rateWord(SrsService.qualityAgain);
            } else if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
              _rateWord(SrsService.qualityHard);
            } else if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
              _rateWord(SrsService.qualityGood);
            } else if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
              _rateWord(SrsService.qualityEasy);
            }
          }
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
            onPressed: () => _popWithFlush(true),
          ),
          title: Text(
            widget.grammarReview
                ? 'Grammar Review'
                : (widget.listName ?? 'Daily Review'),
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withAlpha(80),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${_dueWords.length}',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          bottom: true,
          // Toan bo body cuon duoc: Safari iPad khong co layout khi keyboard
          // mo (viewInsets = 0) nen Column + Expanded cung lam tu bi che.
          child: SingleChildScrollView(
            controller: _bodyScrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              if (_isWordBusy) const LinearProgressIndicator(),
              // Progress bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: theme.colorScheme.primaryContainer.withAlpha(60),
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Mastery badge — an khi go phim de tiet kiem cho hien thi tu.
              if (!compactMode)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: MasteryBadge(level: currentWord['mastery_level'] as int),
                ),

              // Main card — cao tu nhien, cuon cung ca trang.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: _showWordOptions,
                  // Web/desktop: chuot phai mo menu (long-press kho phat hien).
                  onSecondaryTap: _showWordOptions,
                  child: AnimatedBuilder(
                  animation: _flipAnimation,
                  builder: (context, child) {
                    // null (grammar tu cham) giu mau trung tinh nhu khi tra loi dung.
                    final showColors = _showAnswer
                        ? (_isAnswerCorrect != false
                            ? [theme.colorScheme.primary, theme.colorScheme.primaryContainer]
                            : [theme.colorScheme.error, theme.colorScheme.error.withAlpha(160)])
                        : [theme.colorScheme.primary, theme.colorScheme.primaryContainer];

                    return Stack(
                      children: [
                        Container(
                          key: _questionCardKey,
                          width: double.infinity,
                          padding: EdgeInsets.fromLTRB(
                            compactMode ? 14 : 20,
                            (compactMode ? 14 : 20) + 20,
                            compactMode ? 14 : 20,
                            compactMode ? 14 : 20,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: showColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: showColors[0].withAlpha(70),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: !_showAnswer
                              ? _buildQuestionCardContent(currentWord, theme, compactMode)
                              : _buildAnswerCardContent(currentWord, theme, compactMode),
                        ),
                        // Nut hien: web click mo menu (mobile van long-press).
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton(
                            tooltip: 'Tùy chọn',
                            onPressed: _showWordOptions,
                            icon: Icon(
                              Icons.more_horiz_rounded,
                              color: theme.colorScheme.onPrimary.withAlpha(220),
                              size: 22,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withAlpha(25),
                              minimumSize: const Size(36, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  ),
                ),
              ),

              // Panel vi du kieu flashcard: chi hien sau khi nhap tu / Show answer.
              // Thieu vi du -> hien hint thay vi an im lang (de biet can bo sung).
              if (_showAnswer && (((currentWord['example'] ?? '') as String).isNotEmpty || ((currentWord['common_synonyms'] ?? '') as String).isNotEmpty))
                ReviewExamplePanel(
                  word: (currentWord['word'] ?? '').toString(),
                  example: (currentWord['example'] ?? '').toString(),
                  translation: ((currentWord['example_translation'] ?? '') as String).isEmpty
                      ? null
                      : (currentWord['example_translation'] ?? '').toString(),
                  target: (currentWord['example_target'] ?? '').toString().isEmpty
                      ? null
                      : (currentWord['example_target'] ?? '').toString(),
                  commonSynonyms: (currentWord['common_synonyms'] ?? '').toString(),
                  accent: theme.colorScheme.primary,
                  compact: compactMode,
                  onSpeak: () => _speak((currentWord['example'] ?? '').toString()),
                ),
              if (_showAnswer && ((currentWord['example'] ?? '') as String).isEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(20, compactMode ? 8 : 12, 20, 0),
                  child: Text(
                    'Chưa có ví dụ cho từ này — bổ sung tại trang /example.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

              // Bottom section: input + button OR rating buttons
              // Grammar: thay o go bang nut "Show answer" (tu cham).
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: !_showAnswer
                    ? (widget.grammarReview
                        ? _buildGrammarShowAnswerButton(theme, compactMode)
                        : _buildInputSection(theme, compactMode))
                    : _buildRatingSection(theme, colors, compactMode),
              ),

              // Safari iPad bao viewInsets = 0 khi keyboard mo -> spacer nay
              // tao cho de cuon the tu len tren keyboard. Khi he dieu hanh
              // bao inset that thi Scaffold da tu co layout, khong can spacer.
              if (keyboardInset <= 0 && _inputFocused)
                const SizedBox(height: 420),
              ],
            ),
          ),
        ),
      ),
      ),
      ),
      ),
    );
}

  Widget _buildQuestionCardContent(
    Map<String, dynamic> currentWord,
    ThemeData theme,
    bool compact,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if ((currentWord['topic_tag'] ?? '').isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: TopicTagBadge(
                  tag: currentWord['topic_tag'] as String,
                  onColoredSurface: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (!compact) ...[
          const Icon(Icons.translate_rounded, color: Colors.white54, size: 28),
          const SizedBox(height: 10),
        ],
        if ((currentWord['word_type'] ?? '').isNotEmpty) ...[
          WordTypeBadge(
            typeKey: currentWord['word_type'] as String,
            showIcon: false,
            onColoredSurface: true,
          ),
          const SizedBox(height: 10),
        ],
        Text(
          widget.grammarReview ? 'Think of the English structure' : 'What is the English word?',
          style: TextStyle(
            color: theme.colorScheme.onPrimary.withAlpha(170),
            fontSize: compact ? 12 : 13,
            fontFamily: 'Be Vietnam Pro',
          ),
        ),
        SizedBox(height: compact ? 8 : 12),
        Text(
          currentWord['meaning'] ?? '',
          textAlign: TextAlign.center,
          maxLines: compact ? 2 : 4,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Be Vietnam Pro',
            fontSize: compact ? 18 : 22,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimary,
            height: 1.3,
          ),
        ),
        // Vi du chi hien o mat dap an (sau khi tra loi), khong hien o mat hoi de tranh lo hint.
        // O chu duoc che (hint): chi co y nghia khi nguoi dung phai go tu.
        if (!widget.grammarReview) ...[
          SizedBox(height: compact ? 10 : 16),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 6 : 10,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getMaskedWord(currentWord['word'] ?? '', hintLevel: _hintLevel),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 15 : 18,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ],
        if (currentWord['set_name'] != null && !compact) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.onPrimary.withAlpha(35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              currentWord['set_name'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onPrimary.withAlpha(150),
                fontSize: 12,
                fontFamily: 'Be Vietnam Pro',
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Từ đáp án trên mặt sau thẻ: giữ nguyên style cũ, chỉ tô thêm ký tự gõ
  /// thiếu / gõ sai khi có dấu lệch.
  Widget _buildAnswerWord(
    Map<String, dynamic> currentWord,
    ThemeData theme,
    bool compact,
  ) {
    final wordText = (currentWord['word'] ?? '').toString();
    final wordStyle = TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: compact ? 24 : 30,
      fontWeight: FontWeight.w800,
      color: theme.colorScheme.onPrimary,
      letterSpacing: -0.3,
    );

    final diff = _answerDiff;
    if (!widget.grammarReview && diff != null && diff.hasMismatch) {
      return AnswerDiffText(
        text: wordText,
        marks: diff.expectedMarks,
        baseStyle: wordStyle,
        mismatchColor: _answerMismatchColor,
      );
    }

    return Text(
      wordText,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: wordStyle,
    );
  }

  /// Dòng "You typed: ...": nội dung y như trước, chỉ gạch ngang / tô đỏ ký tự
  /// người dùng gõ thừa hoặc gõ lệch.
  Widget _buildTypedLine(ThemeData theme, bool compact) {
    const prefix = 'You typed: ';
    final typedText = _answerController.text;
    final baseStyle = TextStyle(
      fontSize: compact ? 11 : 13,
      color: theme.colorScheme.onPrimary.withAlpha(170),
      fontStyle: FontStyle.italic,
      fontFamily: 'Be Vietnam Pro',
    );

    final diff = _answerDiff;
    if (diff == null || !diff.typedMarks.any((m) => m.isMismatch)) {
      return Text('$prefix$typedText', style: baseStyle);
    }

    // Dấu tính trên riêng chuỗi đã gõ -> chèn thêm dấu "keep" cho phần tiền tố
    // để widget dựng lại đúng cả dòng.
    final prefixChars = prefix.split('');
    final marks = <CharMark>[
      for (var i = 0; i < prefixChars.length; i++)
        CharMark(prefixChars[i], CharMarkKind.keep, i),
      for (final mark in diff.typedMarks)
        CharMark(mark.char, mark.kind, mark.index + prefixChars.length),
    ];

    return AnswerDiffText(
      text: '$prefix$typedText',
      marks: marks,
      baseStyle: baseStyle,
      mismatchColor: _answerMismatchColor,
      replacedDecoration: TextDecoration.lineThrough,
      maxLines: 2,
    );
  }

  Widget _buildAnswerCardContent(
    Map<String, dynamic> currentWord,
    ThemeData theme,
    bool compact,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Grammar tu cham: khong co dung/sai tu may, an icon check/cancel.
        if (!widget.grammarReview) ...[
          Icon(
            _isAnswerCorrect == true ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: _isAnswerCorrect == true ? Colors.greenAccent : Colors.redAccent,
            size: compact ? 32 : 44,
          ),
          SizedBox(height: compact ? 6 : 10),
        ],
        _buildAnswerWord(currentWord, theme, compact),
        if ((currentWord['pronunciation'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '/${currentWord['pronunciation']}/',
            style: TextStyle(
              fontSize: compact ? 12 : 14,
              color: theme.colorScheme.onPrimary.withAlpha(170),
              fontStyle: FontStyle.italic,
              fontFamily: 'Be Vietnam Pro',
            ),
          ),
        ],
        if ((currentWord['word_type'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          WordTypeBadge(
            typeKey: currentWord['word_type'] as String,
            showIcon: false,
            onColoredSurface: true,
          ),
        ],
        SizedBox(height: compact ? 8 : 12),
        Container(width: 48, height: 2, color: theme.colorScheme.onPrimary.withAlpha(60)),
        SizedBox(height: compact ? 8 : 12),
        GestureDetector(
          onTap: _quickEditMeaning,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  currentWord['meaning'] ?? '',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Be Vietnam Pro',
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.edit_rounded,
                size: 14,
                color: theme.colorScheme.onPrimary.withAlpha(170),
              ),
            ],
          ),
        ),
        if (!widget.grammarReview && _answerController.text.trim().isNotEmpty && _isAnswerCorrect != true) ...[
          SizedBox(height: compact ? 6 : 10),
          _buildTypedLine(theme, compact),
        ],
        if ((currentWord['full_details'] ?? '').isNotEmpty && !compact) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.onPrimary.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              currentWord['full_details'],
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onPrimary.withAlpha(170),
                height: 1.4,
                fontFamily: 'Be Vietnam Pro',
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Che do grammar: khong go — chi lat the roi tu cham bang 4 nut SRS.
  Widget _buildGrammarShowAnswerButton(ThemeData theme, bool compact) {
    return SizedBox(
      width: double.infinity,
      height: compact ? 48 : 54,
      child: ElevatedButton.icon(
        onPressed: _showAnswerCard,
        icon: Icon(Icons.visibility_rounded,
            color: theme.colorScheme.onPrimary, size: 20),
        label: Text(
          'Show answer',
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
            fontSize: compact ? 14 : 16,
            fontFamily: 'Plus Jakarta Sans',
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildInputSection(ThemeData theme, bool compact) {
    final wordStr = (_currentWordSafe?['word'] ?? '').toString();
    final maxHints = (wordStr.length - 2).clamp(0, wordStr.length);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Text field - chi build lai TextField khi text doi, khong rebuild ca trang
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _answerController,
          builder: (context, value, _) => TextField(
            key: _answerFieldKey,
            controller: _answerController,
            focusNode: _answerFocusNode,
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.text,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            autofocus: true,
            // Safari iPad: keyboard che field neu khong co scrollPadding.
            scrollPadding: const EdgeInsets.only(bottom: 220),
            onTap: () => _scrollAnswerIntoView(),
            style: TextStyle(
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
              fontFamily: 'Be Vietnam Pro',
            ),
            decoration: InputDecoration(
              hintText: 'Type the English word...',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(140),
                fontSize: compact ? 14 : 16,
              ),
              suffixIcon: value.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: theme.colorScheme.onSurfaceVariant, size: 18),
                      onPressed: () {
                        _answerController.clear();
                        // Giu keyboard khi xoa chu.
                        _answerFocusNode.requestFocus();
                      },
                    )
                  : null,
            ),
            onSubmitted: (_) => _showAnswerCard(),
          ),
        ),
        // Safari iPad: khong tu mo keyboard neu focus ngoai gesture.
        // Nhan vao dong nay (trong gesture) thi keyboard len chac chan.
        if (!_showAnswer && !_inputFocused)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: GestureDetector(
              onTap: () {
                if (_pageFocusNode.hasFocus) _pageFocusNode.unfocus();
                _answerFocusNode.requestFocus();
              },
              child: Text(
                'Chạm vào đây để hiện bàn phím',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        // Hint + Check buttons row
        Row(
          children: [
            // Hint button
            if (_dueWords.isNotEmpty)
              Expanded(
                child: SizedBox(
                  height: compact ? 48 : 54,
                  child: OutlinedButton.icon(
                    onPressed: (_hintLevel < maxHints) ? _tapHint : null,
                    icon: Icon(
                      _hintLevel < maxHints
                          ? Icons.lightbulb
                          : Icons.lightbulb_outline,
                      size: 18,
                    ),
                    label: Text(
                      _hintLevel > 0
                          ? 'Hint ($_hintLevel/$maxHints)'
                          : 'Hint (0)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 14 : 16,
                        fontFamily: 'Plus Jakarta Sans',
                        color: _hintLevel < maxHints
                            ? const Color(0xFFE6A800)
                            : theme.colorScheme.onSurfaceVariant.withAlpha(100),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE6A800),
                      backgroundColor: _hintLevel < maxHints
                          ? const Color(0xFFE6A800).withAlpha(20)
                          : Colors.transparent,
                      side: BorderSide(
                        color: _hintLevel < maxHints
                            ? const Color(0xFFE6A800).withAlpha(120)
                            : theme.colorScheme.onSurfaceVariant.withAlpha(50),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            if (_dueWords.isNotEmpty) const SizedBox(width: 10),
            // Check button
            Expanded(
              flex: _dueWords.isNotEmpty ? 1 : 0,
              child: SizedBox(
                height: compact ? 48 : 54,
                child: ElevatedButton.icon(
                  onPressed: _showAnswerCard,
                  icon: Icon(Icons.check_rounded,
                      color: theme.colorScheme.onPrimary, size: 20),
                  label: Text(
                    'Check answer',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 14 : 16,
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingSection(
    ThemeData theme,
    LingoFlowColors colors,
    bool compact,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'How well did you know it?',
          style: TextStyle(
            fontSize: compact ? 13 : 15,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
            fontFamily: 'Plus Jakarta Sans',
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        Row(
          children: [
            Expanded(
              child: _buildRateButton(
                label: 'Again',
                emoji: '\u{1F622}',
                shortcut: '1',
                subtitle: _calculatedIntervals[SrsService.qualityAgain] ?? '',
                color: theme.colorScheme.error,
                onTap: () => _rateWord(SrsService.qualityAgain),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRateButton(
                label: 'Hard',
                emoji: '\u{1F914}',
                shortcut: '2',
                subtitle: _calculatedIntervals[SrsService.qualityHard] ?? '',
                color: colors.masteryReviewing,
                onTap: () => _rateWord(SrsService.qualityHard),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRateButton(
                label: 'Good',
                emoji: '\u{1F44D}',
                shortcut: '3',
                subtitle: _calculatedIntervals[SrsService.qualityGood] ?? '',
                color: colors.masteryMastered,
                onTap: () => _rateWord(SrsService.qualityGood),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRateButton(
                label: 'Easy',
                emoji: '\u{1F31F}',
                shortcut: '4',
                subtitle: _calculatedIntervals[SrsService.qualityEasy] ?? '',
                color: colors.masteryLearning,
                onTap: () => _rateWord(SrsService.qualityEasy),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRateButton({
    required String label,
    required String emoji,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    String? shortcut,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          border: Border.all(color: color.withAlpha(76), width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                if (shortcut != null)
                  Positioned(
                    right: -10,
                    top: -10,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(51),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Center(
                        child: Text(
                          shortcut,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: color.withAlpha(179)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedScreen() {
    final theme = Theme.of(context);
    final percentage = _totalReviewed > 0
        ? ((_sessionResults.where((r) => (r['quality'] as int) >= 3).length /
                      _totalReviewed) *
                  100)
              .round()
        : 0;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.primary),
          onPressed: () => _popWithFlush(true),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withAlpha(76),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_events,
                    size: 64,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Review Complete!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        'Reviewed',
                        '$_totalReviewed',
                        theme.colorScheme.onPrimary,
                      ),
                      _buildStatItem(
                        'Accuracy',
                        '$percentage%',
                        theme.colorScheme.onPrimary,
                      ),
                      _buildStatItem(
                        'Level Up',
                        '+$_masteryUps',
                        Colors.greenAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_sessionResults.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Session Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(_sessionResults.length, (index) {
                final r = _sessionResults[index];
                final quality = r['quality'] as int;
                final oldLevel = r['oldMastery'] as int;
                final newLevel = r['newMastery'] as int;
                final interval = r['nextInterval'] as int;
                final levelChanged = newLevel != oldLevel;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: quality >= 3
                          ? Colors.green.withAlpha(51)
                          : theme.colorScheme.error.withAlpha(51),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: quality >= 3
                              ? Colors.green.withAlpha(25)
                              : theme.colorScheme.error.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            quality >= 3 ? Icons.check : Icons.replay,
                            color: quality >= 3
                                ? Colors.green
                                : theme.colorScheme.error,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r['word'] as String,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            if (levelChanged)
                              Text(
                                '${SrsService.masteryName(oldLevel)} -> ${SrsService.masteryName(newLevel)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: newLevel > oldLevel
                                      ? Colors.green
                                      : Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        'Next: ${interval}d',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => _popWithFlush(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Done',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color.withAlpha(204)),
        ),
      ],
    );
  }
}
