import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../services/srs_service.dart';
import '../services/word_change_bus.dart';
import '../services/tts_settings_service.dart';
import '../widgets/mastery_badge.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/quick_meaning_edit.dart';
import '../widgets/example_card.dart';
import '../widgets/load_error_view.dart';
import '../widgets/save_blocked_dialog.dart';
import '../widgets/save_feedback.dart';
import '../services/word_details_parser.dart';

class PracticePage extends StatefulWidget {
  final int listId;
  final String listName;
  final int userId;
  final String? category;
  final bool studyMode;
  final List<Map<String, dynamic>>? preloadedWords;

  const PracticePage({
    super.key,
    this.listId = 0,
    required this.listName,
    required this.userId,
    this.studyMode = true,
    this.category,
    this.preloadedWords,
  });

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final DatabaseService _db = DatabaseService();
  final SrsService _srs = SrsService();
  List<Map<String, dynamic>> _words = [];
  bool _isLoading = true;

  /// Loi tai danh sach tu (khac null = khong co de luyen).
  Object? _loadError;

  /// Số lượt ghi SRS đang chạy nền (có thể >1 nếu mạng chậm và người dùng đã
  /// sang câu tiếp). Chỉ dùng để chặn thoát trang, KHÔNG chặn việc trả lời.
  int _pendingSaves = 0;
  bool get _isSavingGrade => _pendingSaves > 0;

  int _currentIndex = 0;
  int _score = 0;
  int _totalAnswered = 0;
  bool _isCompleted = false;
  bool _showConfetti = false;
  bool _showResult = false;
  DateTime? _questionStartTime;

  final List<Map<String, dynamic>> _sessionResults = [];
  final List<Map<String, dynamic>> _retryWords = [];
  bool _isPopping = false;

