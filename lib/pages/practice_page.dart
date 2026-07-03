import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/database_service.dart';
import '../services/srs_service.dart';
import '../services/tts_settings_service.dart';
import '../widgets/mastery_badge.dart';
import '../widgets/confetti_overlay.dart';

class PracticePage extends StatefulWidget {
  final int listId;
  final String listName;
  final int userId;
  final String? category;
  final bool studyMode;

  const PracticePage({
    super.key,
    this.listId = 0,
    required this.listName,
    required this.userId,
    this.studyMode = true,
    this.category,
  });

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final DatabaseService _db = DatabaseService();
  final SrsService _srs = SrsService();
  List<Map<String, dynamic>> _words = [];
  bool _isLoading = true;

  int _currentIndex = 0;
  int _score = 0;
  int _totalAnswered = 0;
  bool _isCompleted = false;
  bool _showConfetti = false;
  String? _selectedAnswer;
  bool _showResult = false;
  DateTime? _questionStartTime;

  int _masteryUps = 0;
  final List<Map<String, dynamic>> _sessionResults = [];
  final List<Future<void>> _pendingReviewUpdates = [];
  final List<Map<String, dynamic>> _retryWords = [];

  final TextEditingController _spellController = TextEditingController();
  final FocusNode _spellFocusNode = FocusNode();
  final FlutterTts _flutterTts = FlutterTts();
  final TtsSettingsService _ttsSettings = TtsSettingsService();
  int _practiceMode = 0;
  int _hintLevel = 0;
  List<String> _currentOptions = [];

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadWords();
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
      debugPrint('Practice TTS error: $e');
    }
  }

  void _focusSpellInputIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _showResult || _isCompleted || _practiceMode != 1) return;
      _spellFocusNode.requestFocus();
    });
  }

  void _generateCurrentOptions() {
    if (_words.isEmpty || _currentIndex >= _words.length) {
      _currentOptions = [];
      return;
    }
    final currentWord = _words[_currentIndex]['word'];
    final options = <String>{currentWord};

    final int targetLength = min(4, _words.length);
    while (options.length < targetLength) {
      final random = _words[Random().nextInt(_words.length)];
      if (random['word'] != currentWord) {
        options.add(random['word']);
      }
    }

    final list = options.toList();
    list.shuffle(Random());
    _currentOptions = list;
  }

  Future<void> _loadWords() async {
    try {
      final List<Map<String, dynamic>> wordsResult;
      if (widget.category != null) {
        wordsResult = await _db.getWordsByCategory(widget.userId, widget.category!);
      } else {
        wordsResult = await _db.getVocabularyWords(widget.listId);
      }
      final words = List<Map<String, dynamic>>.from(wordsResult);
      words.shuffle(Random());
      setState(() {
        _words = words;
        _isLoading = false;
        _questionStartTime = DateTime.now();
        _generateCurrentOptions();
      });
      _focusSpellInputIfNeeded();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _nextQuestion() {
    setState(() {
      _showResult = false;
      _selectedAnswer = null;
      _spellController.clear();
      _spellFocusNode.unfocus();
      _questionStartTime = DateTime.now();
      _hintLevel = 0;

      if (_words.isEmpty) return;

      if (_currentIndex < _words.length - 1) {
        _currentIndex++;
        _generateCurrentOptions();
      } else if (widget.studyMode && _retryWords.isNotEmpty) {
        _words = List<Map<String, dynamic>>.from(_retryWords);
        _words.shuffle(Random());
        _retryWords.clear();
        _currentIndex = 0;
        _generateCurrentOptions();
      } else {
        _isCompleted = true;
        _showConfetti = true;
        if (!widget.studyMode) {
          unawaited(() async {
            await _flushPendingUpdates();
            await _updateListProgress();
          }());
        }
      }
    });
    if (!_isCompleted) {
      _focusSpellInputIfNeeded();
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

  void _queueReviewUpdate({required int wordId, required SrsResult result}) {
    final future = _db.updateWordReview(
      wordId: wordId,
      reviewCount: result.newReviewCount,
      correctStreak: result.newCorrectStreak,
      easeFactor: result.newEaseFactor,
      intervalDays: result.newInterval,
      nextReviewDate: result.nextReviewDate,
      masteryLevel: result.newMasteryLevel,
      lapseCount: result.newLapseCount,
    ).catchError((e) {
      debugPrint('Failed to save review update: $e');
    });

    _pendingReviewUpdates.add(future);
    future.whenComplete(() => _pendingReviewUpdates.remove(future));
  }

  Future<void> _flushPendingUpdates() async {
    if (_pendingReviewUpdates.isEmpty) return;
    final pending = List<Future<void>>.from(_pendingReviewUpdates);
    await Future.wait(pending);
  }

  Future<void> _checkAnswer(String answer) async {
    if (_words.isEmpty || _showResult) return;
    final word = _words[_currentIndex];
    final correct = word['word'];
    final isCorrect = answer.toLowerCase() == correct.toLowerCase();

    if (widget.studyMode) {
      if (!isCorrect) {
        _retryWords.add(Map<String, dynamic>.from(word));
      }
      setState(() {
        _selectedAnswer = answer;
        _showResult = true;
        _totalAnswered++;
        if (isCorrect) _score++;
      });
      unawaited(_speak(correct));
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

    _queueReviewUpdate(wordId: word['id'] as int, result: result);

    if (result.newMasteryLevel > oldMastery) _masteryUps++;

    _sessionResults.add({
      'word': correct,
      'isCorrect': isCorrect,
      'oldMastery': oldMastery,
      'newMastery': result.newMasteryLevel,
      'nextInterval': result.newInterval,
    });

    setState(() {
      _selectedAnswer = answer;
      _showResult = true;
      _totalAnswered++;
      if (isCorrect) _score++;
    });
    unawaited(_speak(correct));
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
      _spellFocusNode.unfocus();
      unawaited(_speak(correct));
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

    _queueReviewUpdate(wordId: word['id'] as int, result: result);

    if (result.newMasteryLevel > oldMastery) _masteryUps++;

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
    _spellFocusNode.unfocus();
    unawaited(_speak(correct));
  }

  void _restart() {
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _totalAnswered = 0;
      _isCompleted = false;
      _showConfetti = false;
      _selectedAnswer = null;
      _showResult = false;
      _spellController.clear();
      _words.shuffle(Random());
      _masteryUps = 0;
      _sessionResults.clear();
      _retryWords.clear();
      _questionStartTime = DateTime.now();
      _generateCurrentOptions();
    });
  }

  void _handleKeyOption(int index) {
    if (_practiceMode == 0 && !_showResult && !_isCompleted && index < _currentOptions.length) {
      _checkAnswer(_currentOptions[index]);
    }
  }

  void _tapHint() {
    if (_showResult ||
        _words.isEmpty ||
        _currentIndex >= _words.length ||
        _practiceMode != 1) {
      return;
    }
    final word = _words[_currentIndex]['word'] ?? '';
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
  void dispose() {
    _spellController.dispose();
    _spellFocusNode.dispose();
    _flutterTts.stop();
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

    if (_words.isEmpty) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(widget.listName, style: TextStyle(color: theme.colorScheme.onSurface)),
        ),
        body: const Center(child: Text('No words to study')),
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
            onPressed: () => Navigator.pop(context, true),
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
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary, theme.colorScheme.primaryContainer],
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
                    Icon(Icons.celebration, size: 64, color: theme.colorScheme.secondary),
                    const SizedBox(height: 16),
                    Text(
                      widget.studyMode ? 'Learned!' : 'Completed!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn('Score', '$_score/$_totalAnswered', theme.colorScheme.onPrimary),
                        _buildStatColumn('Accuracy', '$percentage%', theme.colorScheme.secondary),
                        _buildStatColumn(
                          widget.studyMode ? 'Wrong Loop' : 'Level Up',
                          widget.studyMode ? '${_totalAnswered - _score}' : '+$_masteryUps',
                          widget.studyMode ? Colors.orangeAccent : Colors.greenAccent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (!widget.studyMode && _sessionResults.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.primaryContainer.withAlpha(51)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mastery Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._sessionResults.where((r) => r['oldMastery'] != r['newMastery']).map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                (r['newMastery'] as int) > (r['oldMastery'] as int) ? Icons.arrow_upward : Icons.arrow_downward,
                                size: 16,
                                color: (r['newMastery'] as int) > (r['oldMastery'] as int) ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${r['word']}: ${SrsService.masteryName(r['oldMastery'])} -> ${SrsService.masteryName(r['newMastery'])}',
                                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_sessionResults.every((r) => r['oldMastery'] == r['newMastery']))
                        Text(
                          'No mastery level changes this session.',
                          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
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
                  child: Text(
                    widget.studyMode ? 'Learn Again' : 'Practice Again',
                    style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    }

    final currentWord = _words[_currentIndex];
    final meaning = currentWord['meaning'];
    final options = _currentOptions;
    final masteryLevel = currentWord['mastery_level'] as int? ?? 0;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.digit1): () => _handleKeyOption(0),
        const SingleActivator(LogicalKeyboardKey.digit2): () => _handleKeyOption(1),
        const SingleActivator(LogicalKeyboardKey.digit3): () => _handleKeyOption(2),
        const SingleActivator(LogicalKeyboardKey.digit4): () => _handleKeyOption(3),
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
          onPressed: () => Navigator.pop(context, true),
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
            Container(
              margin: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _spellFocusNode.unfocus();
                        setState(() => _practiceMode = 0);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _practiceMode == 0 ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _practiceMode == 0 ? theme.colorScheme.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Multiple Choice',
                            style: TextStyle(
                              color: _practiceMode == 0 ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _practiceMode = 1);
                        _focusSpellInputIfNeeded();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _practiceMode == 1 ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _practiceMode == 1 ? theme.colorScheme.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Spell',
                            style: TextStyle(
                              color: _practiceMode == 1 ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = keyboardOpen || constraints.maxHeight < 620;
                  final contentPadding = compact ? 18.0 : 24.0;
                  final sectionGap = compact ? 14.0 : 20.0;
                  final cardPadding = compact ? 18.0 : 24.0;
                  final optionPadding = compact ? 12.0 : 16.0;
                  final titleFont = compact ? 21.0 : 24.0;
                  final maskedFont = compact ? 26.0 : 32.0;

                  final content = Padding(
                    padding: EdgeInsets.fromLTRB(contentPadding, keyboardOpen ? 8 : 12, contentPadding, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(cardPadding),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withAlpha(51),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              MasteryBadge(level: masteryLevel),
                              SizedBox(height: compact ? 8 : 12),
                              Text(
                                'What is the English word for:',
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              ),
                              SizedBox(height: compact ? 8 : 12),
                              Text(
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
                              if (_showResult) ...[
                                SizedBox(height: compact ? 12 : 16),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: compact ? 12 : 16,
                                    vertical: compact ? 8 : 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        currentWord['word'],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: compact ? 20 : 22, fontWeight: FontWeight.bold, color: Colors.green),
                                      ),
                                      if ((currentWord['pronunciation'] ?? '').isNotEmpty)
                                        Text(
                                          '/${currentWord['pronunciation']}/',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: sectionGap),
                        if (_practiceMode == 0) ...[
                          Text(
                            'Select the correct word:',
                            style: TextStyle(
                              fontSize: compact ? 15 : 16,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: compact ? 10 : 14),
                          ...List.generate(options.length, (index) {
                            final option = options[index];
                            final isSelected = _selectedAnswer == option;
                            final isCorrect = option == currentWord['word'];

                            Color bgColor = theme.colorScheme.surfaceContainerLowest;
                            Color borderColor = theme.colorScheme.outlineVariant;
                            Color textColor = theme.colorScheme.onSurface;

                            if (_showResult) {
                              if (isCorrect) {
                                bgColor = Colors.green.withAlpha(51);
                                borderColor = Colors.green;
                                textColor = Colors.green;
                              } else if (isSelected && !isCorrect) {
                                bgColor = Colors.red.withAlpha(51);
                                borderColor = Colors.red;
                                textColor = Colors.red;
                              }
                            } else if (isSelected) {
                              bgColor = theme.colorScheme.primaryContainer.withAlpha(51);
                              borderColor = theme.colorScheme.primary;
                            }

                            return Padding(
                              padding: EdgeInsets.only(bottom: compact ? 8 : 10),
                              child: GestureDetector(
                                onTap: _showResult ? null : () => _checkAnswer(option),
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(optionPadding),
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    border: Border.all(color: borderColor, width: 2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: compact ? 28 : 32,
                                        height: compact ? 28 : 32,
                                        decoration: BoxDecoration(
                                          color: borderColor.withAlpha(51),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: compact ? 10 : 12),
                                      Expanded(
                                        child: Text(
                                          option,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: compact ? 15 : 16,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          if (!widget.studyMode && _showResult && _sessionResults.isNotEmpty) ...[
                            SizedBox(height: compact ? 8 : 10),
                            _buildSrsFeedback(_sessionResults.last),
                          ],
                        ] else ...[
                          Text(
                            'Spell the word:',
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
                          if (!_showResult) ...[
                            const SizedBox(height: 6),
                            _buildPracticeHintButton(currentWord),
                            const SizedBox(height: 6),
                          ] else
                            SizedBox(height: compact ? 10 : 14),
                          TextField(
                            controller: _spellController,
                            focusNode: _spellFocusNode,
                            decoration: InputDecoration(
                              hintText: 'Type your answer',
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
                            onSubmitted: _showResult ? null : (_) => _checkSpell(),
                          ),
                          SizedBox(height: compact ? 10 : 14),
                          if (_showResult) ...[
                            Container(
                              padding: EdgeInsets.all(compact ? 12 : 16),
                              decoration: BoxDecoration(
                                color: _spellController.text.toLowerCase() == currentWord['word'].toLowerCase()
                                    ? Colors.green.withAlpha(51)
                                    : Colors.red.withAlpha(51),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _spellController.text.toLowerCase() == currentWord['word'].toLowerCase()
                                        ? Icons.check_circle : Icons.cancel,
                                    color: _spellController.text.toLowerCase() == currentWord['word'].toLowerCase()
                                        ? Colors.green : Colors.red,
                                  ),
                                  SizedBox(width: compact ? 10 : 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _spellController.text.toLowerCase() == currentWord['word'].toLowerCase()
                                              ? 'Correct!' : 'Wrong!',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: _spellController.text.toLowerCase() == currentWord['word'].toLowerCase()
                                                ? Colors.green : Colors.red,
                                          ),
                                        ),
                                        Text(
                                          'Answer: ${currentWord['word']}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!widget.studyMode && _sessionResults.isNotEmpty) ...[
                              SizedBox(height: compact ? 8 : 10),
                              _buildSrsFeedback(_sessionResults.last),
                            ],
                          ],
                        ],
                        const Spacer(),
                        if (_showResult)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _nextQuestion,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                padding: EdgeInsets.symmetric(vertical: compact ? 14 : 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                _currentIndex < _words.length - 1 ? 'Next' : 'Finish',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );

                  return SingleChildScrollView(
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
            _hintLevel > 0 ? 'Goi y ($_hintLevel/$maxHints)' : 'Goi y',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE6A800),
            backgroundColor: canHint
                ? const Color(0xFFE6A800).withAlpha(20)
                : Colors.transparent,
            side: BorderSide(
              color: canHint
                  ? const Color(0xFFE6A800).withAlpha(120)
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
                  'Next review: in ${nextInterval}d',
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

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color.withAlpha(204))),
      ],
    );
  }
}



