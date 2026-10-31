import 'dart:math';

import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../services/tts_settings_service.dart';
import '../services/word_change_bus.dart';
import '../services/word_details_parser.dart';
import '../widgets/example_card.dart';

/// Ôn nhẹ cho từ "Nên biết": nhận diện nghĩa bằng 4 đáp án, không bắt gõ.
/// Lịch giãn: 1 -> 3 -> 7 -> 21 -> 45 ngày; sai thì hẹn lại 1 ngày.
class PassiveReviewPage extends StatefulWidget {
  final int userId;
  const PassiveReviewPage({super.key, required this.userId});

  @override
  State<PassiveReviewPage> createState() => _PassiveReviewPageState();
}

class _PassiveReviewPageState extends State<PassiveReviewPage> {
  static const List<int> _intervals = [1, 3, 7, 21, 45];
  static const List<String> _fallbackMeanings = [
    'một việc đã xảy ra',
    'trạng thái không chắc chắn',
    'hành động lặp lại',
    'cảm giác tiếc nuối',
  ];

  final DatabaseService _db = DatabaseService();
  final TtsSettingsService _tts = TtsSettingsService();
  final Random _random = Random();

  bool _isLoading = true;
  Object? _loadError;
  List<Map<String, dynamic>> _words = [];
  List<String> _meaningPool = [];
  int _index = 0;
  int _correct = 0;
  int _answered = 0;
  int? _selected;
  bool _showResult = false;
  bool _isCompleted = false;
  bool _isSaving = false;
  int _nextDays = 0;
  late List<String> _options;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.speakWith(text);
    } catch (e) {
      debugPrint('Passive TTS error: $e');
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final due = await _db.getPassiveDueWords(widget.userId, limit: 20);
      final all = await _db.getVocabularyWords(widget.userId);
      due.shuffle(_random);
      final pool = all
          .map((w) => (w['meaning'] ?? '').toString().trim())
          .where((m) => m.isNotEmpty)
          .toSet()
          .toList();
      if (!mounted) return;
      setState(() {
        _words = due;
        _meaningPool = pool;
        _index = 0;
        _correct = 0;
        _answered = 0;
        _selected = null;
        _showResult = false;
        _isCompleted = due.isEmpty;
        _isLoading = false;
      });
      if (due.isNotEmpty) _prepareOptions();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e;
      });
    }
  }

  void _prepareOptions() {
    final word = _words[_index];
    final correct = (word['meaning'] ?? '').toString().trim();
    final distractors = _meaningPool
        .where((m) => m.toLowerCase() != correct.toLowerCase())
        .toSet()
        .toList()
      ..shuffle(_random);
    final options = <String>[correct, ...distractors.take(3)];
    for (final fallback in _fallbackMeanings) {
      if (options.length >= 4) break;
      if (!options.contains(fallback)) options.add(fallback);
    }
    options.shuffle(_random);
    _options = options;
    _selected = null;
    _showResult = false;
    _nextDays = 0;
  }

  Future<void> _choose(int index) async {
    if (_showResult || _isSaving || _isCompleted) return;
    final word = _words[_index];
    final correct = (word['meaning'] ?? '').toString().trim();
    final isCorrect = _options[index].trim().toLowerCase() == correct.toLowerCase();
    final reviewCount = (word['review_count'] as int?) ?? 0;
    final interval = isCorrect
        ? _intervals[min(reviewCount, _intervals.length - 1)]
        : 1;
    final next = DateTime.now().add(Duration(days: interval));

    setState(() {
      _selected = index;
      _showResult = true;
      _nextDays = interval;
      _answered++;
      if (isCorrect) _correct++;
      _isSaving = true;
    });
    _speak((word['word'] ?? '').toString());

    try {
      await _db.updateWordReview(
        wordId: word['id'] as int,
        reviewCount: isCorrect ? reviewCount + 1 : reviewCount,
        correctStreak: isCorrect
            ? ((word['correct_streak'] as int?) ?? 0) + 1
            : 0,
        easeFactor: ((word['ease_factor'] ?? 2.5) as num).toDouble(),
        intervalDays: interval,
        nextReviewDate: next,
        masteryLevel: 0,
        lapseCount: isCorrect
            ? ((word['lapse_count'] as int?) ?? 0)
            : ((word['lapse_count'] as int?) ?? 0) + 1,
      );
      WordChangeBus().notifyChanged('passive-review');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Chưa lưu được lịch ôn: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _next() {
    if (_index < _words.length - 1) {
      setState(() {
        _index++;
        _prepareOptions();
      });
    } else {
      setState(() => _isCompleted = true);
      WordChangeBus().notifyChanged('passive-review-done');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Gặp lại nhẹ'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded, size: 40, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Text(
                  'Cần kết nối mạng để ôn tập',
                  style: TextStyle(
                    fontFamily: 'Be Vietnam Pro',
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
              ],
            ),
          ),
        ),
      );
    }

    if (_words.isEmpty || _isCompleted) {
      final percentage = _answered > 0 ? (_correct * 100 / _answered).round() : 0;
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Gặp lại nhẹ'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility_rounded,
                  size: 56,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(height: 14),
                Text(
                  _words.isEmpty ? 'Hôm nay không có từ Nên biết' : 'Đã gặp lại xong!',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (_answered > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Nhận ra đúng $_correct/$_answered nghĩa ($percentage%)',
                    style: TextStyle(
                      fontFamily: 'Be Vietnam Pro',
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Xong'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final word = _words[_index];
    final wordText = (word['word'] ?? '').toString();
    final pronunciation = (word['pronunciation'] ?? '').toString();
    final meaning = (word['meaning'] ?? '').toString();
    final details = parseFullDetails((word['full_details'] ?? '').toString());
    final resolved = resolveExample(word);
    final example = resolved['sentence'] ?? '';
    final translation = resolved['translation'] ?? '';
    final pos = getPrimaryPos(details);
    final isCorrect = _showResult &&
        _selected != null &&
        _options[_selected!].trim().toLowerCase() == meaning.trim().toLowerCase();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Gặp lại nhẹ'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_index + 1}/${_words.length}',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.tertiary,
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
            if (_isSaving) const LinearProgressIndicator(minHeight: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_index + 1) / _words.length,
                  backgroundColor: theme.colorScheme.tertiary.withAlpha(40),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.tertiary),
                  minHeight: 4,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiary.withAlpha(18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.tertiary.withAlpha(70)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  wordText,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _speak(wordText),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.tertiary.withAlpha(25),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.volume_up_rounded,
                                    size: 20,
                                    color: theme.colorScheme.tertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (pronunciation.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '/$pronunciation/',
                              style: TextStyle(
                                fontFamily: 'Be Vietnam Pro',
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Chọn nghĩa đúng',
                            style: TextStyle(
                              fontFamily: 'Be Vietnam Pro',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(_options.length, (i) {
                      final option = _options[i];
                      final isAnswer = option.trim().toLowerCase() == meaning.trim().toLowerCase();
                      Color bg = theme.colorScheme.surfaceContainerLowest;
                      Color border = theme.colorScheme.outlineVariant;
                      Color fg = theme.colorScheme.onSurface;
                      if (_showResult) {
                        if (isAnswer) {
                          bg = Colors.green.withAlpha(40);
                          border = Colors.green;
                          fg = Colors.green;
                        } else if (_selected == i) {
                          bg = Colors.red.withAlpha(40);
                          border = Colors.red;
                          fg = Colors.red;
                        }
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: _showResult ? null : () => _choose(i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: border, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isAnswer && _showResult
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  size: 18,
                                  color: isAnswer && _showResult ? Colors.green : border,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    option,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Be Vietnam Pro',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: fg,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (_showResult) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isCorrect
                              ? Colors.green.withAlpha(30)
                              : Colors.red.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isCorrect ? Icons.check_circle : Icons.cancel,
                                  size: 18,
                                  color: isCorrect ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isCorrect ? 'Đúng rồi!' : 'Sai rồi',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isCorrect ? Colors.green : Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Nghĩa: $meaning',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (example.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              ExampleCard(
                                example: example,
                                pos: pos,
                                translation: translation.isEmpty ? null : translation,
                                maxLines: 3,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              _nextDays <= 1
                                  ? 'Gặp lại sau 1 ngày'
                                  : 'Gặp lại sau $_nextDays ngày',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (_showResult) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _next,
                          child: Text(
                            _index < _words.length - 1 ? 'Tiếp' : 'Hoàn thành',
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          'Nhấn Enter để tiếp tục',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
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
}
