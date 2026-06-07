import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/database_service.dart';
import '../services/srs_service.dart';
import '../services/tts_settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mastery_badge.dart';

class ReviewPage extends StatefulWidget {
  final int userId;
  final int? setId;
  final String? setName;
  final int? groupId;

  const ReviewPage({
    super.key,
    required this.userId,
    this.setId,
    this.setName,
    this.groupId,
  });

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  final SrsService _srs = SrsService();
  final FlutterTts _flutterTts = FlutterTts();
  final TtsSettingsService _ttsSettings = TtsSettingsService();

  final TextEditingController _answerController = TextEditingController();
  final FocusNode _answerFocusNode = FocusNode();
  bool? _isAnswerCorrect;

  List<Map<String, dynamic>> _dueWords = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  bool _showAnswer = false;
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
    _answerController.dispose();
    _answerFocusNode.dispose();
    _flipController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _loadDueWords() async {
    try {
      List<Map<String, dynamic>> words;
      if (widget.groupId != null) {
        words = await _db.getWordsDueForReviewByGroup(widget.groupId!);
      } else if (widget.setId != null) {
        words = await _db.getWordsDueForReview(widget.setId!);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _requestInputFocus() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _answerFocusNode.requestFocus();
    });
  }

  void _queueUpdate(int wordId, SrsResult result) {
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
    if (_dueWords.isEmpty || _currentIndex >= _dueWords.length) return;

    _answerFocusNode.unfocus();

    final word = _dueWords[_currentIndex];
    final intervals = <int, String>{};
    for (final q in [SrsService.qualityAgain, SrsService.qualityHard, SrsService.qualityGood, SrsService.qualityEasy]) {
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
      _isAnswerCorrect = _answerController.text.trim().toLowerCase() == (_dueWords[_currentIndex]['word'] ?? '').toString().toLowerCase();
      _calculatedIntervals = intervals;
    });

