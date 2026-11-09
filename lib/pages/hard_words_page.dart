import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/database_service.dart';
import '../services/tts_settings_service.dart';
import '../services/word_change_bus.dart';
import '../services/word_details_parser.dart';
import '../widgets/flip_word_card.dart';
import '../widgets/mnemonic_editor_sheet.dart';
import '../widgets/load_error_view.dart';

/// Danh sách các từ có lần chấm gần nhất là "Hard" — chỉ để xem lại và
/// nghe phát âm khi rảnh (không luyện tập trong app).
class HardWordsPage extends StatefulWidget {
  const HardWordsPage({super.key, required this.userId});

  final int userId;

  @override
  State<HardWordsPage> createState() => _HardWordsPageState();
}

class _HardWordsPageState extends State<HardWordsPage> {
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
      final words = await _db.getHardWords(widget.userId);
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

  /// Sao chép toàn bộ danh sách từ khó, mỗi từ một dòng.
  void _copyAll() {
    final words = _words
        .map((w) => (w['word'] ?? '').toString())
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return;
    Clipboard.setData(ClipboardData(text: words.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép ${words.length} từ'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Bỏ/thêm yêu thích nhưng KHÔNG xoá khỏi danh sách — danh sách phản ánh
  /// "lần chấm gần nhất là Hard", không liên quan tới yêu thích.
  Future<void> _toggleFavorite(Map<String, dynamic> word) async {
    final id = word['id'] as int;
    final next = word['is_favorite'] != true;
    setState(() => _patch(id, {...word, 'is_favorite': next}));
    try {
      await _db.updateWordFavorite(id, next);
      WordChangeBus().notifyChanged('favorite');
    } catch (e) {
      if (!mounted) return;
      setState(() => _patch(id, word));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  void _patch(int id, Map<String, dynamic> row) {
    final i = _words.indexWhere((w) => w['id'] == id);
    if (i != -1) _words[i] = row;
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
          'Từ khó',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sao chép tất cả',
            icon: const Icon(Icons.copy_all_rounded),
            onPressed: _words.isEmpty ? null : _copyAll,
          ),
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
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                        itemCount: _words.length,
                        itemBuilder: (context, index) {
                          final word = _words[index];
                          final id = word['id'] as int;
                          final text = (word['word'] ?? '').toString();
                          final resolved = resolveExample(word);
                          return FlipWordCard(
                            key: ValueKey('hard-$id'),
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
                            mnemonic: (word['mnemonic'] ?? '').toString(),
                            commonSynonyms: (word['common_synonyms'] ?? '').toString(),
                            collocations: (word['collocations'] ?? '').toString(),
                            accent: theme.colorScheme.primary,
                            isFavorite: word['is_favorite'] == true,
                            onToggleFavorite: () => _toggleFavorite(word),
                            onTap: () => setState(() {
                              if (_flipped.contains(id)) {
                                _flipped.remove(id);
                              } else {
                                _flipped.add(id);
                              }
                            }),
                            onLongPress: () {},
                            onEditMnemonic: () => showMnemonicEditorForWord(context, word),
                            onSpeak: () => _speak(text),
                          );
                        },
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
            Icon(Icons.local_fire_department_rounded, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'Chưa có từ khó',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Từ nào bạn chấm Hard ở lượt ôn gần nhất sẽ xuất hiện ở đây để xem lại khi rảnh.',
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
