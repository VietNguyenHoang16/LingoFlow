import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/animated_pressable.dart';
import '../widgets/word_type_utils.dart';
import '../widgets/word_type_badge.dart';
import '../widgets/bulk_import_dialog.dart';
import 'dart:async';

import 'review_page.dart';
import 'profile_page.dart';
import 'category_page.dart';
import 'recent_page.dart';

class DashboardPage extends StatefulWidget {
  final int userId;

  const DashboardPage({super.key, required this.userId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DatabaseService _db = DatabaseService();
  Map<String, dynamic> _categoryStats = {};
  Map<String, dynamic> _reviewStats = {};
  bool _isLoading = true;
  String? _loadError;
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfilePage(userId: widget.userId),
        ),
      );
      return;
    }
    setState(() => _currentIndex = index);
  }

  void _showSearchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SearchBottomSheet(userId: widget.userId),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final stats = await _db.getCategoryStats(widget.userId);
      if (!mounted) return;
      setState(() {
        _categoryStats = stats;
        _isLoading = false;
        _loadError = null;
      });
      unawaited(_loadReviewStats());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadReviewStats() async {
    try {
      final stats = await _db.getReviewStats(widget.userId);
      if (!mounted) return;
      setState(() => _reviewStats = stats);
    } catch (e) {
      debugPrint('Review stats load failed: $e');
    }
  }

  Future<void> _navigateToReview() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewPage(userId: widget.userId),
      ),
    );
    if (result == true) await _loadData();
  }

  Future<void> _bulkImport() async {
    final inserted = await BulkImportDialog.show(
      context,
      userId: widget.userId,
    );
    if (inserted > 0 && mounted) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã thêm $inserted từ')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _bulkImport,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const Icon(Icons.playlist_add_rounded),
        label: const Text(
          'Import',
          style: TextStyle(fontFamily: 'Be Vietnam Pro', fontWeight: FontWeight.w600),
        ),
      ),
      body: _currentIndex == 1
          ? RecentPage(userId: widget.userId)
          : SafeArea(
              child: _buildHomeBody(theme),
            ),
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: LingoBottomNavBar(
          currentIndex: _currentIndex,
          items: const [
            NavItem(icon: Icons.home_rounded, label: 'Home'),
            NavItem(icon: Icons.history_rounded, label: 'Recent'),
            NavItem(icon: Icons.person_rounded, label: 'Profile'),
          ],
          onTap: _onTabTapped,
        ),
      ),
    );
  }

  Widget _buildHomeBody(ThemeData theme) {
    return Column(
      children: [
        _buildHeader(theme),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
              : _loadError != null
                  ? _buildErrorState(theme, _loadError!)
                  : RefreshIndicator(
                      color: theme.colorScheme.primary,
                      onRefresh: _loadData,
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                            sliver: SliverToBoxAdapter(child: _buildDailyReviewBanner()),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                            sliver: SliverToBoxAdapter(child: _buildSectionHeader(theme)),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                            sliver: SliverGrid(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final key = kWordTypeKeys[index];
                                  final config = wordTypeConfig(key, context);
                                  final stats = _categoryStats[key] as Map<String, dynamic>? ?? {};
                                  return AnimatedPressable(
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => CategoryPage(
                                            userId: widget.userId,
                                            category: key,
                                          ),
                                        ),
                                      );
                                      _loadData();
                                    },
                                    child: _buildCategoryCard(
                                      key_: key,
                                      config: config,
                                      stats: stats,
                                      index: index,
                                    ),
                                  );
                                },
                                childCount: kWordTypeKeys.length,
                              ),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: 0.88,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfilePage(userId: widget.userId)),
            ),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.primaryContainer],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: theme.colorScheme.primary.withAlpha(60), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Center(child: Icon(Icons.person_rounded, color: theme.colorScheme.onPrimary, size: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LingoFlow', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: -0.5, color: theme.colorScheme.onSurface)),
                Text('Vocabulary', style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 12, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          _buildIconButton(icon: Icons.search_rounded, onTap: _showSearchDialog, theme: theme),
        ],
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onTap, required ThemeData theme}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
        ),
        child: Icon(icon, color: theme.colorScheme.onSurface, size: 20),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Categories', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: theme.colorScheme.onSurface)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withAlpha(80), borderRadius: BorderRadius.circular(20)),
            child: Text('${kWordTypeKeys.length} topics', style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
        ),
      ],
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    final isNetworkError = error.contains('ket noi') || error.contains('mang') || error.contains('Connection') || error.contains('Socket') || error.contains('Timeout');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: isNetworkError ? theme.colorScheme.primaryContainer.withAlpha(60) : theme.colorScheme.errorContainer.withAlpha(60),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(isNetworkError ? Icons.wifi_off_rounded : Icons.error_outline_rounded, size: 40, color: isNetworkError ? theme.colorScheme.primary : theme.colorScheme.error),
            ),
            const SizedBox(height: 20),
            Text(isNetworkError ? 'No connection' : 'Failed to load data', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 18, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text(isNetworkError ? 'Check your connection and try again' : error, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 13, color: theme.colorScheme.onSurfaceVariant, height: 1.5)),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyReviewBanner() {
    final colors = context.lingoColors;
    final dueToday = _reviewStats['dueToday'] ?? 0;
    final hasWordsDue = dueToday > 0;
    final bannerColors = hasWordsDue ? colors.reviewBannerDue : colors.reviewBannerDone;

    return GestureDetector(
      onTap: _navigateToReview,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: bannerColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: bannerColors[0].withAlpha(70), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(16)),
              child: Center(child: Text(hasWordsDue ? '\u{1F4DA}' : '\u{2705}', style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hasWordsDue ? 'Time to review!' : 'All done!', style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.2)),
                  const SizedBox(height: 3),
                  Text(hasWordsDue ? '$dueToday words waiting for you' : 'Keep your streak going!', style: const TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required String key_,
    required Map<String, dynamic> config,
    required Map<String, dynamic> stats,
    required int index,
  }) {
    final theme = Theme.of(context);
    final colors = context.lingoColors;
    final palette = colors.cardPalettes[index % colors.cardPalettes.length];
    final isDark = theme.brightness == Brightness.dark;
    final wordCount = (stats['wordCount'] as int?) ?? 0;
    final dueCount = (stats['dueCount'] as int?) ?? 0;
    final progress = ((stats['progress'] as int?) ?? 0) / 100;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerLow : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette[0].withAlpha(isDark ? 40 : 30), width: 1.5),
        boxShadow: isDark ? null : [
          BoxShadow(color: palette[0].withAlpha(22), blurRadius: 20, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(right: -24, top: -24,
            child: Container(width: 100, height: 100,
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [palette[0].withAlpha(isDark ? 25 : 18), palette[0].withAlpha(0)]),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: palette, begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: palette[0].withAlpha(60), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Icon(config['icon'] as IconData, color: Colors.white, size: 22),
                    ),
                    if (dueCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.reviewBannerDue[0],
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: colors.reviewBannerDue[0].withAlpha(60), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Text('$dueCount', style: const TextStyle(fontFamily: 'Plus Jakarta Sans', color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
                const Spacer(),
                Text(config['label'] as String, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: theme.colorScheme.onSurface, height: 1.3)),
                const SizedBox(height: 6),
                Text('$wordCount words', style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Progress', style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 10, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant.withAlpha(160))),
                        Text('${(progress * 100).round()}%', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10, fontWeight: FontWeight.w800, color: palette[0])),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          Container(height: 5, width: double.infinity, color: palette[0].withAlpha(isDark ? 40 : 25)),
                          FractionallySizedBox(
                            widthFactor: progress.clamp(0.0, 1.0) == 0 ? 0.04 : progress.clamp(0.0, 1.0),
                            child: Container(height: 5, decoration: BoxDecoration(gradient: LinearGradient(colors: palette))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Search Bottom Sheet
// ============================================================

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
      setState(() { _searchResults = []; _isSearching = false; });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await _db.searchWord(widget.userId, query);
      if (!mounted) return;
      setState(() { _searchResults = results; _isSearching = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: _search,
                    style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 16, color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search words...',
                      prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.primary, size: 22),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurfaceVariant),
                              onPressed: () { _searchController.clear(); _search(''); },
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isSearching
                ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                : _searchResults.isEmpty && _searchController.text.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('\u{1F50D}', style: const TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text('No word found', style: TextStyle(fontFamily: 'Be Vietnam Pro', color: theme.colorScheme.onSurfaceVariant, fontSize: 16)),
                          ],
                        ),
                      )
                    : _searchResults.isEmpty
                        ? Center(
                            child: Text('Type to search', style: TextStyle(fontFamily: 'Be Vietnam Pro', color: theme.colorScheme.onSurfaceVariant, fontSize: 15)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final word = _searchResults[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(word['word'] as String, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 17, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
                                    const SizedBox(height: 4),
                                    Text(word['meaning'] as String, style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
                                    if ((word['word_type'] as String? ?? '').trim().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Builder(builder: (context) {
                                        final tokens = (word['word_type'] as String).split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                                        return Wrap(spacing: 4, runSpacing: 4, children: tokens.map((t) => WordTypeBadge(typeKey: t, compact: true)).toList());
                                      }),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.folder_outlined, size: 13, color: theme.colorScheme.primary),
                                        const SizedBox(width: 5),
                                        Icon(Icons.label_outline, size: 13, color: theme.colorScheme.primary),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text('${word['category'] ?? ''} / ${word['list_name'] ?? ''}',
                                            style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                                            overflow: TextOverflow.ellipsis),
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
