import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/database_service.dart';
import '../services/srs_service.dart';
import '../services/tts_settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mastery_utils.dart';
import '../widgets/mastery_badge.dart';
import '../widgets/bottom_nav_bar.dart';
import 'practice_page.dart';
import 'review_page.dart';
import 'placeholder_page.dart';

class VocabularySetPage extends StatefulWidget {
  final int setId;
  final String setName;
  final int userId;
  
  const VocabularySetPage({
    super.key,
    required this.setId,
    required this.setName,
    required this.userId,
  });

  @override
  State<VocabularySetPage> createState() => _VocabularySetPageState();
}

class _VocabularySetPageState extends State<VocabularySetPage> {
  final DatabaseService _db = DatabaseService();
  final FlutterTts _flutterTts = FlutterTts();
  final SrsService _srs = SrsService();
  final TtsSettingsService _ttsSettings = TtsSettingsService();
  bool _isImporting = false;
  List<Map<String, dynamic>> _words = [];
  bool _isLoading = true;
  int _progress = 0;
  int _totalWords = 0;
  int _dueCount = 0;
  Map<int, int> _masteryBreakdown = {};
  int _currentNavIndex = 1;
  bool _isSelectionMode = false;
  int _filterLevel = -1;
  final Set<int> _selectedWords = {};
  final Set<int> _flippedWords = {};

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
      if (!_isSelectionMode) {
        _selectedWords.clear();
      }
    });
  }

  void _showWordOptions({
    required int wordId,
    required String word,
    required String meaning,
    required String pronunciation,
    required String fullDetails,
    required bool isDifficult,
  }) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              word,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(isDifficult ? Icons.flag : Icons.flag_outlined, color: isDifficult ? Colors.red : null),
            title: Text(isDifficult ? 'Unmark Hard' : 'Mark Hard'),
            onTap: () {
              Navigator.pop(context);
              _toggleHardWord(wordId, isDifficult);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(context);
              _editWord(
                wordId: wordId,
                word: word,
                meaning: meaning,
                pronunciation: pronunciation,
                fullDetails: fullDetails,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete'),
            onTap: () {
              Navigator.pop(context);
              _deleteWord(wordId);
            },
          ),
          const SizedBox(height: 16),
        ],
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
        title: const Text('Delete Words'),
        content: Text('Are you sure you want to delete ${_selectedWords.length} selected words?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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
            SnackBar(content: Text('Deleted $countToDelete words')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
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
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PlaceholderPage(title: 'Practice', icon: Icons.fitness_center)),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PlaceholderPage(title: 'Profile', icon: Icons.person)),
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
    var voices = await _flutterTts.getVoices;
    if (voices != null) {
      debugPrint('Available voices: $voices');
    }
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
      final words = await _db.getVocabularyWords(widget.setId);
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

      setState(() {
        _words = words;
        _totalWords = total;
        _progress = progress;
        _dueCount = localDueCount;
        _masteryBreakdown = breakdown;
        final validIds = words.map((w) => w['id'] as int).toSet();
        _flippedWords.removeWhere((id) => !validIds.contains(id));
        _isLoading = false;
      });

      _refreshDueCount();
      await _db.updateVocabularySetProgress(widget.setId, progress, total);
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
      final dueWords = await _db.getWordsDueForReview(widget.setId);
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
        title: const Text('Add Words (Bulk)'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter words (one per line)',
                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: wordsController,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText: 'fair: (adj) công bằng, hợp lý; (n) hội chợ; (adv) khá, tương đối\n...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
        final lines = result.split('\n').where((line) => line.trim().isNotEmpty).toList();
        
        if (lines.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No words to import')),
            );
          }
          return;
        }

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
          if (remainder.isNotEmpty) {
            int semicolonIdx = remainder.indexOf(';');
            if (semicolonIdx != -1) {
              meaning = remainder.substring(0, semicolonIdx).trim();
              fullDetails = remainder.substring(semicolonIdx + 1).trim();
            } else {
              meaning = remainder;
            }
          }
          
          await _db.addVocabularyWord(
            widget.setId,
            word,
            '',
            meaning,
            fullDetails: fullDetails,
          );
        }

        await _loadWords();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added ${lines.length} words!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isImporting = false);
        }
      }
    }
  }

  Future<void> _deleteWord(int wordId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Word'),
        content: const Text('Are you sure you want to delete this word?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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
            SnackBar(content: Text('Error: $e')),
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
  }) async {
    final meaningController = TextEditingController(text: meaning);
    final pronunciationController = TextEditingController(text: pronunciation);
    final detailsController = TextEditingController(text: fullDetails);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit "$word"'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Meaning', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: meaningController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter the meaning you want',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Pronunciation', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: pronunciationController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Optional pronunciation',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Notes / Word type details', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Optional details or part of speech',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (meaningController.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      final wasFlipped = _flippedWords.contains(wordId);
      await _db.updateVocabularyWordDetails(
        wordId: wordId,
        meaning: meaningController.text,
        pronunciation: pronunciationController.text,
        fullDetails: detailsController.text,
      );
      await _loadWords();
      if (wasFlipped && mounted) {
        setState(() {
          _flippedWords.add(wordId);
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated "$word"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by Level',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _buildFilterOption(-1, 'All Words', Icons.list, Colors.grey, _words.length),
            _buildFilterOption(0, 'New', Icons.fiber_new, Colors.grey, _masteryBreakdown[0] ?? 0),
            _buildFilterOption(1, 'Learning', Icons.menu_book, context.lingoColors.masteryLearning, _masteryBreakdown[1] ?? 0),
            _buildFilterOption(2, 'Reviewing', Icons.refresh, context.lingoColors.masteryReviewing, _masteryBreakdown[2] ?? 0),
            _buildFilterOption(3, 'Mastered', Icons.star, context.lingoColors.masteryMastered, _masteryBreakdown[3] ?? 0),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(int level, String label, IconData icon, Color color, int count) {
    final isSelected = _filterLevel == level;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 13,
          ),
        ),
      ),
      selected: isSelected,
      onTap: () {
        setState(() => _filterLevel = level);
        Navigator.pop(context);
      },
    );
  }

  List<Map<String, dynamic>> get _filteredWords {
    if (_filterLevel == -1) return _words;
    return _words.where((w) => (w['mastery_level'] ?? 0) == _filterLevel).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.lingoColors;

    final displayWords = _filteredWords;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
                      ),
                      Text(
                        'Vocabulary List',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _toggleSelectionMode,
                        icon: Icon(
                          _isSelectionMode ? Icons.close : Icons.delete_outline,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [theme.colorScheme.primary, theme.colorScheme.primaryContainer],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'List',
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onPrimary.withAlpha(179),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.setName,
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.onPrimary.withAlpha(25),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Mastery Progress',
                                            style: TextStyle(
                                              fontFamily: 'Plus Jakarta Sans',
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.onPrimary,
                                            ),
                                          ),
                                          Text(
                                            '$_progress%',
                                            style: TextStyle(
                                              fontFamily: 'Plus Jakarta Sans',
                                              fontSize: 24,
                                              fontWeight: FontWeight.w900,
                                              color: theme.colorScheme.secondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      if (_totalWords > 0)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: SizedBox(
                                            height: 12,
                                            child: Row(
                                              children: [
                                                _buildBarSegment(_masteryBreakdown[3] ?? 0, _totalWords, colors.masteryMastered),
                                                _buildBarSegment(_masteryBreakdown[2] ?? 0, _totalWords, colors.masteryReviewing),
                                                _buildBarSegment(_masteryBreakdown[1] ?? 0, _totalWords, colors.masteryLearning),
                                                _buildBarSegment(_masteryBreakdown[0] ?? 0, _totalWords, theme.colorScheme.onPrimary.withAlpha(60)),
                                              ],
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.onPrimary.withAlpha(51),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildLegend('New', theme.colorScheme.onPrimary.withAlpha(138), _masteryBreakdown[0] ?? 0),
                                          _buildLegend('Learning', colors.masteryLearning, _masteryBreakdown[1] ?? 0),
                                          _buildLegend('Reviewing', colors.masteryReviewing, _masteryBreakdown[2] ?? 0),
                                          _buildLegend('Mastered', colors.masteryMastered, _masteryBreakdown[3] ?? 0),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (_dueCount > 0) ...[
                                  const SizedBox(height: 12),
                                  GestureDetector(
                                    onTap: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ReviewPage(
                                            userId: widget.userId,
                                            setId: widget.setId,
                                            setName: widget.setName,
                                          ),
                                        ),
                                      );
                                      if (result == true) await _loadWords();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: colors.reviewBannerDue[0].withAlpha(76),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: colors.reviewBannerDue[0].withAlpha(128)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.notifications_active, color: theme.colorScheme.onPrimary, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            '$_dueCount words due for review!',
                                            style: TextStyle(
                                              color: theme.colorScheme.onPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const Spacer(),
                                          Icon(Icons.arrow_forward_ios, color: theme.colorScheme.onPrimary.withAlpha(179), size: 14),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PracticePage(
                                          setId: widget.setId,
                                          setName: widget.setName,
                                          userId: widget.userId,
                                        ),
                                      ),
                                    );
                                    if (result == true) await _loadWords();
                                  },
                                  icon: Icon(Icons.play_arrow, color: theme.colorScheme.onSecondary),
                                  label: Text(
                                    'Practice',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.secondary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ReviewPage(
                                          userId: widget.userId,
                                          setId: widget.setId,
                                          setName: widget.setName,
                                        ),
                                      ),
                                    );
                                    if (result == true) await _loadWords();
                                  },
                                  icon: const Icon(Icons.refresh, color: Colors.white),
                                  label: Text(
                                    'Review ($_dueCount)',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colors.reviewBannerDue[0],
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Word List (${displayWords.length})',
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              Row(
                                children: [
                                  if (_isSelectionMode && _selectedWords.isNotEmpty)
                                    GestureDetector(
                                      onTap: _deleteSelectedWords,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.delete, color: Colors.white, size: 18),
                                            SizedBox(width: 4),
                                            Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (!_isSelectionMode && displayWords.isNotEmpty)
                                    GestureDetector(
                                      onTap: _flipAll,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withAlpha(25),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              displayWords.every((w) => _flippedWords.contains(w['id']))
                                                  ? Icons.flip_to_back
                                                  : Icons.flip_to_front,
                                              color: theme.colorScheme.primary,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              displayWords.every((w) => _flippedWords.contains(w['id']))
                                                  ? 'Unflip All' : 'Flip All',
                                              style: TextStyle(
                                                fontFamily: 'Be Vietnam Pro',
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  GestureDetector(
                                    onTap: _showFilterSheet,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _filterLevel >= 0 ? theme.colorScheme.primary.withAlpha(25) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            _filterLevel >= 0 ? SrsService.masteryName(_filterLevel) : 'Filter',
                                            style: TextStyle(
                                              fontFamily: 'Be Vietnam Pro',
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            _filterLevel >= 0 ? Icons.filter_alt : Icons.filter_list,
                                            color: theme.colorScheme.primary,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (displayWords.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.auto_stories, size: 64, color: theme.colorScheme.onSurfaceVariant.withAlpha(128)),
                                    const SizedBox(height: 16),
                                    Text(
                                      _filterLevel >= 0 ? 'No ${SrsService.masteryName(_filterLevel)} words' : 'No words yet',
                                      style: TextStyle(
                                        fontFamily: 'Be Vietnam Pro',
                                        fontSize: 16,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _filterLevel >= 0 ? 'Try changing the filter' : 'Add your first word to get started!',
                                      style: TextStyle(
                                        fontFamily: 'Be Vietnam Pro',
                                        fontSize: 14,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ...List.generate(displayWords.length, (index) {
                              final word = displayWords[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildWordCard(
                                  id: word['id'],
                                  word: word['word'],
                                  pronunciation: word['pronunciation'] ?? '',
                                  meaning: word['meaning'],
                                  fullDetails: word['full_details'] ?? '',
                                  isMastered: word['is_mastered'] ?? false,
                                  isDifficult: word['is_difficult'] ?? false,
                                  masteryLevel: word['mastery_level'] ?? 0,
                                  nextReviewDate: word['next_review_date'],
                                  intervalDays: word['interval_days'] ?? 0,
                                  correctStreak: word['correct_streak'] ?? 0,
                                ),
                              );
                            }),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isSelectionMode && _selectedWords.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _deleteSelectedWords,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.delete, color: Colors.white),
              label: Text(
                'Delete ${_selectedWords.length}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : FloatingActionButton(
              onPressed: _isImporting ? null : _addWord,
              backgroundColor: theme.colorScheme.primary,
              child: _isImporting
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.onPrimary,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(Icons.add, color: theme.colorScheme.onPrimary),
            ),
      bottomNavigationBar: LingoBottomNavBar(
        currentIndex: _currentNavIndex,
        items: const [
          NavItem(icon: Icons.school_outlined, label: 'Learn'),
          NavItem(icon: Icons.menu_book, label: 'Library'),
          NavItem(icon: Icons.fitness_center_outlined, label: 'Practice'),
          NavItem(icon: Icons.person_outline, label: 'Profile'),
        ],
        onTap: _onNavTapped,
      ),
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
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onPrimary.withAlpha(179),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildWordCard({
    required int id,
    required String word,
    required String pronunciation,
    required String meaning,
    required String fullDetails,
    required bool isMastered,
    required bool isDifficult,
    required int masteryLevel,
    DateTime? nextReviewDate,
    required int intervalDays,
    required int correctStreak,
  }) {
    final theme = Theme.of(context);
    final colors = context.lingoColors;

    final isSelected = _selectedWords.contains(id);
    final isFlipped = _flippedWords.contains(id);
    final isMasteredOrHigh = isMastered || masteryLevel >= 3;
    final mConfig = masteryConfig(masteryLevel, context);
    final reviewText = _srs.timeUntilReview(nextReviewDate);
    final isDue = _srs.isDueForReview(nextReviewDate);

    return GestureDetector(
      onTap: _isSelectionMode ? () => _toggleWordSelection(id) : () => _toggleWordFlip(id),
      onLongPress: _isSelectionMode
          ? null
          : () => _showWordOptions(
                wordId: id, word: word, meaning: meaning,
                pronunciation: pronunciation, fullDetails: fullDetails,
                isDifficult: isDifficult,
              ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primaryContainer.withAlpha(51) : theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : Border.all(
                  color: isDue ? colors.reviewBannerDue[0] : (mConfig['color'] as Color).withAlpha(153),
                  width: isDue ? 2.0 : 1.5,
                ),
        ),
        child: Row(
          children: [
            if (_isSelectionMode)
              Container(
                width: 24, height: 24,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    width: 2,
                  ),
                ),
                child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
              ),
            const SizedBox(width: 16),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                child: isFlipped
                    ? Column(
                        key: ValueKey('back-$id'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  word,
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              MasteryBadge(level: masteryLevel),
                            ],
                          ),
                          if (pronunciation.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '/$pronunciation/',
                              style: TextStyle(
                                fontFamily: 'Be Vietnam Pro',
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            meaning,
                            style: TextStyle(
                              fontFamily: 'Be Vietnam Pro',
                              fontSize: 14,
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
                                height: 1.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: _isSelectionMode ? null : () => _editWord(
                                  wordId: id, word: word, meaning: meaning,
                                  pronunciation: pronunciation, fullDetails: fullDetails,
                                ),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('Edit meaning'),
                                style: TextButton.styleFrom(
                                  foregroundColor: theme.colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  minimumSize: Size.zero,
                                ),
                              ),
                              const Spacer(),
                              if (!_isSelectionMode)
                                IconButton(
                                  onPressed: () => _speak(word),
                                  icon: Icon(Icons.volume_up, color: theme.colorScheme.primary),
                                ),
                            ],
                          ),
                          if (masteryLevel > 0 || nextReviewDate != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  isDue ? Icons.notifications_active : Icons.schedule,
                                  size: 13,
                                  color: isDue ? colors.reviewBannerDue[0] : theme.colorScheme.onSurfaceVariant.withAlpha(179),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    reviewText,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Be Vietnam Pro',
                                      fontSize: 11,
                                      fontWeight: isDue ? FontWeight.bold : FontWeight.normal,
                                      color: isDue ? colors.reviewBannerDue[0] : theme.colorScheme.onSurfaceVariant.withAlpha(179),
                                    ),
                                  ),
                                ),
                                if (intervalDays > 0)
                                  Text(
                                    '${intervalDays}d',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurfaceVariant.withAlpha(179),
                                    ),
                                  ),
                                if (correctStreak > 0) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    'Streak $correctStreak',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurfaceVariant.withAlpha(179),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      )
                    : Column(
                        key: ValueKey('front-$id'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  word,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (isMasteredOrHigh)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(Icons.star, color: colors.masteryMastered, size: 18),
                                ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: _isSelectionMode ? null : () => _toggleHardWord(id, isDifficult),
                                icon: Icon(
                                  isDifficult ? Icons.favorite : Icons.favorite_border,
                                  color: isDifficult ? Colors.red : theme.colorScheme.onSurfaceVariant.withAlpha(128),
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap card to flip',
                            style: TextStyle(
                              fontFamily: 'Be Vietnam Pro',
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant.withAlpha(179),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            if (!isFlipped)
              IconButton(
                onPressed: _isSelectionMode ? null : () => _speak(word),
                icon: Icon(Icons.volume_up, color: theme.colorScheme.primary),
              ),
          ],
        ),
      ),
    );
  }
}
