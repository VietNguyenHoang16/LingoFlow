export '../widgets/search_bottom_sheet.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/word_change_bus.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/pwa_install_banner.dart';
import '../widgets/review_banner_buttons.dart';

import 'review_page.dart';
import 'profile_page.dart';
import 'recent_page.dart';

class DashboardPage extends StatefulWidget {
  final int userId;

  const DashboardPage({super.key, required this.userId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DatabaseService _db = DatabaseService();
  Map<String, dynamic> _reviewStats = {};
  bool _isLoading = true;
  String? _loadError;
  int _currentIndex = 0;
  StreamSubscription<WordChangeEvent>? _wordChangeSub;

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _wordChangeSub =
        WordChangeBus().stream.listen((_) => _loadData(background: true));
  }

  @override
  void dispose() {
    _wordChangeSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool background = false}) async {
    if (!background) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final data = await _db.getDashboardStats(widget.userId);
      if (!mounted) return;
      setState(() {
        _reviewStats = data.reviewStats;
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
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

  Future<void> _navigateToGrammarReview() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewPage(userId: widget.userId, grammarReview: true),
      ),
    );
    if (result == true) await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: _buildCurrentTab(theme),
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: LingoBottomNavBar(
          currentIndex: _currentIndex,
          items: const [
            NavItem(icon: Icons.history_rounded, label: 'Recent'),
            NavItem(icon: Icons.repeat_rounded, label: 'Review'),
            NavItem(icon: Icons.settings_outlined, label: 'Settings'),
          ],
          onTap: _onTabTapped,
        ),
      ),
    );
  }

  Widget _buildCurrentTab(ThemeData theme) {
    switch (_currentIndex) {
      case 0:
        return RecentPage(userId: widget.userId);
      case 1:
        return SafeArea(child: _buildReviewTab(theme));
      case 2:
        return ProfilePage(userId: widget.userId);
      default:
        return RecentPage(userId: widget.userId);
    }
  }

  Widget _buildReviewTab(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Review & SRS',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Ôn tập ngắt quãng hàng ngày',
                style: TextStyle(
                  fontFamily: 'Be Vietnam Pro',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
              : _loadError != null
                  ? _buildErrorState(theme, _loadError!)
                  : RefreshIndicator(
                      color: theme.colorScheme.primary,
                      onRefresh: _loadData,
                      child: ListView(
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          _buildDailyReviewBanner(),
                          const SizedBox(height: 16),
                          const PwaInstallBanner(),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildDailyReviewBanner() {
    final dueToday = (_reviewStats['dueToday'] as int?) ?? 0;
    final grammarDue = (_reviewStats['grammarDue'] as int?) ?? 0;

    return ReviewBannerButtons(
      dueWords: dueToday,
      dueGrammar: grammarDue,
      onWordsReview: _navigateToReview,
      onGrammarReview: _navigateToGrammarReview,
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
}