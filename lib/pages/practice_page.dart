import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/database_service.dart';
import '../services/srs_service.dart';
import '../services/tts_settings_service.dart';

class PracticePage extends StatefulWidget {
  final int setId;
  final String setName;
  final int userId;
  final bool studyMode;

  const PracticePage({
    super.key,
    required this.setId,
    required this.setName,
    required this.userId,
    this.studyMode = true,
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
  String? _selectedAnswer;
  bool _showResult = false;
  DateTime? _questionStartTime;

  // SRS tracking
  int _masteryUps = 0;
  int _masteryDowns = 0;
  final List<Map<String, dynamic>> _sessionResults = [];
  final List<Future<void>> _pendingReviewUpdates = [];
  final List<Map<String, dynamic>> _retryWords = [];

  final TextEditingController _spellController = TextEditingController();
  final FocusNode _spellFocusNode = FocusNode();
  final FlutterTts _flutterTts = FlutterTts();
  final TtsSettingsService _ttsSettings = TtsSettingsService();
  int _practiceMode = 0;

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

  Future<void> _loadWords() async {
    try {
      final wordsResult = await _db.getVocabularyWords(widget.setId);
      final words = List<Map<String, dynamic>>.from(wordsResult);
      words.shuffle(Random());
      setState(() {
        _words = words;
        _isLoading = false;
        _questionStartTime = DateTime.now();
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
        if (!widget.studyMode) {
          unawaited(() async {
            await _flushPendingUpdates();
            await _updateSetProgress();
          }());
        }
      }
    });
    if (!_isCompleted) {
      _focusSpellInputIfNeeded();
    }
  }

  Future<void> _updateSetProgress() async {
    try {
      final words = await _db.getVocabularyWords(widget.setId);
      final total = words.length;
      final mastered = words.where((w) => (w['mastery_level'] ?? 0) >= 3).length;
      final progress = total > 0 ? ((mastered / total) * 100).round() : 0;
      await _db.updateVocabularySetProgress(widget.setId, progress, total);
    } catch (e) {
      debugPrint('Failed to update set progress: $e');
    }
  }

  void _queueReviewUpdate({
    required int wordId,
    required SrsResult result,
  }) {
    final future = _db.updateWordReview(
      wordId: wordId,
      reviewCount: result.newReviewCount,
      correctStreak: result.newCorrectStreak,
      easeFactor: result.newEaseFactor,
      intervalDays: result.newInterval,
      nextReviewDate: result.nextReviewDate,
      masteryLevel: result.newMasteryLevel,
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

    // Calculate response time
    final responseTimeMs = _questionStartTime != null
        ? DateTime.now().difference(_questionStartTime!).inMilliseconds
        : 5000;

    // Convert practice result to SRS quality
    final quality = _srs.practiceResultToQuality(isCorrect, responseTimeMs: responseTimeMs);
    final oldMastery = word['mastery_level'] as int? ?? 0;

    // Calculate SRS
    final result = _srs.calculateNextReview(
      quality: quality,
      currentInterval: word['interval_days'] as int? ?? 0,
      easeFactor: ((word['ease_factor'] ?? 2.5) as num).toDouble(),
      correctStreak: word['correct_streak'] as int? ?? 0,
      reviewCount: word['review_count'] as int? ?? 0,
    );

    // Persist in background so UI can show result immediately.
    _queueReviewUpdate(wordId: word['id'] as int, result: result);

    // Track stats
    if (result.newMasteryLevel > oldMastery) _masteryUps++;
    if (result.newMasteryLevel < oldMastery) _masteryDowns++;

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
    );

    _queueReviewUpdate(wordId: word['id'] as int, result: result);

    if (result.newMasteryLevel > oldMastery) _masteryUps++;
    if (result.newMasteryLevel < oldMastery) _masteryDowns++;

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

  List<String> _generateOptions() {
    if (_words.isEmpty) return [];
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
    return list;
  }

  void _restart() {
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _totalAnswered = 0;
      _isCompleted = false;
      _selectedAnswer = null;
      _showResult = false;
      _spellController.clear();
      _words.shuffle(Random());
      _masteryUps = 0;
      _masteryDowns = 0;
      _sessionResults.clear();
      _retryWords.clear();
      _questionStartTime = DateTime.now();
    });
  }

  String _getMaskedWord(String word) {
    if (word.length <= 2) return word; // Cho từ quá ngắn
    final first = word[0];
    final last = word[word.length - 1];
    final underscores = List.filled(word.length - 2, '_').join(' ');
    // Nếu từ có khoảng trắng ở giữa thì sao? (vd: 'ice cream')
    // Xử lý đơn giản: thay toàn bộ chữ ở giữa bằng _
    String masked = '';
    for (int i = 0; i < word.length; i++) {
      if (i == 0 || i == word.length - 1 || word[i] == ' ') {
        masked += word[i];
      } else {
        masked += ' _ ';
      }
    }
    return masked.replaceAll('  ', ' ').trim();
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
    const Color primary = Color(0xFF4a40e0);
    const Color primaryContainer = Color(0xFF9795ff);
    const Color surface = Color(0xFFfaf4ff);
    const Color surfaceContainerLow = Color(0xFFf5eeff);
    const Color onSurface = Color(0xFF32294f);
    const Color onSurfaceVariant = Color(0xFF5f557f);
    const Color secondaryContainer = Color(0xFFfed01b);
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_words.isEmpty) {
      return Scaffold(
        backgroundColor: surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: primary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(widget.setName, style: const TextStyle(color: onSurface)),
        ),
        body: const Center(
          child: Text('No words to study'),
        ),
      );
    }