  final TextEditingController _spellController = TextEditingController();
  final FocusNode _spellFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final TtsSettingsService _ttsSettings = TtsSettingsService();
  int _hintLevel = 0;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    _loadWords();
  }

  Future<void> _speak(String text) async {
    try {
      await _ttsSettings.speakWith(text);
    } catch (e) {
      debugPrint('Practice TTS error: $e');
    }
  }

  void _focusSpellInputIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _showResult || _isCompleted) return;
      _spellFocusNode.requestFocus();
    });
  }

  Future<void> _loadWords() async {
    try {
      List<Map<String, dynamic>> words;
      if (widget.preloadedWords != null) {
        words = List<Map<String, dynamic>>.from(widget.preloadedWords!);
      } else {
        final List<Map<String, dynamic>> wordsResult;
        if (widget.category != null) {
          wordsResult = await _db.getWordsByCategory(widget.userId, widget.category!);
        } else {
          wordsResult = await _db.getVocabularyWords(widget.listId);
        }
        words = List<Map<String, dynamic>>.from(wordsResult);
      }
      words.shuffle(Random());
      setState(() {
        _words = words;
        _isLoading = false;
        _loadError = null;
        _questionStartTime = DateTime.now();
      });
      _focusSpellInputIfNeeded();
    } catch (e) {
      // Mat mang: bao ro thay vi hien "No words to study" gay hieu nham.
      setState(() {
        _isLoading = false;
        _loadError = e;
      });
    }
  }

  void _retryLoad() {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    _loadWords();
  }

  void _nextQuestion() {
    setState(() {
      _showResult = false;
      _spellController.clear();
      _questionStartTime = DateTime.now();
      _hintLevel = 0;

      if (_words.isEmpty) return;

      if (_currentIndex < _words.length - 1) {
        _currentIndex++;
      } else if (widget.studyMode && _retryWords.isNotEmpty) {
        _words = List<Map<String, dynamic>>.from(_retryWords);
        _words.shuffle(Random());
        _retryWords.clear();
        _currentIndex = 0;
      } else {
        _isCompleted = true;
        _showConfetti = true;
        if (!widget.studyMode) {
          unawaited(() async {
            await _updateListProgress();
            WordChangeBus().notifyChanged('practice-flush');
          }());
        }
      }
    });
    if (_isCompleted) {
      _spellFocusNode.unfocus();
    } else {
      _focusSpellInputIfNeeded();
      _scrollToTopAfterFrame();
    }
  }

  Future<void> _updateListProgress() async {
    try {
      final words = await _db.getVocabularyWords(widget.listId);
      final total = words.length;
      final mastered = words.where((w) => (w['mastery_level'] ?? 0) >= 3).length;
      final progress = total > 0 ? ((mastered / total) * 100).round() : 0;
      await _db.updateListProgress(widget.listId, progress, total);
    } catch (e) {
      debugPrint('Failed to update set progress: $e');
    }
  }

  /// Luu SRS cua cau vua tra loi, chi tra `true` khi server da ghi xong.
  /// Mat mang -> hop thoai chan: khong tiep tuc de khong mat tien do am tham.
  Future<bool> _saveReviewGrade(
    Map<String, dynamic> word,
    SrsResult result,
  ) async {
    Future<void> write() => _db.updateWordReview(
          wordId: word['id'] as int,
          reviewCount: result.newReviewCount,
          correctStreak: result.newCorrectStreak,
          easeFactor: result.newEaseFactor,
          intervalDays: result.newInterval,
          nextReviewDate: result.nextReviewDate,
          masteryLevel: result.newMasteryLevel,
          lapseCount: result.newLapseCount,
        );

    setState(() => _pendingSaves++);
    try {
      await write();
      if (mounted) setState(() => _pendingSaves = (_pendingSaves - 1).clamp(0, 999));
      return true;
    } catch (e) {
      debugPrint('Failed to save review update: $e');
      if (!mounted) return false;
      setState(() => _pendingSaves = (_pendingSaves - 1).clamp(0, 999));
      return showSaveBlockedDialog(
        context: context,
        error: e,
        message:
            'Kết quả của "${(word['word'] ?? '').toString()}" chưa được lưu. '
            'Kết nối lại rồi bấm "Thử lại" để không phải làm lại từ đầu.',
        onRetry: write,
        onExit: () => _popWithFlush(true),
      );
    }
  }

  /// Guard _isPopping: chan double-pop khi Navigator dang locked.
  Future<void> _popWithFlush([bool result = false]) async {
    if (_isPopping || _isSavingGrade) return;
    _isPopping = true;
    WordChangeBus().notifyChanged('practice-flush');
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;
    navigator.pop(result);
  }

  Future<void> _checkSpell() async {
    if (_words.isEmpty || _showResult) return;
    final word = _words[_currentIndex];
    final correct = word['word'];
    final isCorrect = _spellController.text.trim().toLowerCase() == correct.toLowerCase();

    if (widget.studyMode) {
      if (!isCorrect) {
        _retryWords.add(Map<String, dynamic>.from(word));
      }
      setState(() {
        _showResult = true;
        _totalAnswered++;
        if (isCorrect) _score++;
      });
      // Không unfocus: giữ bàn phím mở để tick lần nữa là sang câu tiếp.
      _speakAfterFrame(correct);
      _scrollToTopAfterFrame();
      return;
    }

    final responseTimeMs = _questionStartTime != null
        ? DateTime.now().difference(_questionStartTime!).inMilliseconds
        : 5000;

    final quality = _srs.practiceResultToQuality(isCorrect, responseTimeMs: responseTimeMs);
    final oldMastery = word['mastery_level'] as int? ?? 0;

    final result = _srs.calculateNextReview(
      quality: quality,
      currentInterval: word['interval_days'] as int? ?? 0,
      easeFactor: ((word['ease_factor'] ?? 2.5) as num).toDouble(),
      correctStreak: word['correct_streak'] as int? ?? 0,
      reviewCount: word['review_count'] as int? ?? 0,
      lapseCount: word['lapse_count'] as int? ?? 0,
    );

    // Hiện kết quả NGAY (không chờ mạng) để bấm tick là thấy phản hồi tức thì.
    // SRS lưu ở nền; nếu lỗi mạng vẫn chặn tiến độ bằng hộp thoại như trước.
    _sessionResults.add({
      'word': correct,
      'isCorrect': isCorrect,
      'oldMastery': oldMastery,
      'newMastery': result.newMasteryLevel,
      'nextInterval': result.newInterval,
    });

    setState(() {
      _showResult = true;
      _totalAnswered++;
      if (isCorrect) _score++;
    });
    _speakAfterFrame(correct);
    _scrollToTopAfterFrame();
    unawaited(_saveReviewGrade(word, result));
  }

  /// Đọc từ sau khi frame kết quả đã vẽ xong (TTS không làm chậm phản hồi).
  void _speakAfterFrame(String text) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_speak(text));
    });
  }

  /// Kéo nội dung lên đầu để khung kết quả hiện ngay, không bị trôi xuống dưới.
  void _scrollToTopAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _restart() {
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _totalAnswered = 0;
      _isCompleted = false;
      _showConfetti = false;
      _showResult = false;
      _spellController.clear();
      _words.shuffle(Random());
      _sessionResults.clear();
      _retryWords.clear();
      _questionStartTime = DateTime.now();
    });
    _focusSpellInputIfNeeded();
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (_isCompleted) {
        _restart();
      } else {
        _handleKeyNext();
      }
      return true;
    }
    return false;
  }

  void _handleKeyNext() {
    if (_isCompleted) return;
    if (_showResult) {
      _nextQuestion();
    } else {
      _checkSpell();
    }
  }

  void _tapHint() {
    if (_showResult || _words.isEmpty || _currentIndex >= _words.length) {
      return;
    }
    final word = _words[_currentIndex]['word'] ?? '';
    final wordStr = word.toString();
    final maxHints = (wordStr.length - 2).clamp(0, wordStr.length);
    if (_hintLevel < maxHints) {
      setState(() => _hintLevel++);
    }
  }

  Future<void> _quickEditMeaning() async {
    if (_words.isEmpty || _currentIndex >= _words.length || !mounted) return;
    final w = _words[_currentIndex];
    final next = await showQuickMeaningEdit(
      context: context,
      word: (w['word'] ?? '').toString(),
      meaning: (w['meaning'] ?? '').toString(),
    );
    if (next == null || !mounted) return;
    // Bounds co the doi trong luc dialog mo (retry shuffle/_restart).
    if (_currentIndex >= _words.length) return;
    final previous = Map<String, dynamic>.from(_words[_currentIndex]);
    // Optimistic patch tai cho: giu nguyen trang thai hien ket qua cua cau hoi.
    setState(() {
      _words[_currentIndex] = {..._words[_currentIndex], 'meaning': next};
    });
    try {
      final example = await runWithSaveFeedback<Map<String, String>?>(
        context: context,
        word: (w['word'] ?? '').toString(),
        action: () => _db.updateVocabularyWordDetails(
          wordId: previous['id'] as int,
          meaning: next,
          pronunciation: (previous['pronunciation'] ?? '').toString(),
          fullDetails: (previous['full_details'] ?? '').toString(),
          wordType: (previous['word_type'] ?? '').toString(),
          topicTag: (previous['topic_tag'] ?? '').toString(),
          commonSynonyms: (previous['common_synonyms'] ?? '').toString(),
          regenerateExample: true,
        ),
      );
      if (example != null && mounted) {
        setState(() {
          if (_currentIndex < _words.length) {
            _words[_currentIndex] = {
              ..._words[_currentIndex],
              'example_sentence': example['sentence'],
              'example_translation': example['translation'],
              'example_target': example['target'],
            };
          }
        });
      }
      WordChangeBus().notifyChanged('edit-word');
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_currentIndex < _words.length) {
            _words[_currentIndex] = previous;
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      // Spell mode: tra focus de go tiep; MC mode thi no-op.
      if (mounted) _focusSpellInputIfNeeded();
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
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _spellController.dispose();
    _spellFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
            onPressed: () => _popWithFlush(true),
          ),
          title: Text(
            widget.listName,
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
        body: LoadErrorView(
          error: _loadError,
          onRetry: _retryLoad,
          onBack: () => _popWithFlush(true),
        ),
      );
    }

    if (_words.isEmpty) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
            onPressed: () => _popWithFlush(),
          ),
          title: Text(widget.listName, style: TextStyle(color: theme.colorScheme.onSurface)),
        ),
        body: const Center(child: Text('Chưa có từ nào để luyện')),
      );
    }

    if (_isCompleted) {
      final percentage = _totalAnswered > 0 ? (_score * 100 / _totalAnswered).round() : 0;
      return ConfettiOverlay(
        play: _showConfetti,
        child: Scaffold(
          backgroundColor: theme.colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
              onPressed: () => _popWithFlush(true),
            ),
            title: Text(widget.listName, style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.brightness == Brightness.dark
                          ? theme.colorScheme.outlineVariant
                          : theme.colorScheme.primary,
                      width: 1,
                    ),
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
                      Icon(Icons.celebration_rounded,
                          size: 56, color: theme.colorScheme.onPrimary),
                      const SizedBox(height: 14),
                      Text(
                        widget.studyMode ? 'Đã học xong!' : 'Hoàn thành luyện tập!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Đúng $_score/$_totalAnswered câu · $percentage%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onPrimary.withAlpha(235),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _restart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Làm lại',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildKeyChip(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _popWithFlush(true),
                  child: const Text('Thoát'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentWord = _words[_currentIndex];
    final meaning = currentWord['meaning'];
    final masteryLevel = currentWord['mastery_level'] as int? ?? 0;
    final practiceDetails = parseFullDetails((currentWord['full_details'] ?? '').toString());
    final practiceResolved = resolveExample(currentWord);
    final practiceExample = practiceResolved['sentence'] ?? '';
    final practiceTranslation = practiceResolved['translation'] ?? '';
    final practicePos = getPrimaryPos(practiceDetails);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.digit0): _tapHint,
        const SingleActivator(LogicalKeyboardKey.numpad0): _tapHint,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
          onPressed: () => _popWithFlush(true),
        ),
        title: Text(widget.listName, style: TextStyle(color: theme.colorScheme.onSurface)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withAlpha(51),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1}/${_words.length}',
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            if (_isSavingGrade) const LinearProgressIndicator(minHeight: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / _words.length,
                  backgroundColor: theme.colorScheme.primaryContainer.withAlpha(51),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  minHeight: 4,
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = keyboardOpen || constraints.maxHeight < 620;
                  final contentPadding = compact ? 18.0 : 24.0;
                  final sectionGap = compact ? 14.0 : 20.0;
                  final cardPadding = compact ? 18.0 : 24.0;
                  final titleFont = compact ? 21.0 : 24.0;
                  final maskedFont = compact ? 26.0 : 32.0;
                  final isCorrectAnswer = _spellController.text.trim().toLowerCase() ==
                      currentWord['word'].toString().toLowerCase();
                  final typedAnswer = _spellController.text.trim();

                  final content = Padding(
                    padding: EdgeInsets.fromLTRB(contentPadding, keyboardOpen ? 8 : 12, contentPadding, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(
                            _showResult
                                ? (compact ? 12 : 16)
                                : cardPadding,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withAlpha(51),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Khi da tra loi tren man hinh nho: bo bot dong chu
                              // de toan bo ket qua + nut Tiep nam trong 1 khung.
                              if (!_showResult || !compact) ...[
                                MasteryBadge(level: masteryLevel),
                                SizedBox(height: compact ? 8 : 12),
                                Text(
                                  'Từ tiếng Anh của nghĩa này là gì?',
                                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                                ),
                                SizedBox(height: compact ? 8 : 12),
                              ] else
                                const SizedBox(height: 2),
                              GestureDetector(
                                onTap: _quickEditMeaning,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        meaning,
                                        textAlign: TextAlign.center,
                                        maxLines: _showResult ? 2 : 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: titleFont,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.edit_rounded,
                                      size: 14,
                                      color: theme.colorScheme.primary.withAlpha(170),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: _showResult && compact ? 8 : sectionGap),
                        // Giữ ô nhập trong cây (Offstage) khi hiện kết quả: bàn
                        // phím không đóng/mở lại giữa các câu -> bấm tick lần nữa
                        // là sang câu tiếp, hết cảm giác khựng vì IME.
                        Offstage(
                          offstage: _showResult,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                        Text(
                          'Gõ từ tiếng Anh:',
                          style: TextStyle(
                            fontSize: compact ? 15 : 16,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: compact ? 10 : 14),
                        Container(
                          padding: EdgeInsets.all(compact ? 18 : 24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              _getMaskedWord(currentWord['word'], hintLevel: _hintLevel),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: maskedFont,
                                letterSpacing: 2,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        // Hint button
                        const SizedBox(height: 6),
                        _buildPracticeHintButton(currentWord),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _spellController,
                          focusNode: _spellFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Nhập từ bạn nhớ được...',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 12 : 14),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerLowest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          // Giữ bàn phím mở sau khi bấm ✓: mặc định Flutter sẽ
                          // unfocus (bàn phím đóng rồi mở lại -> khựng). No-op
                          // để tick lần nữa là sang câu tiếp ngay.
                          onEditingComplete: () {},
                          onSubmitted: _showResult
                              ? (_) => _nextQuestion()
                              : (_) => _checkSpell(),
                        ),
                            ],
                          ),
                        ),
                        // Ket qua: dung/sai + dap an + phat am + vi du + SRS.
                        if (_showResult && keyboardOpen)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.keyboard_return_rounded,
                                  size: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Bấm Enter/nút ✓ trên bàn phím để sang câu tiếp',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_showResult) ...[
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 10 : 12,
                              vertical: compact ? 8 : 10,
                            ),
                            decoration: BoxDecoration(
                              color: isCorrectAnswer
                                  ? Colors.green.withAlpha(45)
                                  : Colors.red.withAlpha(45),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isCorrectAnswer ? Icons.check_circle : Icons.cancel,
                                      size: 18,
                                      color: isCorrectAnswer ? Colors.green : Colors.red,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isCorrectAnswer ? 'Đúng rồi!' : 'Sai rồi',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isCorrectAnswer ? Colors.green : Colors.red,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Đáp án: ${currentWord['word']}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if ((currentWord['pronunciation'] ?? '').isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      '/${currentWord['pronunciation']}/',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                if (!isCorrectAnswer && typedAnswer.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Bạn gõ: $typedAnswer',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                if (practiceExample.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  ExampleCard(
                                    example: practiceExample,
                                    pos: practicePos,
                                    translation: practiceTranslation.isEmpty ? null : practiceTranslation,
                                    maxLines: compact ? 3 : 4,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!widget.studyMode && _sessionResults.isNotEmpty) ...[
                            SizedBox(height: compact ? 8 : 10),
                            _buildSrsFeedback(_sessionResults.last),
                          ],
                        ],
                        const Spacer(),
                        if (_showResult) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _nextQuestion,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                padding: EdgeInsets.symmetric(vertical: compact ? 14 : 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _currentIndex < _words.length - 1 ? 'Tiếp' : 'Hoàn thành',
                                    style: TextStyle(
                                      color: theme.colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _buildKeyChip(),
                                ],
                              ),
                            ),
                          ),
                          if (!compact) ...[
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                'Nhấn Enter để tiếp tục',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          ],
                        ],
                      ],
                    ),
                  );

                  return SingleChildScrollView(
                    controller: _scrollController,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(child: content),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
    ),
    );
  }

  Widget _buildPracticeHintButton(Map<String, dynamic> currentWord) {
    final theme = Theme.of(context);
    final wordStr = (currentWord['word'] ?? '').toString();
    final maxHints = (wordStr.length - 2).clamp(0, wordStr.length);
    final canHint = _hintLevel < maxHints;

    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: canHint ? _tapHint : null,
          icon: Icon(
            canHint ? Icons.lightbulb : Icons.lightbulb_outline,
            size: 16,
          ),
          label: Text(
            _hintLevel > 0 ? 'Gợi ý ($_hintLevel/$maxHints)' : 'Gợi ý',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            backgroundColor: canHint
                ? theme.colorScheme.primary.withAlpha(15)
                : Colors.transparent,
            side: BorderSide(
              color: canHint
                  ? theme.colorScheme.primary.withAlpha(100)
                  : theme.colorScheme.onSurfaceVariant.withAlpha(50),
              width: 2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildSrsFeedback(Map<String, dynamic> result) {
    final theme = Theme.of(context);
    final oldMastery = result['oldMastery'] as int;
    final newMastery = result['newMastery'] as int;
    final nextInterval = result['nextInterval'] as int;
    final levelChanged = newMastery != oldMastery;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primaryContainer.withAlpha(51)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nextInterval <= 0
                      ? 'Ôn lại hôm nay'
                      : 'Ôn lại sau $nextInterval ngày',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                ),
                if (levelChanged)
                  Text(
                    '${SrsService.masteryName(oldMastery)} -> ${SrsService.masteryName(newMastery)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: newMastery > oldMastery ? Colors.green : Colors.orange,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyChip() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.onPrimary.withAlpha(38),
        border: Border.all(color: theme.colorScheme.onPrimary.withAlpha(120), width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.keyboard_return, size: 13, color: theme.colorScheme.onPrimary),
          const SizedBox(width: 4),
          Text(
            'Enter',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onPrimary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}


