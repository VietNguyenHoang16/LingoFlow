import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../services/flashcard_queue.dart';
import '../services/tts_settings_service.dart';
import '../services/word_details_parser.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/flip_word_card.dart';
import '../widgets/load_error_view.dart';

class FlashcardPracticePage extends StatefulWidget {
  final int listId;
  final String listName;
  final int userId;
  final String? category;
  final List<Map<String, dynamic>>? preloadedWords;

  const FlashcardPracticePage({
    super.key,
    this.listId = 0,
    required this.listName,
    required this.userId,
    this.category,
    this.preloadedWords,
  });

  @override
  State<FlashcardPracticePage> createState() => _FlashcardPracticePageState();
}

class _FlashcardPracticePageState extends State<FlashcardPracticePage> {
  final DatabaseService _db = DatabaseService();
  final TtsSettingsService _ttsSettings = TtsSettingsService();

  List<Map<String, dynamic>> _allWords = [];
  FlashcardQueue<Map<String, dynamic>>? _queue;
  bool _isLoading = true;
  Object? _loadError;
  bool _revealed = false;
  bool _showConfetti = false;
  bool _isPopping = false;
  int _cardKey = 0;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _speak(String text) async {
    try {
      await _ttsSettings.speakWith(text);
    } catch (e) {
      debugPrint('Flashcard TTS error: $e');
    }
  }

  Future<void> _loadWords() async {
    try {
      List<Map<String, dynamic>> words;
      if (widget.preloadedWords != null) {
        words = List<Map<String, dynamic>>.from(widget.preloadedWords!);
      } else {
        final List<Map<String, dynamic>> wordsResult;
        if (widget.category != null) {
          wordsResult =
              await _db.getWordsByCategory(widget.userId, widget.category!);
        } else {
          wordsResult = await _db.getVocabularyWords(widget.listId);
        }
        words = List<Map<String, dynamic>>.from(wordsResult);
      }
      words.shuffle(Random());
      setState(() {
        _allWords = words;
        _queue = FlashcardQueue(words);
        _isLoading = false;
        _loadError = null;
        _revealed = false;
        _cardKey++;
      });
    } catch (e) {
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

  void _restart() {
    final words = List<Map<String, dynamic>>.from(_allWords)
      ..shuffle(Random());
    setState(() {
      _queue = FlashcardQueue(words);
      _revealed = false;
      _showConfetti = false;
      _cardKey++;
    });
  }

  void _markKnown() {
    final queue = _queue;
    if (queue == null || queue.isDone) return;
    setState(() {
      queue.markKnown();
      _revealed = false;
      _cardKey++;
      if (queue.isDone) _showConfetti = true;
    });
  }

  void _markUnknown() {
    if (_revealed) return;
    setState(() => _revealed = true);
  }

  void _advance() {
    final queue = _queue;
    if (queue == null || !_revealed) return;
    setState(() {
      queue.markUnknown();
      _revealed = false;
      _cardKey++;
    });
  }

  void _pop() {
    if (_isPopping) return;
    _isPopping = true;
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;
    navigator.pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
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
            onPressed: _pop,
          ),
          title: Text(
            widget.listName,
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
        body: LoadErrorView(
          error: _loadError,
          onRetry: _retryLoad,
          onBack: _pop,
        ),
      );
    }

    final queue = _queue;
    if (queue == null || queue.total == 0) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
            onPressed: _pop,
          ),
          title: Text(
            widget.listName,
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
        body: const Center(child: Text('Chưa có từ nào để luyện')),
      );
    }

    if (queue.isDone) {
      return ConfettiOverlay(
        play: _showConfetti,
        child: Scaffold(
          backgroundColor: theme.colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
              onPressed: _pop,
            ),
            title: Text(
              widget.listName,
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
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
                        Icons.celebration_rounded,
                        size: 56,
                        color: theme.colorScheme.onPrimary,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Đã biết hết ${queue.total} từ!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Bạn đã nhớ hết bộ từ này.',
                        textAlign: TextAlign.center,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Làm lại',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: _pop, child: const Text('Thoát')),
              ],
            ),
          ),
        ),
      );
    }

    final word = queue.current!;
    final wordText = (word['word'] ?? '').toString();
    final resolved = resolveExample(word);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
          onPressed: _pop,
        ),
        title: Text(
          widget.listName,
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withAlpha(51),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Còn ${queue.remaining}',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
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
                  value: queue.total == 0 ? 0 : queue.known / queue.total,
                  backgroundColor:
                      theme.colorScheme.primaryContainer.withAlpha(51),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  minHeight: 4,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: FlipWordCard(
                  key: ValueKey('flashcard_${word['id']}_$_cardKey'),
                  isFlipped: _revealed,
                  word: wordText,
                  pronunciation: (word['pronunciation'] ?? '').toString(),
                  meaning: (word['meaning'] ?? '').toString(),
                  wordType: (word['word_type'] ?? '').toString(),
                  topicTag: (word['topic_tag'] ?? '').toString(),
                  example: resolved['sentence'] ?? '',
                  exampleTranslation: resolved['translation'],
                  commonSynonyms:
                      (word['common_synonyms'] ?? '').toString(),
                  collocations: (word['collocations'] ?? '').toString(),
                  accent: theme.colorScheme.primary,
                  isDifficult: word['is_difficult'] == true ||
                      word['is_difficult'] == 1,
                  showFlipHint: false,
                  showSpeakButton: false,
                  onTap: () {},
                  onLongPress: () {},
                  onSpeak: () => unawaited(_speak(wordText)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    button: true,
                    label: 'Nghe phát âm',
                    child: GestureDetector(
                      onTap: () => unawaited(_speak(wordText)),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withAlpha(20),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.primary.withAlpha(90),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.volume_up_rounded,
                          color: theme.colorScheme.primary,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_revealed)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _advance,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Tiếp',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: OutlinedButton.icon(
                              onPressed: _markUnknown,
                              icon: const Icon(Icons.close_rounded, size: 20),
                              label: const Text(
                                'Chưa biết',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: _markKnown,
                              icon: const Icon(Icons.check_rounded, size: 20),
                              label: const Text(
                                'Đã biết',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
