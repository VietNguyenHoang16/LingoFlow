import 'dart:async';

import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../services/tts_settings_service.dart';
import '../services/word_change_bus.dart';
import '../services/word_details_parser.dart';
import '../widgets/flip_word_card.dart';
import '../widgets/load_error_view.dart';
import '../widgets/practice_mode_sheet.dart';
import 'flashcard_practice_page.dart';
import 'practice_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key, required this.userId});

  final int userId;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final DatabaseService _db = DatabaseService();
  final TtsSettingsService _tts = TtsSettingsService();
  final Set<int> _flipped = {};
  StreamSubscription<WordChangeEvent>? _sub;

  List<Map<String, dynamic>> _words = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = WordChangeBus().stream.listen((event) {
      if (event.reason == 'favorite') return;
      _load(background: true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool background = false}) async {
    if (!background) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final words = await _db.getFavoriteWords(widget.userId);
      if (!mounted) return;
      setState(() {
        _words = words;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.speakWith(text);
    } catch (_) {}
  }

  Future<void> _toggle(Map<String, dynamic> word) async {
    final id = word['id'] as int;
    final next = word['is_favorite'] != true;
    setState(() {
      if (!next) {
        _words.removeWhere((w) => w['id'] == id);
        _flipped.remove(id);
      } else {
        final i = _words.indexWhere((w) => w['id'] == id);
        if (i != -1) _words[i] = {...word, 'is_favorite': true};
      }
    });
    try {
      await _db.updateWordFavorite(id, next);
      WordChangeBus().notifyChanged('favorite');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!next) {
          _words.insert(0, word);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _practice() async {
    if (_words.isEmpty) return;
    final mode = await showPracticeModeSheet(context);
    if (!mounted || mode == null) return;
    final selected = List<Map<String, dynamic>>.from(_words);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => mode == PracticeMode.flashcard
            ? FlashcardPracticePage(
                userId: widget.userId,
                listName: 'Yêu thích (${selected.length})',
                preloadedWords: selected,
              )
            : PracticePage(
                userId: widget.userId,
                listName: 'Yêu thích (${selected.length})',
                preloadedWords: selected,
              ),
      ),
    );
    if (mounted) await _load(background: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Từ yêu thích',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_words.length}',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? LoadErrorView(
                  error: _error,
                  onRetry: _load,
                  onBack: () => Navigator.pop(context),
                )
              : _words.isEmpty
                  ? _empty(theme)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                        itemCount: _words.length,
                        itemBuilder: (context, index) {
                          final word = _words[index];
                          final id = word['id'] as int;
                          final text = (word['word'] ?? '').toString();
                          final resolved = resolveExample(word);
                          return FlipWordCard(
                            key: ValueKey('fav-$id'),
                            isFlipped: _flipped.contains(id),
                            word: text,
                            pronunciation: (word['pronunciation'] ?? '').toString(),
                            meaning: (word['meaning'] ?? '').toString(),
                            wordType: (word['word_type'] ?? '').toString(),
                            topicTag: (word['topic_tag'] ?? '').toString(),
                            example: resolved['sentence'] ?? '',
                            exampleTranslation: (resolved['translation'] ?? '').toString().isEmpty
                                ? null
                                : resolved['translation'],
                            commonSynonyms: (word['common_synonyms'] ?? '').toString(),
                            collocations: (word['collocations'] ?? '').toString(),
                            accent: theme.colorScheme.primary,
                            isFavorite: true,
                            onToggleFavorite: () => _toggle(word),
                            onTap: () => setState(() {
                              if (_flipped.contains(id)) {
                                _flipped.remove(id);
                              } else {
                                _flipped.add(id);
                              }
                            }),
                            onLongPress: () {},
                            onSpeak: () => _speak(text),
                          );
                        },
                      ),
                    ),
      bottomNavigationBar: _words.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _practice,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text('Luyện tập từ yêu thích (${_words.length})'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _empty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border_rounded, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'Chưa có từ yêu thích',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Chạm tim ở danh sách, tìm kiếm hoặc ôn tập để lưu lại.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Be Vietnam Pro',
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
