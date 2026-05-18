import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/tts_settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/animated_pressable.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';

import 'review_page.dart';
import 'placeholder_page.dart';
import 'vocabulary_group_page.dart';

class DashboardPage extends StatefulWidget {
  final int userId;

  const DashboardPage({super.key, required this.userId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DatabaseService _db = DatabaseService();
  final TtsSettingsService _ttsSettings = TtsSettingsService();
  List<Map<String, dynamic>> _vocabularyGroups = [];
  Map<String, dynamic> _reviewStats = {};
  bool _isLoading = true;
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;

    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PlaceholderPage(title: 'Progress', icon: Icons.query_stats),
          ),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PlaceholderPage(title: 'Profile', icon: Icons.person),
          ),
        );
        break;
    }
  }

  void _showSearchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SearchBottomSheet(userId: widget.userId),
    );
  }

  Future<void> _showVoiceSettings() async {
    final selectedVoice = await _ttsSettings.showVoiceSelector(context);
    if (!mounted || selectedVoice == null) return;

    final previewTts = FlutterTts();
    await _ttsSettings.applyTo(previewTts);
    await previewTts.speak('This is a voice preview');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Voice changed to ${selectedVoice.name}')),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final groups = await _db.getVocabularyGroups(widget.userId);
      if (!mounted) return;
      setState(() {
        _vocabularyGroups = groups;
        _isLoading = false;
      });
      unawaited(_loadReviewStats());
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data load error: $e')),
        );
      }
    }
  }

  Future<void> _loadReviewStats() async {
    try {
      final stats = await _db.getReviewStats(widget.userId);
      if (!mounted) return;
      setState(() {
        _reviewStats = stats;
      });
    } catch (e) {
      debugPrint('Review stats load failed: $e');
    }
  }

  Future<void> _createNewGroup() async {
    try {
      int nextNumber = 1;
      for (var group in _vocabularyGroups) {
        final name = group['name'] as String;
        if (name.startsWith('4000 Word List ')) {
          final numPart = int.tryParse(name.replaceAll('4000 Word List ', ''));
          if (numPart != null && numPart >= nextNumber) {
            nextNumber = numPart + 1;
          }
        }
      }
      final defaultName = '4000 Word List $nextNumber';
      final nameController = TextEditingController(text: defaultName);
      final enteredName = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Create New Group'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Enter group name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context, name);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      );
      if (enteredName == null || enteredName.isEmpty) return;
      await _db.createVocabularyGroup(widget.userId, enteredName);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created "$enteredName"')),
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

  Future<void> _deleteGroup(int groupId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete group'),
        content: const Text('Are you sure you want to delete this group? All lists and words inside will also be deleted.'),
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
        await _db.deleteVocabularyGroup(groupId);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deleted!')),
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

  Future<void> _navigateToReview() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewPage(userId: widget.userId),
      ),
    );
    if (result == true) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  Expanded(
                    child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primaryContainer,
                        ),
                        child: Icon(Icons.person, color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Vocabulary Library',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.surfaceContainerLow,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.record_voice_over, color: theme.colorScheme.primary),
                          onPressed: _showVoiceSettings,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.surfaceContainerLow,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.search, color: theme.colorScheme.primary),
                          onPressed: _showSearchDialog,
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
                          const SizedBox(height: 8),
                          _buildDailyReviewBanner(),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'My Groups',
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                '${_vocabularyGroups.length} groups',
                                style: TextStyle(
                                  fontFamily: 'Be Vietnam Pro',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_vocabularyGroups.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.folder_open, size: 64, color: theme.colorScheme.onSurfaceVariant),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No groups yet',
                                      style: TextStyle(
                                        fontFamily: 'Be Vietnam Pro',
                                        fontSize: 16,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: _vocabularyGroups.length,
                              itemBuilder: (context, index) {
                                final group = _vocabularyGroups[index];
                                return AnimatedPressable(
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => VocabularyGroupPage(
                                          userId: widget.userId,
                                          groupId: group['id'] as int,
                                          groupName: group['name'] as String,
                                        ),
                                      ),
                                    );
                                    _loadData();
                                  },
                                  child: _buildGroupFolderCard(
                                    id: group['id'] as int,
                                    title: group['name'] as String,
                                    wordCount: group['wordCount'] as int? ?? 0,
                                    listCount: group['listCount'] as int? ?? 0,
                                    progress: ((group['progress'] as int? ?? 0) / 100).clamp(0.0, 1.0),
                                    dueCount: group['dueCount'] as int? ?? 0,
                                    index: index,
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewGroup,
        backgroundColor: theme.colorScheme.primary,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Icon(Icons.add, color: theme.colorScheme.onPrimary, size: 30),
      ),
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: LingoBottomNavBar(
          currentIndex: _currentIndex,
          items: const [
            NavItem(icon: Icons.home_outlined, label: 'Home'),
            NavItem(icon: Icons.menu_book, label: 'Library'),
            NavItem(icon: Icons.query_stats_outlined, label: 'Progress'),
            NavItem(icon: Icons.person_outline, label: 'Profile'),
          ],
          onTap: _onTabTapped,
        ),
      ),
    );
  }

  Widget _buildDailyReviewBanner() {
    final colors = context.lingoColors;
    final dueToday = _reviewStats['dueToday'] ?? 0;
    final hasWordsDue = dueToday > 0;

    return GestureDetector(
      onTap: _navigateToReview,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: hasWordsDue ? colors.reviewBannerDue : colors.reviewBannerDone,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (hasWordsDue ? colors.reviewBannerDue[0] : colors.reviewBannerDone[0]).withAlpha(76),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasWordsDue ? Icons.notifications_active : Icons.check_circle,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasWordsDue ? 'Time to review!' : "You're all caught up!",
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    hasWordsDue ? '$dueToday words waiting for you' : 'Keep up the momentum',
                    style: const TextStyle(
                      fontFamily: 'Be Vietnam Pro',
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupFolderCard({
    required int id,
    required String title,
    required int wordCount,
    required int listCount,
    required double progress,
    required int dueCount,
    required int index,
  }) {
    final colors = context.lingoColors;
    final palette = colors.cardPalettes[index % colors.cardPalettes.length];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: palette[0].withAlpha(25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -20, top: -20,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: palette[0].withAlpha(13),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: palette[0].withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.folder_rounded, color: palette[0], size: 24),
                    ),
                    if (dueCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.reviewBannerDue[0],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$dueCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$listCount list | $wordCount words',
                  style: TextStyle(
                    fontFamily: 'Be Vietnam Pro',
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Stack(
                  children: [
                    Container(
                      height: 6,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress.clamp(0.05, 1.0),
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: palette),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 0, top: 0,
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: Icon(Icons.more_vert, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                onPressed: () => _showGroupOptions(id),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupOptions(int groupId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Bo Tu', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _deleteGroup(groupId);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class SearchBottomSheet extends StatefulWidget {
  final int userId;

  const SearchBottomSheet({super.key, required this.userId});

  @override
  State<SearchBottomSheet> createState() => _SearchBottomSheetState();
}

class _SearchBottomSheetState extends State<SearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await _db.searchWord(widget.userId, query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _search,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Search for a word...',
                prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _search('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          Expanded(
            child: _isSearching
                ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                : _searchResults.isEmpty && _searchController.text.isNotEmpty
                    ? Center(
                        child: Text(
                          'Word not found',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final word = _searchResults[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withAlpha(20),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  word['word'] as String,
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  word['meaning'] as String,
                                  style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.folder_outlined, size: 14, color: theme.colorScheme.primary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${word['group_name']} / ${word['set_name']}',
                                        style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