    _flipController.forward();
    unawaited(_speak((_dueWords[_currentIndex]['word'] ?? '').toString()));
  }

  String _getMaskedWord(String word) {
    if (word.length <= 2) return word;
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.lingoColors;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
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
          title: Text('Review', style: TextStyle(color: theme.colorScheme.onSurface)),
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
                  child: const Icon(Icons.check_circle, size: 72, color: Colors.green),
                ),
                const SizedBox(height: 24),
                Text(
                  'All caught up!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 12),
                Text(
                  'No words are due for review right now.\nKeep learning new words!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurfaceVariant),
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

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(
          widget.setName ?? 'Daily Review',
          style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
        ),
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
                  '${_currentIndex + 1} / ${_dueWords.length}',
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: theme.colorScheme.primaryContainer.withAlpha(51),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  minHeight: 6,
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 500;
                  final cardPadding = compact ? 14.0 : 20.0;
                  final cardMaxH = compact ? 200.0 : 300.0;
                  final cardMinH = compact ? 120.0 : 180.0;
                  final meaningFont = compact ? 17.0 : 22.0;
                  final maskedFont = compact ? 14.0 : 18.0;
                  final inputFont = compact ? 17.0 : 20.0;
                  final hintFont = compact ? 13.0 : 16.0;
                  final inputVPad = compact ? 10.0 : 16.0;
                  final gap = compact ? 8.0 : 16.0;
                  final btnH = compact ? 44.0 : 52.0;
                  final btnFont = compact ? 14.0 : 16.0;
                  final iconSize = compact ? 24.0 : 32.0;
                  final ansWordFont = compact ? 22.0 : 28.0;
                  final ansMeanFont = compact ? 16.0 : 19.0;
                  final subtitleFont = compact ? 12.0 : 14.0;

                  return SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(24, compact ? 4 : 16, 24, 16),
                    child: Column(
                      children: [
                        if (!compact) ...[
                          const SizedBox(height: 8),
                          MasteryBadge(level: currentWord['mastery_level'] as int),
                          SizedBox(height: gap),
                        ],
                        AnimatedBuilder(
                          animation: _flipAnimation,
                          builder: (context, child) {
                            final showColors = _showAnswer
                                ? (_isAnswerCorrect == true
                                    ? [theme.colorScheme.primary, theme.colorScheme.primaryContainer]
                                    : [theme.colorScheme.error, theme.colorScheme.error.withAlpha(179)])
                                : [theme.colorScheme.primary, theme.colorScheme.primaryContainer];
                            return Container(
                              width: double.infinity,
                              constraints: BoxConstraints(minHeight: cardMinH, maxHeight: cardMaxH),
                              padding: EdgeInsets.all(cardPadding),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: showColors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: (showColors[0]).withAlpha(76),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (!_showAnswer) ...[
                                    if (!compact) const Icon(Icons.translate, color: Colors.white54, size: 32),
                                    SizedBox(height: compact ? 0 : 8),
                                    Text('What is the English word?', style: TextStyle(color: theme.colorScheme.onPrimary.withAlpha(179), fontSize: compact ? 12 : 14)),
                                    SizedBox(height: compact ? 4 : 10),
                                    Text(
                                      currentWord['meaning'] ?? '',
                                      textAlign: TextAlign.center,
                                      maxLines: compact ? 1 : 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: meaningFont, fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimary, letterSpacing: 0.5),
                                    ),
                                    SizedBox(height: compact ? 6 : 16),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: compact ? 3 : 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withAlpha(25),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _getMaskedWord(currentWord['word'] ?? ''),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: maskedFont,
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
                                        decoration: BoxDecoration(color: theme.colorScheme.onPrimary.withAlpha(38), borderRadius: BorderRadius.circular(12)),
                                        child: Text(currentWord['set_name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.colorScheme.onPrimary.withAlpha(153), fontSize: 12)),
                                      ),
                                    ],
                                    SizedBox(height: compact ? 8 : 20),
                                    TextField(
                                      controller: _answerController,
                                      focusNode: _answerFocusNode,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: inputFont, fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimary),
                                      decoration: InputDecoration(
                                        hintText: 'Type English word...',
                                        hintStyle: TextStyle(color: theme.colorScheme.onPrimary.withAlpha(128), fontSize: hintFont),
                                        filled: true,
                                        fillColor: Colors.black.withAlpha(51),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: inputVPad),
                                      ),
                                      onSubmitted: (_) => _showAnswerCard(),
                                    ),
                                  ] else ...[
                                    Icon(_isAnswerCorrect == true ? Icons.check_circle : Icons.cancel, color: _isAnswerCorrect == true ? Colors.greenAccent : Colors.redAccent, size: compact ? 28 : 40),
                                    SizedBox(height: compact ? 4 : 8),
                                    Text(currentWord['word'] ?? '', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: ansWordFont, fontWeight: FontWeight.w800, color: theme.colorScheme.onPrimary)),
                                    if ((currentWord['pronunciation'] ?? '').isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text('/${currentWord['pronunciation']}/', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: compact ? 12 : 14, color: theme.colorScheme.onPrimary.withAlpha(179), fontStyle: FontStyle.italic)),
                                    ],
                                    SizedBox(height: compact ? 4 : 8),
                                    Container(width: 60, height: 2, color: theme.colorScheme.onPrimary.withAlpha(76)),
                                    SizedBox(height: compact ? 6 : 10),
                                    Text(currentWord['meaning'] ?? '', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: ansMeanFont, fontWeight: FontWeight.w600, color: theme.colorScheme.onPrimary)),
                                    if (_answerController.text.trim().isNotEmpty && _isAnswerCorrect != true) ...[
                                      SizedBox(height: compact ? 4 : 10),
                                      Text('You typed: ${_answerController.text}', style: TextStyle(fontSize: subtitleFont, color: theme.colorScheme.onPrimary.withAlpha(179), fontStyle: FontStyle.italic)),
                                    ],
                                    if ((currentWord['full_details'] ?? '').isNotEmpty && !compact) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: theme.colorScheme.onPrimary.withAlpha(38), borderRadius: BorderRadius.circular(12)),
                                        child: Text(currentWord['full_details'], textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: theme.colorScheme.onPrimary.withAlpha(179), height: 1.4)),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                        SizedBox(height: gap),
                        if (!_showAnswer) ...[
                          SizedBox(
                            width: double.infinity,
                            height: btnH,
                            child: ElevatedButton.icon(
                              onPressed: _showAnswerCard,
                              icon: Icon(Icons.check, color: theme.colorScheme.onPrimary, size: compact ? 18 : 22),
                              label: Text('Check Answer', style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: btnFont)),
                              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 4),
                            ),
                          ),
                        ] else ...[
                          Text('How well did you remember?', style: TextStyle(fontSize: compact ? 13 : 16, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                          SizedBox(height: compact ? 6 : 12),
                          LayoutBuilder(
                            builder: (context, buttonConstraints) {
                              final useWrap = buttonConstraints.maxWidth < 380;
                              if (useWrap) {
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    SizedBox(width: (buttonConstraints.maxWidth - 8) / 2, child: _buildRateButton(label: 'Again', emoji: 'A', subtitle: _calculatedIntervals[SrsService.qualityAgain] ?? '', color: theme.colorScheme.error, onTap: () => _rateWord(SrsService.qualityAgain))),
                                    SizedBox(width: (buttonConstraints.maxWidth - 8) / 2, child: _buildRateButton(label: 'Hard', emoji: 'H', subtitle: _calculatedIntervals[SrsService.qualityHard] ?? '', color: colors.masteryReviewing, onTap: () => _rateWord(SrsService.qualityHard))),
                                    SizedBox(width: (buttonConstraints.maxWidth - 8) / 2, child: _buildRateButton(label: 'Good', emoji: 'G', subtitle: _calculatedIntervals[SrsService.qualityGood] ?? '', color: colors.masteryMastered, onTap: () => _rateWord(SrsService.qualityGood))),
                                    SizedBox(width: (buttonConstraints.maxWidth - 8) / 2, child: _buildRateButton(label: 'Easy', emoji: 'E', subtitle: _calculatedIntervals[SrsService.qualityEasy] ?? '', color: colors.masteryLearning, onTap: () => _rateWord(SrsService.qualityEasy))),
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: _buildRateButton(label: 'Again', emoji: '😣', subtitle: _calculatedIntervals[SrsService.qualityAgain] ?? '', color: theme.colorScheme.error, onTap: () => _rateWord(SrsService.qualityAgain))),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildRateButton(label: 'Hard', emoji: '🤔', subtitle: _calculatedIntervals[SrsService.qualityHard] ?? '', color: colors.masteryReviewing, onTap: () => _rateWord(SrsService.qualityHard))),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildRateButton(label: 'Good', emoji: '👍', subtitle: _calculatedIntervals[SrsService.qualityGood] ?? '', color: colors.masteryMastered, onTap: () => _rateWord(SrsService.qualityGood))),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildRateButton(label: 'Easy', emoji: '🌟', subtitle: _calculatedIntervals[SrsService.qualityEasy] ?? '', color: colors.masteryLearning, onTap: () => _rateWord(SrsService.qualityEasy))),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
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

  Widget _buildRateButton({
    required String label,
    required String emoji,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          border: Border.all(color: color.withAlpha(76), width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: color.withAlpha(179))),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedScreen() {
    final theme = Theme.of(context);
    final percentage = _totalReviewed > 0
        ? ((_sessionResults.where((r) => (r['quality'] as int) >= 3).length / _totalReviewed) * 100).round()
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
                gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.primaryContainer], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: theme.colorScheme.primary.withAlpha(76), blurRadius: 24, offset: const Offset(0, 12))],
              ),
              child: Column(
                children: [
                  Icon(Icons.emoji_events, size: 64, color: theme.colorScheme.secondary),
                  const SizedBox(height: 12),
                  Text('Review Complete!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: theme.colorScheme.onPrimary)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem('Reviewed', '$_totalReviewed', theme.colorScheme.onPrimary),
                      _buildStatItem('Accuracy', '$percentage%', theme.colorScheme.onPrimary),
                      _buildStatItem('Level Up', '+$_masteryUps', Colors.greenAccent),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_sessionResults.isNotEmpty) ...[
              Align(alignment: Alignment.centerLeft, child: Text('Session Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))),
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
                  decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(12), border: Border.all(color: quality >= 3 ? Colors.green.withAlpha(51) : theme.colorScheme.error.withAlpha(51))),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: quality >= 3 ? Colors.green.withAlpha(25) : theme.colorScheme.error.withAlpha(25), shape: BoxShape.circle),
                        child: Center(child: Icon(quality >= 3 ? Icons.check : Icons.replay, color: quality >= 3 ? Colors.green : theme.colorScheme.error, size: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r['word'] as String, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                            if (levelChanged)
                              Text('${SrsService.masteryName(oldLevel)} -> ${SrsService.masteryName(newLevel)}', style: TextStyle(fontSize: 12, color: newLevel > oldLevel ? Colors.green : Colors.orange, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Text('Next: ${interval}d', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
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
                style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text('Done', style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
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
        Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color.withAlpha(204))),
      ],
    );
  }
}
