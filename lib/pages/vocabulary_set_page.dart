import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/database_service.dart';
import '../services/srs_service.dart';
import '../services/tts_settings_service.dart';
import '../services/translation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mastery_utils.dart';
import '../widgets/mastery_badge.dart';
import '../widgets/word_type_utils.dart';
import '../widgets/word_type_badge.dart';
import '../widgets/bottom_nav_bar.dart';
import 'practice_page.dart';
import 'review_page.dart';
import 'profile_page.dart';

class VocabularyListPage extends StatefulWidget {
  final int listId;
  final String listName;
  final int userId;
  final String? category;

  const VocabularyListPage({
    super.key,
    required this.listId,
    required this.listName,
    required this.userId,
    this.category,
  });

  @override
  State<VocabularyListPage> createState() => _VocabularyListPageState();
}

class _VocabularyListPageState extends State<VocabularyListPage> {
  final DatabaseService _db = DatabaseService();
  final FlutterTts _flutterTts = FlutterTts();
  final SrsService _srs = SrsService();
  final TtsSettingsService _ttsSettings = TtsSettingsService();
  final TranslationService _translation = TranslationService();
  final Map<int, String> _exampleTranslations = {};
  final Set<int> _loadingTranslations = {};
  bool _isImporting = false;
  List<Map<String, dynamic>> _words = [];
  bool _isLoading = true;
  int _progress = 0;
  int _totalWords = 0;
  int _dueCount = 0;
  Map<int, int> _masteryBreakdown = {};
  Map<String, int> _wordTypeBreakdown = {};
  int _currentNavIndex = 1;
  bool _isSelectionMode = false;
  int _filterLevel = -1;
  final Set<int> _selectedWords = {};
  final Set<int> _flippedWords = {};
  String? _filterWordType;

  // -------------------------------------------------------
  // Logic methods (unchanged)
  // -------------------------------------------------------