    if (_isCompleted) {
      final percentage = _totalAnswered > 0 ? (_score * 100 / _totalAnswered).round() : 0;
      return Scaffold(
        backgroundColor: surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: primary),
            onPressed: () => Navigator.pop(context, true),
          ),
          title: Text(widget.setName, style: const TextStyle(color: onSurface)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Trophy card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primary, primaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.celebration, size: 64, color: secondaryContainer),
                    const SizedBox(height: 16),
                     Text(
                       widget.studyMode ? 'Learned!' : 'Completed!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn('Score', '$_score/$_totalAnswered', Colors.white),
                        _buildStatColumn('Accuracy', '$percentage%', secondaryContainer),
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
              // SRS info
              if (!widget.studyMode && _sessionResults.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryContainer.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📊 Mastery Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._sessionResults.where((r) => r['oldMastery'] != r['newMastery']).map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                (r['newMastery'] as int) > (r['oldMastery'] as int)
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                size: 16,
                                color: (r['newMastery'] as int) > (r['oldMastery'] as int)
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${r['word']}: ${SrsService.masteryName(r['oldMastery'])} → ${SrsService.masteryName(r['newMastery'])}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_sessionResults.every((r) => r['oldMastery'] == r['newMastery']))
                        Text(
                          'No mastery level changes this session.',
                          style: TextStyle(
                            fontSize: 13,
                            color: onSurfaceVariant,
                          ),
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
                    backgroundColor: primary,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    widget.studyMode ? 'Learn Again' : 'Practice Again',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentWord = _words[_currentIndex];
    final meaning = currentWord['meaning'];
    final options = _generateOptions();
    final masteryLevel = currentWord['mastery_level'] as int? ?? 0;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primary),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(widget.setName, style: const TextStyle(color: onSurface)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1}/${_words.length}',
                  style: const TextStyle(color: primary, fontWeight: FontWeight.bold),
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
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_currentIndex + 1) / _words.length,
                backgroundColor: primaryContainer.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(primary),
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
                        color: _practiceMode == 0 ? primary : surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _practiceMode == 0 ? primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Multiple Choice',
                          style: TextStyle(
                            color: _practiceMode == 0 ? Colors.white : onSurface,
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
                        color: _practiceMode == 1 ? primary : surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _practiceMode == 1 ? primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Spell',
                          style: TextStyle(
                            color: _practiceMode == 1 ? Colors.white : onSurface,
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
                          color: primaryContainer.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildMasteryBadge(masteryLevel),
                            SizedBox(height: compact ? 8 : 12),
                            const Text(
                              'What is the English word for:',
                              style: TextStyle(color: onSurfaceVariant),
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
                                color: primary,
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
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      currentWord['word'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: compact ? 20 : 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    if ((currentWord['pronunciation'] ?? '').isNotEmpty)
                                      Text(
                                        '/${currentWord['pronunciation']}/',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: onSurfaceVariant),
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
                            color: onSurface,
                          ),
                        ),
                        SizedBox(height: compact ? 10 : 14),
                        ...List.generate(options.length, (index) {
                          final option = options[index];
                          final isSelected = _selectedAnswer == option;
                          final isCorrect = option == currentWord['word'];

                          Color bgColor = Colors.white;
                          Color borderColor = const Color(0xFFb2a6d5);
                          Color textColor = onSurface;

                          if (_showResult) {
                            if (isCorrect) {
                              bgColor = Colors.green.withValues(alpha: 0.2);
                              borderColor = Colors.green;
                              textColor = Colors.green;
                            } else if (isSelected && !isCorrect) {
                              bgColor = Colors.red.withValues(alpha: 0.2);
                              borderColor = Colors.red;
                              textColor = Colors.red;
                            }
                          } else if (isSelected) {
                            bgColor = primaryContainer.withValues(alpha: 0.2);
                            borderColor = primary;
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
                                        color: borderColor.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          String.fromCharCode(65 + index),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
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
                            color: onSurface,
                          ),
                        ),
                        SizedBox(height: compact ? 10 : 14),
                        Container(
                          padding: EdgeInsets.all(compact ? 18 : 24),
                          decoration: BoxDecoration(
                            color: surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              _getMaskedWord(currentWord['word']),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: maskedFont,
                                letterSpacing: 2,
                                fontWeight: FontWeight.bold,
                                color: primary,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 10 : 14),
                        TextField(
                          controller: _spellController,
                          focusNode: _spellFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Type your answer',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: compact ? 12 : 14,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFb2a6d5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: primary, width: 2),
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
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _spellController.text.toLowerCase() == currentWord['word'].toLowerCase()
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: _spellController.text.toLowerCase() == currentWord['word'].toLowerCase()
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                SizedBox(width: compact ? 10 : 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _spellController.text.toLowerCase() == currentWord['word'].toLowerCase()
                                            ? 'Correct!'
                                            : 'Wrong!',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _spellController.text.toLowerCase() == currentWord['word'].toLowerCase()
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                      Text(
                                        'Answer: ${currentWord['word']}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: onSurfaceVariant),
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
                              backgroundColor: primary,
                              padding: EdgeInsets.symmetric(vertical: compact ? 14 : 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _currentIndex < _words.length - 1 ? 'Next' : 'Finish',
                              style: const TextStyle(
                                color: Colors.white,
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
                    child: IntrinsicHeight(
                      child: content,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildMasteryBadge(int level) {
    final config = _getMasteryConfig(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: (config['color'] as Color).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config['icon'] as IconData, size: 14, color: config['color'] as Color),
          const SizedBox(width: 4),
          Text(
            config['label'] as String,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: config['color'] as Color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSrsFeedback(Map<String, dynamic> result) {
    final oldMastery = result['oldMastery'] as int;
    final newMastery = result['newMastery'] as int;
    final nextInterval = result['nextInterval'] as int;
    final levelChanged = newMastery != oldMastery;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFf5eeff),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9795ff).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 18, color: Color(0xFF4a40e0)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next review: in ${nextInterval}d',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4a40e0),
                  ),
                ),
                if (levelChanged)
                  Text(
                    '${SrsService.masteryName(oldMastery)} → ${SrsService.masteryName(newMastery)}',
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

  Map<String, dynamic> _getMasteryConfig(int level) {
    switch (level) {
      case 0:
        return {'label': 'New', 'color': Colors.grey, 'icon': Icons.fiber_new};
      case 1:
        return {'label': 'Learning', 'color': const Color(0xFF1e88e5), 'icon': Icons.menu_book};
      case 2:
        return {'label': 'Reviewing', 'color': const Color(0xFFfb8c00), 'icon': Icons.refresh};
      case 3:
        return {'label': 'Mastered', 'color': const Color(0xFF43a047), 'icon': Icons.star};
      default:
        return {'label': 'Unknown', 'color': Colors.grey, 'icon': Icons.help};
    }
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
