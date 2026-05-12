import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/tts_settings_service.dart';
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
        // Determine default group name based on existing groups.
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
        // Prompt user for group name, pre‑filled with the default suggestion.
        final nameController = TextEditingController(text: defaultName);
        final enteredName = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Create New Group'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'Enter group name',
              ),
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
        // Abort if user cancelled or entered empty name.
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
    const Color primary = Color(0xFF4a40e0);
    const Color primaryContainer = Color(0xFF9795ff);
    const Color surface = Color(0xFFfaf4ff);
    const Color surfaceContainerLow = Color(0xFFf5eeff);
    const Color onSurface = Color(0xFF32294f);
    const Color onSurfaceVariant = Color(0xFF5f557f);
    return Scaffold(
      backgroundColor: surface,
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
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryContainer,
                        ),
                        child: const Icon(Icons.person, color: onSurface),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Vocabulary Library',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: onSurface,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: surfaceContainerLow,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.record_voice_over, color: primary),
                          onPressed: _showVoiceSettings,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: surfaceContainerLow,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.search, color: primary),
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
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildDailyReviewBanner(
                            primary: primary,
                            onSurface: onSurface,
                            onSurfaceVariant: onSurfaceVariant,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'My Groups',
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: onSurface,
                                ),
                              ),
                              Text(
                                '${_vocabularyGroups.length} groups',
                                style: const TextStyle(
                                  fontFamily: 'Be Vietnam Pro',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_vocabularyGroups.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              child: const Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.folder_open, size: 64, color: onSurfaceVariant),
                                    SizedBox(height: 16),
                                    Text(
                                      'No groups yet',
                                      style: TextStyle(
                                        fontFamily: 'Be Vietnam Pro',
                                        fontSize: 16,
                                        color: onSurfaceVariant,
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
                                return GestureDetector(
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
        backgroundColor: primary,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: surface.withValues(alpha: 0.8),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF32294f).withValues(alpha: 0.06),
              blurRadius: 32,
              offset: const Offset(0, -12),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            GestureDetector(
              onTap: () => _onTabTapped(0),
              child: _buildNavItem(Icons.home_outlined, 'Home', isActive: _currentIndex == 0),
            ),
            GestureDetector(
              onTap: () => _onTabTapped(1),
              child: _buildNavItem(Icons.menu_book, 'Library', isActive: _currentIndex == 1),
            ),
            GestureDetector(
              onTap: () => _onTabTapped(2),
              child: _buildNavItem(Icons.query_stats_outlined, 'Progress', isActive: _currentIndex == 2),
            ),
            GestureDetector(
              onTap: () => _onTabTapped(3),
              child: _buildNavItem(Icons.person_outline, 'Profile', isActive: _currentIndex == 3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyReviewBanner({
    required Color primary,
    required Color onSurface,
    required Color onSurfaceVariant,
  }) {
    final dueToday = _reviewStats['dueToday'] ?? 0;
    final hasWordsDue = dueToday > 0;

    return GestureDetector(
      onTap: _navigateToReview,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: hasWordsDue
              ? const LinearGradient(
                  colors: [Color(0xFFff6b35), Color(0xFFffa726)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFF2d8f4e), Color(0xFF4ade80)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (hasWordsDue ? const Color(0xFFff6b35) : const Color(0xFF2d8f4e)).withValues(alpha: 0.3),
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
                color: Colors.white.withValues(alpha: 0.2),
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
                    hasWordsDue ? 'Time to review!' : 'You\'re all caught up!',
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
    final List<List<Color>> palettes = [
      [const Color(0xFF6366f1), const Color(0xFF818cf8)],
      [const Color(0xFFfb7185), const Color(0xFFfda4af)],
      [const Color(0xFF34d399), const Color(0xFF6ee7b7)],
      [const Color(0xFFfbbf24), const Color(0xFFfcd34d)],
      [const Color(0xFF8b5cf6), const Color(0xFFa78bfa)],
    ];
    final palette = palettes[index % palettes.length];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: palette[0].withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: palette[0].withValues(alpha: 0.05),
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
                        color: palette[0].withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.folder_rounded,
                        color: palette[0],
                        size: 24,
                      ),
                    ),
                    if (dueCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFff6b35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$dueCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1f2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$listCount list | $wordCount words',
                  style: TextStyle(
                    fontFamily: 'Be Vietnam Pro',
                    fontSize: 12,
                    color: Colors.grey.shade500,
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
                        color: Colors.grey.shade100,
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
            right: 0,
            top: 0,
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
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
      backgroundColor: Colors.white,
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

  Widget _buildNavItem(IconData icon, String label, {required bool isActive}) {
    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFfed01b),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF433500)),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Be Vietnam Pro',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF433500),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF64748b)),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Be Vietnam Pro',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748b),
          ),
        ),
      ],
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFfaf4ff),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
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
                prefixIcon: const Icon(Icons.search, color: Color(0xFF4a40e0)),
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
                fillColor: Colors.white,
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
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty && _searchController.text.isNotEmpty
                    ? const Center(
                        child: Text(
                          'Word not found',
                          style: TextStyle(
                            color: Color(0xFF5f557f),
                            fontSize: 16,
                          ),
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4a40e0).withValues(alpha: 0.08),
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
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1f2937),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  word['meaning'] as String,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF5f557f),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.folder_outlined,
                                      size: 14,
                                      color: Color(0xFF4a40e0),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${word['group_name']} / ${word['set_name']}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF4a40e0),
                                          fontWeight: FontWeight.w600,
                                        ),
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
