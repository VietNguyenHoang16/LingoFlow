import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/database_service.dart';
import '../services/srs_service.dart';
import '../services/tts_settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mastery_badge.dart';

class ReviewPage extends StatefulWidget {
  final int userId;
  final int? listId;
  final String? listName;
  final String? category;

  const ReviewPage({
    super.key,
    required this.userId,
    this.listId,
    this.listName,
    this.category,
  });

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  final SrsService _srs = SrsService();
  final FlutterTts _flutterTts = FlutterTts();
  final TtsSettingsService _ttsSettings = TtsSettingsService();

  final TextEditingController _answerController = TextEditingController();
  final FocusNode _answerFocusNode = FocusNode();
  final FocusNode _pageFocusNode = FocusNode();
  final GlobalKey _answerFieldKey = GlobalKey();
  bool? _isAnswerCorrect;

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

  Map<int, String> _calculatedIntervals = {};

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _answerFocusNode.addListener(_handleAnswerFocusChange);
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _initTts();
    _loadDueWords();
  }

  Future<void> _initTts() async {
    await _ttsSettings.applyTo(_flutterTts);
  }

  Future<void> _speak(String text) async {
    try {
      await _flutterTts.stop();
      await _ttsSettings.applyTo(_flutterTts);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Review TTS error: $e');
    }
  }

  Future<void> _flushUpdates() async {
    if (_pendingUpdates.isEmpty) return;
    await Future.wait(List<Future<void>>.from(_pendingUpdates));
  }

  @override
  void dispose() {
    unawaited(_flushUpdates());
    _answerFocusNode.removeListener(_handleAnswerFocusChange);
    _answerController.dispose();
    _answerFocusNode.dispose();
    _pageFocusNode.dispose();
    _flipController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _loadDueWords() async {
    try {
      List<Map<String, dynamic>> words;
      if (widget.category != null) {
        words = await _db.getWordsDueForReviewByCategory(widget.userId, widget.category!);
      } else if (widget.listId != null) {
        words = await _db.getWordsDueForReview(widget.listId!);
      } else {
        words = await _db.getAllWordsDueForReview(widget.userId);
      }
      words.shuffle();

      setState(() {
        _dueWords = words;
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
    void focusAndReveal() {
      if (!mounted || _showAnswer || _isCompleted || _dueWords.isEmpty) return;
      _answerFocusNode.requestFocus();
      _scrollAnswerIntoView();
    }

    if (immediate) {
      focusAndReveal();
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      focusAndReveal();
      Future<void>.delayed(const Duration(milliseconds: 120), focusAndReveal);
    });
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

  void _handleAnswerFocusChange() {
    if (!_answerFocusNode.hasFocus) return;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_answerFocusNode.hasFocus) return;
      _scrollAnswerIntoView();
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted && _answerFocusNode.hasFocus) {
          _scrollAnswerIntoView();
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

  void _rateWord(int quality) {
    if (_dueWords.isEmpty || _currentIndex >= _dueWords.length) return;

    final word = _dueWords[_currentIndex];
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

      _showAnswer = false;
      _isAnswerCorrect = null;
      _answerController.clear();
      _flipController.reset();
      _calculatedIntervals = {};
      _hintLevel = 0;

      if (_currentIndex < _dueWords.length - 1) {
        _currentIndex++;
      } else {
        _isCompleted = true;
      }
    });

    if (!_isCompleted) {
      _requestInputFocus(immediate: true);
    }
  }

  void _showAnswerCard() {
    if (_dueWords.isEmpty || _currentIndex >= _dueWords.length) return;

    _answerFocusNode.unfocus();
    _pageFocusNode.requestFocus();

    final word = _dueWords[_currentIndex];
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
      _isAnswerCorrect =
          _answerController.text.trim().toLowerCase() ==
          (_dueWords[_currentIndex]['word'] ?? '').toString().toLowerCase();
      _calculatedIntervals = intervals;
    });

    _flipController.forward();
    unawaited(_speak((_dueWords[_currentIndex]['word'] ?? '').toString()));
  }

  void _tapHint() {
    if (_showAnswer ||
        _dueWords.isEmpty ||
        _currentIndex >= _dueWords.length) {
      return;
    }
    final word = _dueWords[_currentIndex]['word'] ?? '';
    final wordStr = word.toString();
    final maxHints = (wordStr.length - 2).clamp(0, wordStr.length);
    if (_hintLevel < maxHints) {
      setState(() => _hintLevel++);
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

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

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

    if (_isCompleted) {
      return _buildCompletedScreen();
    }

    final currentWord = _dueWords[_currentIndex];
    final progress = (_currentIndex + 1) / _dueWords.length;

    return KeyboardListener(
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
            onPressed: () => Navigator.pop(context, true),
          ),
          title: Text(
            widget.listName ?? 'Daily Review',
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
          child: Column(
            children: [
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

              // Mastery badge
              if (!keyboardOpen)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: MasteryBadge(level: currentWord['mastery_level'] as int),
                ),

              // Main card â€” expands to fill remaining space
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AnimatedBuilder(
                    animation: _flipAnimation,
                    builder: (context, child) {
                      final showColors = _showAnswer
                          ? (_isAnswerCorrect == true
                              ? [theme.colorScheme.primary, theme.colorScheme.primaryContainer]
                              : [theme.colorScheme.error, theme.colorScheme.error.withAlpha(160)])
                          : [theme.colorScheme.primary, theme.colorScheme.primaryContainer];

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
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
                            ? _buildQuestionCardContent(currentWord, theme, keyboardOpen)
                            : _buildAnswerCardContent(currentWord, theme, keyboardOpen),
                      );
                    },
                  ),
                ),
              ),

              // Bottom section: input + button OR rating buttons
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  keyboardOpen ? 8 : 20,
                ),
                child: !_showAnswer
                    ? _buildInputSection(theme, keyboardOpen)
                    : _buildRatingSection(theme, colors, keyboardOpen),
              ),
            ],
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!compact) ...[
          const Icon(Icons.translate_rounded, color: Colors.white54, size: 28),
          const SizedBox(height: 10),
        ],
        Text(
          'What is the English word?',
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
            style: TextStyle(
              fontSize: compact ? 15 : 18,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
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

  Widget _buildAnswerCardContent(
    Map<String, dynamic> currentWord,
    ThemeData theme,
    bool compact,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _isAnswerCorrect == true ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: _isAnswerCorrect == true ? Colors.greenAccent : Colors.redAccent,
          size: compact ? 32 : 44,
        ),
        SizedBox(height: compact ? 6 : 10),
        Text(
          currentWord['word'] ?? '',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: compact ? 24 : 30,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onPrimary,
            letterSpacing: -0.3,
          ),
        ),
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
        SizedBox(height: compact ? 8 : 12),
        Container(width: 48, height: 2, color: theme.colorScheme.onPrimary.withAlpha(60)),
        SizedBox(height: compact ? 8 : 12),
        Text(
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
        if (_answerController.text.trim().isNotEmpty && _isAnswerCorrect != true) ...[
          SizedBox(height: compact ? 6 : 10),
          Text(
            'You typed: ${_answerController.text}',
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              color: theme.colorScheme.onPrimary.withAlpha(170),
              fontStyle: FontStyle.italic,
              fontFamily: 'Be Vietnam Pro',
            ),
          ),
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

  Widget _buildInputSection(ThemeData theme, bool compact) {
    final wordStr = _dueWords.isNotEmpty
        ? (_dueWords[_currentIndex]['word'] ?? '').toString()
        : '';
    final maxHints = (wordStr.length - 2).clamp(0, wordStr.length);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Text field
        TextField(
          key: _answerFieldKey,
          controller: _answerController,
          focusNode: _answerFocusNode,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
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
            suffixIcon: _answerController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: theme.colorScheme.onSurfaceVariant, size: 18),
                    onPressed: () => setState(() => _answerController.clear()),
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _showAnswerCard(),
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
                          : 'Hint',
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
          onPressed: () => Navigator.pop(context, true),
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
                onPressed: () => Navigator.pop(context, true),
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
