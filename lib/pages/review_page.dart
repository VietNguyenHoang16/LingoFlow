import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/database_service.dart';
import '../services/srs_service.dart';
import '../services/tts_settings_service.dart';

class ReviewPage extends StatefulWidget {
  final int userId;
  final int? setId;
  final String? setName;

  const ReviewPage({
    super.key,
    required this.userId,
    this.setId,
    this.setName,
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

  // Session stats
  int _totalReviewed = 0;
  int _masteryUps = 0;
  int _masteryDowns = 0;
  final List<Map<String, dynamic>> _sessionResults = [];

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

  @override
  void dispose() {
    _answerController.dispose();
    _answerFocusNode.dispose();
    _flipController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _loadDueWords() async {
    try {
      List<Map<String, dynamic>> words;
      if (widget.setId != null) {
        words = await _db.getWordsDueForReview(widget.setId!);
      } else {
        words = await _db.getAllWordsDueForReview(widget.userId);
      }
      words.shuffle();

      setState(() {
        _dueWords = words;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _rateWord(int quality) async {
    if (_dueWords.isEmpty || _currentIndex >= _dueWords.length) return;

    final word = _dueWords[_currentIndex];
    final oldMastery = word['mastery_level'] as int;

    final result = _srs.calculateNextReview(
      quality: quality,
      currentInterval: word['interval_days'] as int,
      easeFactor: (word['ease_factor'] as num).toDouble(),
      correctStreak: word['correct_streak'] as int,
      reviewCount: word['review_count'] as int,
    );

    // Update database
    await _db.updateWordReview(
      wordId: word['id'] as int,
      reviewCount: result.newReviewCount,
      correctStreak: result.newCorrectStreak,
      easeFactor: result.newEaseFactor,
      intervalDays: result.newInterval,
      nextReviewDate: result.nextReviewDate,
      masteryLevel: result.newMasteryLevel,
    );

    // Track session stats
    _totalReviewed++;
    if (result.newMasteryLevel > oldMastery) _masteryUps++;
    if (result.newMasteryLevel < oldMastery) _masteryDowns++;

    _sessionResults.add({
      'word': word['word'],
      'quality': quality,
      'oldMastery': oldMastery,
      'newMastery': result.newMasteryLevel,
      'nextInterval': result.newInterval,
    });

    // Move to next word
    setState(() {
      if (quality == SrsService.qualityAgain) {
        // Thêm từ vào cuối danh sách để ôn lại ngay trong phiên này
        _dueWords.add(word);
      }

      _showAnswer = false;
      _isAnswerCorrect = null;
      _answerController.clear();
      _flipController.reset();
      if (_currentIndex < _dueWords.length - 1) {
        _currentIndex++;
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _answerFocusNode.requestFocus();
        });
      } else {
        _isCompleted = true;
      }
    });
  }

  void _showAnswerCard() {
    _answerFocusNode.unfocus();
    setState(() {
      _showAnswer = true;
      _isAnswerCorrect = _answerController.text.trim().toLowerCase() == (_dueWords[_currentIndex]['word'] ?? '').toString().toLowerCase();
    });
    _flipController.forward();
    if (_dueWords.isNotEmpty && _currentIndex < _dueWords.length) {
      unawaited(_speak((_dueWords[_currentIndex]['word'] ?? '').toString()));
    }
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
    const Color onSecondaryFixed = Color(0xFF433500);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_dueWords.isEmpty) {
      return Scaffold(
        backgroundColor: surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: primary),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Review', style: TextStyle(color: onSurface)),
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
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, size: 72, color: Colors.green),
                ),
                const SizedBox(height: 24),
                const Text(
                  'All caught up! 🎉',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No words are due for review right now.\nKeep learning new words!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isCompleted) {
      return _buildCompletedScreen(
        primary: primary,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        secondaryContainer: secondaryContainer,
        onSecondaryFixed: onSecondaryFixed,
        surfaceContainerLow: surfaceContainerLow,
      );
    }

    final currentWord = _dueWords[_currentIndex];
    final progress = (_currentIndex + 1) / _dueWords.length;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primary),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(
          widget.setName ?? 'Daily Review',
          style: const TextStyle(color: onSurface, fontWeight: FontWeight.bold),
        ),
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
                  '${_currentIndex + 1} / ${_dueWords.length}',
                  style: const TextStyle(
                    color: primary,
                    fontWeight: FontWeight.bold,
                  ),
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
                  value: progress,
                  backgroundColor: primaryContainer.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(primary),
                  minHeight: 6,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildMasteryBadge(currentWord['mastery_level'] as int),
                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: _flipAnimation,
                      builder: (context, child) {
                        return Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 180, maxHeight: 300),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _showAnswer
                                  ? (_isAnswerCorrect == true 
                                      ? [const Color(0xFF2d8f4e), const Color(0xFF4ade80)]
                                      : [const Color(0xFFe53935), const Color(0xFFef5350)])
                                  : [primary, primaryContainer],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: (_showAnswer ? (_isAnswerCorrect == true ? Colors.green : Colors.red) : primary).withValues(alpha: 0.3),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!_showAnswer) ...[
                                const Icon(Icons.translate, color: Colors.white54, size: 32),
                                const SizedBox(height: 8),
                                const Text('What is the English word?', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                const SizedBox(height: 10),
                                Text(
                                  currentWord['meaning'] ?? '',
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                                ),
                                if (currentWord['set_name'] != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                                    child: Text(currentWord['set_name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                TextField(
                                  controller: _answerController,
                                  focusNode: _answerFocusNode,
                                  autofocus: true,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Type English word...',
                                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                    filled: true,
                                    fillColor: Colors.black.withValues(alpha: 0.2),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  ),
                                  onSubmitted: (_) => _showAnswerCard(),
                                ),
                              ] else ...[
                                Icon(_isAnswerCorrect == true ? Icons.check_circle : Icons.cancel, color: _isAnswerCorrect == true ? Colors.greenAccent : Colors.redAccent, size: 40),
                                const SizedBox(height: 8),
                                Text(currentWord['word'] ?? '', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                                if ((currentWord['pronunciation'] ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text('/${currentWord['pronunciation']}/', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: Colors.white70, fontStyle: FontStyle.italic)),
                                ],
                                const SizedBox(height: 8),
                                Container(width: 60, height: 2, color: Colors.white30),
                                const SizedBox(height: 10),
                                Text(currentWord['meaning'] ?? '', textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 19, fontWeight: FontWeight.w600, color: Colors.white)),
                                
                                if (_answerController.text.trim().isNotEmpty && _isAnswerCorrect != true) ...[
                                  const SizedBox(height: 10),
                                  Text('You typed: ${_answerController.text}', style: const TextStyle(fontSize: 14, color: Colors.white70, fontStyle: FontStyle.italic)),
                                ],

                                if ((currentWord['full_details'] ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                                    child: Text(currentWord['full_details'], textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4)),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    if (!_showAnswer) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _showAnswerCard,
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text('Check Answer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          style: ElevatedButton.styleFrom(backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 4),
                        ),
                      ),
                    ] else ...[
                      const Text('How well did you remember?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: onSurface)),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, buttonConstraints) {
                          final useWrap = buttonConstraints.maxWidth < 380;
                          if (useWrap) {
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                SizedBox(width: (buttonConstraints.maxWidth - 8) / 2, child: _buildRateButton(label: 'Again', emoji: 'A', subtitle: _previewInterval(SrsService.qualityAgain), color: const Color(0xFFe53935), onTap: () => _rateWord(SrsService.qualityAgain))),
                                SizedBox(width: (buttonConstraints.maxWidth - 8) / 2, child: _buildRateButton(label: 'Hard', emoji: 'H', subtitle: _previewInterval(SrsService.qualityHard), color: const Color(0xFFfb8c00), onTap: () => _rateWord(SrsService.qualityHard))),
                                SizedBox(width: (buttonConstraints.maxWidth - 8) / 2, child: _buildRateButton(label: 'Good', emoji: 'G', subtitle: _previewInterval(SrsService.qualityGood), color: const Color(0xFF43a047), onTap: () => _rateWord(SrsService.qualityGood))),
                                SizedBox(width: (buttonConstraints.maxWidth - 8) / 2, child: _buildRateButton(label: 'Easy', emoji: 'E', subtitle: _previewInterval(SrsService.qualityEasy), color: const Color(0xFF1e88e5), onTap: () => _rateWord(SrsService.qualityEasy))),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: _buildRateButton(label: 'Again', emoji: '😣', subtitle: _previewInterval(SrsService.qualityAgain), color: const Color(0xFFe53935), onTap: () => _rateWord(SrsService.qualityAgain))),
                              const SizedBox(width: 8),
                              Expanded(child: _buildRateButton(label: 'Hard', emoji: '🤔', subtitle: _previewInterval(SrsService.qualityHard), color: const Color(0xFFfb8c00), onTap: () => _rateWord(SrsService.qualityHard))),
                              const SizedBox(width: 8),
                              Expanded(child: _buildRateButton(label: 'Good', emoji: '👍', subtitle: _previewInterval(SrsService.qualityGood), color: const Color(0xFF43a047), onTap: () => _rateWord(SrsService.qualityGood))),
                              const SizedBox(width: 8),
                              Expanded(child: _buildRateButton(label: 'Easy', emoji: '🌟', subtitle: _previewInterval(SrsService.qualityEasy), color: const Color(0xFF1e88e5), onTap: () => _rateWord(SrsService.qualityEasy))),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _previewInterval(int quality) {
    if (_dueWords.isEmpty || _currentIndex >= _dueWords.length) return '';
    final word = _dueWords[_currentIndex];
    final result = _srs.calculateNextReview(
      quality: quality,
      currentInterval: word['interval_days'] as int,
      easeFactor: (word['ease_factor'] as num).toDouble(),
      correctStreak: word['correct_streak'] as int,
      reviewCount: word['review_count'] as int,
    );
    final days = result.newInterval;
    if (days == 0) return '< 1m';
    if (days == 1) return '1d';
    if (days < 7) return '${days}d';
    if (days < 30) return '${(days / 7).round()}w';
    return '${(days / 30).round()}mo';
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
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }

  Widget _buildMasteryBadge(int level) {
    final config = _getMasteryConfig(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: config['color'].withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config['color'].withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config['icon'] as IconData, size: 16, color: config['color'] as Color),
          const SizedBox(width: 6),
          Text(config['label'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: config['color'] as Color)),
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

  Widget _buildCompletedScreen({
    required Color primary,
    required Color surface,
    required Color onSurface,
    required Color onSurfaceVariant,
    required Color secondaryContainer,
    required Color onSecondaryFixed,
    required Color surfaceContainerLow,
  }) {
    final percentage = _totalReviewed > 0
        ? ((_sessionResults.where((r) => (r['quality'] as int) >= 3).length / _totalReviewed) * 100).round()
        : 0;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF4a40e0)),
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
                gradient: LinearGradient(colors: [primary, const Color(0xFF9795ff)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 12))],
              ),
              child: Column(
                children: [
                  const Icon(Icons.emoji_events, size: 64, color: Color(0xFFfed01b)),
                  const SizedBox(height: 12),
                  const Text('Review Complete!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem('Reviewed', '$_totalReviewed', Colors.white),
                      _buildStatItem('Accuracy', '$percentage%', Colors.white),
                      _buildStatItem('Level Up', '+$_masteryUps', Colors.greenAccent),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_sessionResults.isNotEmpty) ...[
              Align(alignment: Alignment.centerLeft, child: Text('Session Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: onSurface))),
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
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: quality >= 3 ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2))),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: quality >= 3 ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: Center(child: Icon(quality >= 3 ? Icons.check : Icons.replay, color: quality >= 3 ? Colors.green : Colors.red, size: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r['word'] as String, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: onSurface)),
                            if (levelChanged)
                              Text('${SrsService.masteryName(oldLevel)} → ${SrsService.masteryName(newLevel)}', style: TextStyle(fontSize: 12, color: newLevel > oldLevel ? Colors.green : Colors.orange, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Text('Next: ${interval}d', style: TextStyle(fontSize: 12, color: onSurfaceVariant)),
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
                style: ElevatedButton.styleFrom(backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
        Text(label, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8))),
      ],
    );
  }
}