  Future<void> _toggleHardWord(int wordId, bool currentStatus) async {
    try {
      await _db.updateWordDifficult(wordId, !currentStatus);
      setState(() {
        final index = _words.indexWhere((w) => w['id'] == wordId);
        if (index != -1) {
          _words[index] = {..._words[index], 'is_difficult': !currentStatus};
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedWords.clear();
    });
  }

  void _showWordOptions({
    required int wordId,
    required String word,
    required String meaning,
    required String pronunciation,
    required String fullDetails,
    required String wordType,
    required bool isDifficult,
    String exampleSentence = '',
  }) async {
    final theme = Theme.of(context);
    await showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Column(
                children: [
                  Text(
                    word,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (meaning.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      meaning,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Be Vietnam Pro',
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: (isDifficult ? Colors.green : Colors.orange).withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDifficult ? Icons.flag : Icons.flag_outlined,
                  color: isDifficult ? Colors.green : Colors.orange,
                  size: 18,
                ),
              ),
              title: Text(
                isDifficult ? 'Bo danh dau kho' : 'Danh dau kho',
                style: const TextStyle(fontFamily: 'Be Vietnam Pro', fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleHardWord(wordId, isDifficult);
              },
            ),
            ListTile(
              leading: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.edit_rounded, color: theme.colorScheme.primary, size: 18),
              ),
              title: const Text(
                'Chinh sua',
                style: TextStyle(fontFamily: 'Be Vietnam Pro', fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _editWord(
                  wordId: wordId, word: word, meaning: meaning,
                  pronunciation: pronunciation, fullDetails: fullDetails,
                  wordType: wordType, exampleSentence: exampleSentence,
                );
              },
            ),
            ListTile(
              leading: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_rounded, color: Colors.red, size: 18),
              ),
              title: const Text(
                'Xoa tu',
                style: TextStyle(
                  color: Colors.red,
                  fontFamily: 'Be Vietnam Pro',
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteWord(wordId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _toggleWordSelection(int wordId) {
    setState(() {
      if (_selectedWords.contains(wordId)) {
        _selectedWords.remove(wordId);
      } else {
        _selectedWords.add(wordId);
      }
    });
  }

  void _toggleWordFlip(int wordId) {
    setState(() {
      if (_flippedWords.contains(wordId)) {
        _flippedWords.remove(wordId);
      } else {
        _flippedWords.add(wordId);
      }
    });
  }

  void _flipAll() {
    final displayIds = _filteredWords.map((w) => w['id'] as int).toSet();
    if (displayIds.isEmpty) return;
    final allFlipped = displayIds.every((id) => _flippedWords.contains(id));
    setState(() {
      if (allFlipped) {
        _flippedWords.removeAll(displayIds);
      } else {
        _flippedWords.addAll(displayIds);
      }
    });
  }

  Future<void> _deleteSelectedWords() async {
    if (_selectedWords.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoa tu da chon?'),
        content: Text('Ban sap xoa ${_selectedWords.length} tu vung.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huy')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xoa'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final countToDelete = _selectedWords.length;
      try {
        for (int wordId in _selectedWords) {
          await _db.deleteVocabularyWord(wordId);
        }
        await _loadWords();
        setState(() {
          _selectedWords.clear();
          _isSelectionMode = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Da xoa $countToDelete tu')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Loi: $e')),
          );
        }
      }
    }
  }

  void _onNavTapped(int index) {
    if (index == _currentNavIndex) return;
    setState(() => _currentNavIndex = index);
    if (index == 0) {
      Navigator.pop(context);
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfilePage(userId: widget.userId)),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadWords();
    _initTts();
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
      debugPrint('TTS Error: $e');
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _loadWords() async {
    try {
      final words = await _db.getVocabularyWords(widget.listId);
      final total = words.length;
      final mastered = words.where((w) => (w['mastery_level'] ?? 0) >= 3).length;
      final progress = total > 0 ? ((mastered / total) * 100).round() : 0;
      final now = DateTime.now();
      final localDueCount = words.where((w) {
        final dynamic rawDate = w['next_review_date'];
        if (rawDate == null) return true;
        final dueDate = rawDate is DateTime ? rawDate : DateTime.tryParse(rawDate.toString());
        if (dueDate == null) return true;
        return !dueDate.isAfter(now);
      }).length;

      final breakdown = <int, int>{};
      for (final w in words) {
        final level = w['mastery_level'] as int? ?? 0;
        breakdown[level] = (breakdown[level] ?? 0) + 1;
      }

      final typeBreakdown = <String, int>{};
      for (final w in words) {
        final raw = (w['word_type'] ?? '').toString();
        if (raw.isEmpty) continue;
        for (final t in raw.split(',')) {
          final key = t.trim();
          if (key.isEmpty) continue;
          typeBreakdown[key] = (typeBreakdown[key] ?? 0) + 1;
        }
      }

      setState(() {
        _words = words;
        _totalWords = total;
        _progress = progress;
        _dueCount = localDueCount;
        _masteryBreakdown = breakdown;
        _wordTypeBreakdown = typeBreakdown;
        final validIds = words.map((w) => w['id'] as int).toSet();
        _flippedWords.removeWhere((id) => !validIds.contains(id));
        _isLoading = false;
      });

      _refreshDueCount();
      await _db.updateListProgress(widget.listId, progress, total);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _refreshDueCount() async {
    try {
      final dueWords = await _db.getWordsDueForReview(widget.listId);
      if (!mounted) return;
      setState(() => _dueCount = dueWords.length);
    } catch (e) {
      debugPrint('Due count refresh failed: $e');
    }
  }

  Future<void> _addWord() async {
    final wordsController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Them tu (nhap nhieu)'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Moi dong la mot tu vung',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: wordsController,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText:
                      'fair: (adj) cong bang; (n) hoi cho; (adv) kha\n...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huy'),
          ),
          TextButton(
            onPressed: () {
              if (wordsController.text.trim().isNotEmpty) {
                Navigator.pop(context, wordsController.text);
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      setState(() => _isImporting = true);
      try {
        final lines = result
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList();
        if (lines.isEmpty) return;

        final orderedLines = lines.reversed.toList();
        for (String rawLine in orderedLines) {
          String line = rawLine.trim();
          if (line.isEmpty) continue;
          int colonIdx = line.indexOf(':');
          String word;
          String remainder;
          if (colonIdx != -1) {
            word = line.substring(0, colonIdx).trim();
            remainder = line.substring(colonIdx + 1).trim();
          } else {
            word = line;
            remainder = '';
          }

          String meaning = '';
          String fullDetails = '';
          String wordType = '';
          if (remainder.isNotEmpty) {
            final typeMatches = RegExp(r'\(([a-z\.]+)\)')
                .allMatches(remainder)
                .map((m) => normalizeWordTypeAbbrev(m.group(1) ?? ''))
                .where((key) => key.isNotEmpty)
                .toSet()
                .toList();
            if (typeMatches.isNotEmpty) {
              wordType = typeMatches.join(',');
            }
            final cleanedRemainder =
                remainder.replaceAll(RegExp(r'\s*\(([a-z\.]+)\)'), '').trim();
            int semicolonIdx = cleanedRemainder.indexOf(';');
            if (semicolonIdx != -1) {
              meaning = cleanedRemainder.substring(0, semicolonIdx).trim();
              fullDetails = cleanedRemainder.substring(semicolonIdx + 1).trim();
            } else {
              meaning = cleanedRemainder;
            }
          }

          final existingWords = await _db.searchWord(widget.userId, word);
          final alreadyExists = existingWords.any(
            (w) => (w['word']?.toString().toLowerCase() ?? '') ==
                word.toLowerCase(),
          );
          if (alreadyExists) continue;

          await _db.addVocabularyWord(
            widget.listId,
            word,
            '',
            meaning,
            fullDetails: fullDetails,
            wordType: wordType,
          );
        }

        await _loadWords();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Da them ${lines.length} tu!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Loi: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _deleteWord(int wordId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoa tu nay?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huy')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xoa'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _db.deleteVocabularyWord(wordId);
        await _loadWords();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Loi: $e')),
          );
        }
      }
    }
  }

  Future<void> _editWord({
    required int wordId,
    required String word,
    required String meaning,
    required String pronunciation,
    required String fullDetails,
    required String wordType,
    String exampleSentence = '',
  }) async {
    final wordController = TextEditingController(text: word);
    final meaningController = TextEditingController(text: meaning);
    final pronunciationController = TextEditingController(text: pronunciation);
    final detailsController = TextEditingController(text: fullDetails);
    final exampleController = TextEditingController(text: exampleSentence);
    final selectedTypes = <String>{
      ...wordType
          .split(',')
          .map((t) => t.trim())
          .where((t) => kWordTypeLabel.containsKey(t)),
    };

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Chinh sua tu'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tu vung', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: wordController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Nhap tu',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Nghia', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: meaningController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Nhap nghia',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Phat am', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pronunciationController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Tuy chon',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Loai tu', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: kWordTypeKeys.map((key) {
                      final config = wordTypeConfig(key, dialogContext);
                      final color = config['color'] as Color;
                      final isSelected = selectedTypes.contains(key);
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            if (isSelected) {
                              selectedTypes.remove(key);
                            } else {
                              selectedTypes.add(key);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withAlpha(40) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? color.withAlpha(180)
                                  : color.withAlpha(60),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(config['icon'] as IconData, size: 12, color: color),
                              const SizedBox(width: 4),
                              Text(
                                config['shortLabel'] as String,
                                style: TextStyle(
                                  fontFamily: 'Be Vietnam Pro',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('Chi tiet', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: detailsController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Tuy chon',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Cau vi du', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: exampleController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Nhap cau tieng Anh',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Huy'),
            ),
            TextButton(
              onPressed: () {
                if (wordController.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Luu'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final joinedTypes = selectedTypes.toList().join(',');

    try {
      final wasFlipped = _flippedWords.contains(wordId);
      await _db.updateVocabularyWord(
        wordId: wordId,
        word: wordController.text,
        meaning: meaningController.text,
        pronunciation: pronunciationController.text,
        fullDetails: detailsController.text,
        wordType: joinedTypes,
        exampleSentence: exampleController.text,
      );
      await _loadWords();
      if (wasFlipped && mounted) setState(() => _flippedWords.add(wordId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Da cap nhat "${wordController.text.trim()}"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loi: $e')),
        );
      }
    }
  }

  void _showFilterSheet() {
    final theme = Theme.of(context);
    final colors = context.lingoColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loc theo trinh do',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _buildFilterOption(-1, 'Tat ca', Icons.list_rounded, Colors.grey, _words.length),
              _buildFilterOption(0, 'Moi', Icons.fiber_new_rounded, Colors.blueGrey, _masteryBreakdown[0] ?? 0),
              _buildFilterOption(1, 'Dang hoc', Icons.menu_book_rounded, colors.masteryLearning, _masteryBreakdown[1] ?? 0),
              _buildFilterOption(2, 'Dang on', Icons.refresh_rounded, colors.masteryReviewing, _masteryBreakdown[2] ?? 0),
              _buildFilterOption(3, 'Thuan thuc', Icons.star_rounded, colors.masteryMastered, _masteryBreakdown[3] ?? 0),
              _buildFilterOption(-2, 'Kho nho', Icons.warning_amber_rounded, Colors.orange, _words.where((w) => SrsService.isLeech(w['lapse_count'] as int? ?? 0)).length),
              const SizedBox(height: 18),
              Divider(color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 12),
              Text(
                'Loc theo loai tu',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _buildWordTypeFilterOption(
                null,
                'Tat ca',
                Icons.all_inclusive_rounded,
                Colors.grey,
                _words.length,
                sheetContext,
                setSheetState,
              ),
              ...kWordTypeKeys.map((key) {
                final config = wordTypeConfig(key, sheetContext);
                return _buildWordTypeFilterOption(
                  key,
                  config['label'] as String,
                  config['icon'] as IconData,
                  config['color'] as Color,
                  _wordTypeBreakdown[key] ?? 0,
                  sheetContext,
                  setSheetState,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption(int level, String label, IconData icon, Color color, int count) {
    final theme = Theme.of(context);
    final isSelected = _filterLevel == level;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterLevel = level;
          _filterWordType = null;
        });
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: color.withAlpha(80), width: 1.5) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Be Vietnam Pro',
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                  color: isSelected ? color : theme.colorScheme.onSurface,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha(isSelected ? 40 : 20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordTypeFilterOption(
    String? typeKey,
    String label,
    IconData icon,
    Color color,
    int count,
    BuildContext sheetContext,
    StateSetter setSheetState,
  ) {
    final theme = Theme.of(sheetContext);
    final isSelected = _filterWordType == typeKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterWordType = typeKey;
          _filterLevel = -1;
        });
        Navigator.pop(sheetContext);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: color.withAlpha(80), width: 1.5) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Be Vietnam Pro',
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                  color: isSelected ? color : theme.colorScheme.onSurface,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha(isSelected ? 40 : 20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredWords {
    Iterable<Map<String, dynamic>> words = _words;
    if (_filterWordType != null) {
      words = words.where((w) {
        final raw = (w['word_type'] ?? '').toString();
        if (raw.isEmpty) return false;
        return raw.split(',').map((s) => s.trim()).contains(_filterWordType);
      });
    }
    final list = words.toList();
    if (_filterLevel == -2) {
      return list.where((w) => SrsService.isLeech(w['lapse_count'] as int? ?? 0)).toList();
    }
    if (_filterLevel == -1) return list;
    return list.where((w) => (w['mastery_level'] ?? 0) == _filterLevel).toList();
  }

  // -------------------------------------------------------
  // Build
  // -------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.lingoColors;
    final isDark = theme.brightness == Brightness.dark;
    final displayWords = _filteredWords;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: theme.colorScheme.primary,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
            actions: [
              GestureDetector(
                onTap: _toggleSelectionMode,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(0, 8, 12, 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isSelectionMode ? Icons.close_rounded : Icons.checklist_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withAlpha(200),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Danh sach',
                            style: TextStyle(
                              fontFamily: 'Be Vietnam Pro',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.listName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.4,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildProgressSection(theme, colors),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Due review banner
                  if (_dueCount > 0)
                    _buildDueBanner(theme, colors),
                  if (_dueCount > 0) const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          label: 'Luyen tap',
                          icon: Icons.play_arrow_rounded,
                          color: theme.colorScheme.secondary,
                          textColor: theme.colorScheme.onSecondary,
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PracticePage(
                                  listId: widget.listId,
                                  listName: widget.listName,
                                  userId: widget.userId,
                                ),
                              ),
                            );
                            if (result == true) await _loadWords();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          label: 'On tap ($_dueCount)',
                          icon: Icons.refresh_rounded,
                          color: colors.reviewBannerDue[0],
                          textColor: Colors.white,
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReviewPage(
                                  userId: widget.userId,
                                  listId: widget.listId,
                                  listName: widget.listName,
                                ),
                              ),
                            );
                            if (result == true) await _loadWords();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Word list header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Danh sach tu (${displayWords.length})',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      // Flip all
                      if (!_isSelectionMode && displayWords.isNotEmpty)
                        _buildChipButton(
                          label: displayWords.every((w) => _flippedWords.contains(w['id']))
                              ? 'Giu lat'
                              : 'Lat tat ca',
                          icon: Icons.flip_rounded,
                          onTap: _flipAll,
                          theme: theme,
                        ),
                      const SizedBox(width: 8),
                      // Filter
                      _buildChipButton(
                        label: _filterWordType != null
                            ? (kWordTypeLabel[_filterWordType] ?? _filterWordType!)
                            : (_filterLevel == -2
                                ? 'Kho nho'
                                : (_filterLevel >= 0
                                    ? SrsService.masteryName(_filterLevel)
                                    : 'Loc')),
                        icon: _filterLevel != -1 || _filterWordType != null
                            ? Icons.filter_alt_rounded
                            : Icons.filter_list_rounded,
                        onTap: _showFilterSheet,
                        theme: theme,
                        isActive: _filterLevel != -1 || _filterWordType != null,
                      ),
                      // Delete selected
                      if (_isSelectionMode && _selectedWords.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _deleteSelectedWords,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.delete_rounded, color: Colors.white, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${_selectedWords.length}',
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Words
                  if (displayWords.isEmpty)
                    _buildEmptyWords(theme)
                  else
                    ...List.generate(displayWords.length, (index) {
                      final word = displayWords[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildWordCard(
                          id: word['id'],
                          word: word['word'],
                          pronunciation: word['pronunciation'] ?? '',
                          meaning: word['meaning'],
                          fullDetails: word['full_details'] ?? '',
                          wordType: word['word_type'] ?? '',
                          exampleSentence: word['example_sentence'] ?? '',
                          isMastered: word['is_mastered'] ?? false,
                          isDifficult: word['is_difficult'] ?? false,
                          masteryLevel: word['mastery_level'] ?? 0,
                          nextReviewDate: word['next_review_date'],
                          intervalDays: word['interval_days'] ?? 0,
                          correctStreak: word['correct_streak'] ?? 0,
                          lapseCount: word['lapse_count'] ?? 0,
                          isDark: isDark,
                        ),
                      );
                    }),
                ]),
              ),
            ),
        ],
      ),
      floatingActionButton: _isSelectionMode && _selectedWords.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _deleteSelectedWords,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.delete_rounded, color: Colors.white),
              label: Text(
                'Xoa ${_selectedWords.length} tu',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withAlpha(80),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: _isImporting ? null : _addWord,
                backgroundColor: theme.colorScheme.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: _isImporting
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: theme.colorScheme.onPrimary,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Icon(Icons.add_rounded, color: theme.colorScheme.onPrimary, size: 28),
              ),
            ),
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: LingoBottomNavBar(
          currentIndex: _currentNavIndex,
          items: const [
            NavItem(icon: Icons.home_rounded, label: 'Trang chu'),
            NavItem(icon: Icons.person_rounded, label: 'Ho so'),
          ],
          onTap: _onNavTapped,
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // Widget helpers
  // -------------------------------------------------------

  Widget _buildProgressSection(ThemeData theme, LingoFlowColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _totalWords > 0
                    ? SizedBox(
                        height: 8,
                        child: Row(
                          children: [
                            _buildBarSegment(_masteryBreakdown[3] ?? 0, _totalWords, colors.masteryMastered),
                            _buildBarSegment(_masteryBreakdown[2] ?? 0, _totalWords, colors.masteryReviewing),
                            _buildBarSegment(_masteryBreakdown[1] ?? 0, _totalWords, colors.masteryLearning),
                            _buildBarSegment(
                              _masteryBreakdown[0] ?? 0,
                              _totalWords,
                              Colors.white.withAlpha(50),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        height: 8,
                        color: Colors.white.withAlpha(30),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$_progress%',
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildLegend('Moi', Colors.white.withAlpha(120), _masteryBreakdown[0] ?? 0),
            const SizedBox(width: 12),
            _buildLegend('Hoc', colors.masteryLearning, _masteryBreakdown[1] ?? 0),
            const SizedBox(width: 12),
            _buildLegend('On', colors.masteryReviewing, _masteryBreakdown[2] ?? 0),
            const SizedBox(width: 12),
            _buildLegend('Gioi', colors.masteryMastered, _masteryBreakdown[3] ?? 0),
          ],
        ),
      ],
    );
  }

  Widget _buildBarSegment(int count, int total, Color color) {
    if (count == 0 || total == 0) return const SizedBox.shrink();
    return Expanded(flex: count, child: Container(color: color));
  }

  Widget _buildLegend(String label, Color color, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$count $label',
          style: TextStyle(
            fontFamily: 'Be Vietnam Pro',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withAlpha(200),
          ),
        ),
      ],
    );
  }

  Widget _buildDueBanner(ThemeData theme, LingoFlowColors colors) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewPage(
              userId: widget.userId,
              listId: widget.listId,
              listName: widget.listName,
            ),
          ),
        );
        if (result == true) await _loadWords();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors.reviewBannerDue),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors.reviewBannerDue[0].withAlpha(60),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Text('ðŸ“š', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Co tu can on tap!',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$_dueCount tu dang cho ban',
                    style: const TextStyle(
                      fontFamily: 'Be Vietnam Pro',
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(80),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required ThemeData theme,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withAlpha(25)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: isActive
              ? Border.all(color: theme.colorScheme.primary.withAlpha(80), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Be Vietnam Pro',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWords(ThemeData theme) {
    final hasActiveFilter = _filterLevel != -1 || _filterWordType != null;
    final masteryLabel = _filterLevel == -2
        ? 'kho nho'
        : (_filterLevel >= 0
            ? 'trinh do ${SrsService.masteryName(_filterLevel)}'
            : '');
    final typeLabel = _filterWordType != null
        ? (kWordTypeLabel[_filterWordType] ?? _filterWordType!)
        : '';
    final subjectParts = <String>[
      if (masteryLabel.isNotEmpty) masteryLabel,
      if (typeLabel.isNotEmpty) typeLabel,
    ];
    final subject = subjectParts.join(' + ');
    return Container(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Text('ðŸ“–', style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Text(
              subject.isNotEmpty
                  ? 'Khong co tu $subject'
                  : 'Chua co tu vung',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasActiveFilter ? 'Thu thay doi bo loc' : 'Nhan + de them tu dau tien!',
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

  Widget _buildWordCard({
    required int id,
    required String word,
    required String pronunciation,
    required String meaning,
    required String fullDetails,
    required String wordType,
    required String exampleSentence,
    required bool isMastered,
    required bool isDifficult,
    required int masteryLevel,
    DateTime? nextReviewDate,
    required int intervalDays,
    required int correctStreak,
    required int lapseCount,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final colors = context.lingoColors;

    final isSelected = _selectedWords.contains(id);
    final isFlipped = _flippedWords.contains(id);
    final isMasteredOrHigh = isMastered || masteryLevel >= 3;
    final mConfig = masteryConfig(masteryLevel, context);
    final masteryColor = mConfig['color'] as Color;
    final reviewText = _srs.timeUntilReview(nextReviewDate);
    final isDue = _srs.isDueForReview(nextReviewDate);

    return GestureDetector(
      onTap: _isSelectionMode
          ? () => _toggleWordSelection(id)
          : () => _toggleWordFlip(id),
      onLongPress: _isSelectionMode
          ? null
          : () => _showWordOptions(
                wordId: id,
                word: word,
                meaning: meaning,
                pronunciation: pronunciation,
                fullDetails: fullDetails,
                wordType: wordType,
                isDifficult: isDifficult,
                exampleSentence: exampleSentence,
              ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withAlpha(15)
              : (isDark
                  ? theme.colorScheme.surfaceContainerLow
                  : theme.colorScheme.surfaceContainerLowest),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withAlpha(150)
                : (isDue
                    ? colors.reviewBannerDue[0].withAlpha(150)
                    : masteryColor.withAlpha(60)),
            width: isSelected || isDue ? 1.5 : 1,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(6),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selection checkbox
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 10, top: 2),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : null,
                ),
              ),

            // Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: isFlipped
                    ? _buildWordCardBack(
                        key: ValueKey('back-$id'),
                        id: id,
                        word: word,
                        pronunciation: pronunciation,
                        meaning: meaning,
                        fullDetails: fullDetails,
                        wordType: wordType,
                        exampleSentence: exampleSentence,
                        isDifficult: isDifficult,
                        masteryLevel: masteryLevel,
                        nextReviewDate: nextReviewDate,
                        intervalDays: intervalDays,
                        correctStreak: correctStreak,
                        lapseCount: lapseCount,
                        reviewText: reviewText,
                        isDue: isDue,
                        theme: theme,
                        colors: colors,
                      )
                    : _buildWordCardFront(
                        key: ValueKey('front-$id'),
                        id: id,
                        word: word,
                        wordType: wordType,
                        isMasteredOrHigh: isMasteredOrHigh,
                        isDifficult: isDifficult,
                        masteryColor: masteryColor,
                        lapseCount: lapseCount,
                        theme: theme,
                        colors: colors,
                      ),
              ),
            ),

            // Speaker icon (front only)
            if (!isFlipped) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _isSelectionMode ? null : () => _speak(word),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.volume_up_rounded,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWordCardFront({
    required Key key,
    required int id,
    required String word,
    required String wordType,
    required bool isMasteredOrHigh,
    required bool isDifficult,
    required Color masteryColor,
    required int lapseCount,
    required ThemeData theme,
    required LingoFlowColors colors,
  }) {
    final typeTokens = wordType
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                word,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: theme.colorScheme.onSurface,
                  height: 1.2,
                ),
              ),
            ),
            if (SrsService.isLeech(lapseCount))
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Leech',
                  style: TextStyle(
                    fontFamily: 'Be Vietnam Pro',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange,
                  ),
                ),
              ),
            if (isMasteredOrHigh)
              Icon(Icons.star_rounded, color: colors.masteryMastered, size: 18),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: _isSelectionMode ? null : () => _toggleHardWord(id, isDifficult),
              child: Icon(
                isDifficult ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isDifficult
                    ? Colors.red
                    : theme.colorScheme.onSurfaceVariant.withAlpha(100),
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: masteryColor.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                SrsService.masteryName(0),
                style: TextStyle(
                  fontFamily: 'Be Vietnam Pro',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: masteryColor,
                ),
              ),
            ),
            if (typeTokens.isNotEmpty) ...[
              const SizedBox(width: 6),
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: typeTokens
                      .map((t) => WordTypeBadge(typeKey: t, compact: true))
                      .toList(),
                ),
              ),
            ] else ...[
              const SizedBox(width: 8),
              Text(
                'Nhan de lat',
                style: TextStyle(
                  fontFamily: 'Be Vietnam Pro',
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(140),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildWordCardBack({
    required Key key,
    required int id,
    required String word,
    required String pronunciation,
    required String meaning,
    required String fullDetails,
    required String wordType,
    required String exampleSentence,
    required bool isDifficult,
    required int masteryLevel,
    required DateTime? nextReviewDate,
    required int intervalDays,
    required int correctStreak,
    required int lapseCount,
    required String reviewText,
    required bool isDue,
    required ThemeData theme,
    required LingoFlowColors colors,
  }) {
    final typeTokens = wordType
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                word,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (SrsService.isLeech(lapseCount))
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
              ),
            MasteryBadge(level: masteryLevel),
          ],
        ),
        if (typeTokens.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: typeTokens
                .map((t) => WordTypeBadge(typeKey: t, compact: true))
                .toList(),
          ),
        ],
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
          meaning,
          style: TextStyle(
            fontFamily: 'Be Vietnam Pro',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        if (fullDetails.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            fullDetails,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Be Vietnam Pro',
              fontSize: 12,
              color: theme.colorScheme.onSurface,
              height: 1.5,
            ),
          ),
        ],
        if (exampleSentence.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.primary.withAlpha(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.format_quote_rounded, size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        exampleSentence,
                        style: TextStyle(
                          fontFamily: 'Be Vietnam Pro',
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (_exampleTranslations.containsKey(id))
                  Padding(
                    padding: const EdgeInsets.only(left: 18),
                    child: Text(
                      _exampleTranslations[id]!,
                      style: TextStyle(
                        fontFamily: 'Be Vietnam Pro',
                        fontSize: 12,
                        color: theme.colorScheme.primary.withAlpha(200),
                        height: 1.3,
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: _loadingTranslations.contains(id)
                      ? null
                      : () async {
                          if (_exampleTranslations.containsKey(id)) {
                            setState(() => _exampleTranslations.remove(id));
                          } else {
                            setState(() => _loadingTranslations.add(id));
                            final translation = await _translation.translateText(exampleSentence);
                            setState(() {
                              _exampleTranslations[id] = translation;
                              _loadingTranslations.remove(id);
                            });
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _loadingTranslations.contains(id)
                          ? theme.colorScheme.primary.withAlpha(30)
                          : theme.colorScheme.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_loadingTranslations.contains(id))
                          SizedBox(
                            width: 12, height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: theme.colorScheme.primary),
                          )
                        else
                          Icon(Icons.translate_rounded, size: 12, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          _exampleTranslations.containsKey(id) ? 'An dich' : 'Dich',
                          style: TextStyle(
                            fontFamily: 'Be Vietnam Pro',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            GestureDetector(
              onTap: _isSelectionMode
                  ? null
                  : () => _editWord(
                        wordId: id,
                        word: word,
                        meaning: meaning,
                        pronunciation: pronunciation,
                        fullDetails: fullDetails,
                        wordType: wordType,
                      ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_rounded, size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Sua',
                      style: TextStyle(
                        fontFamily: 'Be Vietnam Pro',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (nextReviewDate != null || intervalDays > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDue ? Icons.notifications_active_rounded : Icons.schedule_rounded,
                    size: 13,
                    color: isDue ? colors.reviewBannerDue[0] : theme.colorScheme.onSurfaceVariant.withAlpha(160),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    reviewText,
                    style: TextStyle(
                      fontFamily: 'Be Vietnam Pro',
                      fontSize: 11,
                      fontWeight: isDue ? FontWeight.w700 : FontWeight.w500,
                      color: isDue
                          ? colors.reviewBannerDue[0]
                          : theme.colorScheme.onSurfaceVariant.withAlpha(160),
                    ),
                  ),
                ],
              ),
            if (!_isSelectionMode) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _speak(word),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.volume_up_rounded, color: theme.colorScheme.primary, size: 22),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

