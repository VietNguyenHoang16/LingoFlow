import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Hai nut on tap tren Dashboard: tu vung den han + cau truc (grammar) den han.
///
/// Luu y layout: widget nay nam trong SliverToBoxAdapter cua CustomScrollView
/// -> nhan chieu cao unbounded. KHONG duoc dung Flex children (Spacer/
/// Expanded trong Column doc lap) o day; chieu cao nut la co dinh.
class ReviewBannerButtons extends StatelessWidget {
  final int dueWords;
  final int dueGrammar;
  final VoidCallback onWordsReview;
  final VoidCallback onGrammarReview;

  const ReviewBannerButtons({
    super.key,
    required this.dueWords,
    required this.dueGrammar,
    required this.onWordsReview,
    required this.onGrammarReview,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.lingoColors;

    return Row(
      children: [
        Expanded(
          child: _ReviewButton(
            dueCount: dueWords,
            dueLabel: 'words due',
            dueTitle: 'Time to review!',
            doneSubtitle: 'Keep your streak going!',
            gradient: dueWords > 0 ? colors.reviewBannerDue : colors.reviewBannerDone,
            onTap: onWordsReview,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ReviewButton(
            dueCount: dueGrammar,
            dueLabel: 'structures due',
            dueTitle: 'Grammar time!',
            doneSubtitle: 'No structures due!',
            gradient: dueGrammar > 0 ? colors.reviewBannerGrammar : colors.reviewBannerDone,
            onTap: onGrammarReview,
          ),
        ),
      ],
    );
  }
}

class _ReviewButton extends StatelessWidget {
  final int dueCount;
  final String dueLabel;
  final String dueTitle;
  final String doneSubtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ReviewButton({
    required this.dueCount,
    required this.dueLabel,
    required this.dueTitle,
    required this.doneSubtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDue = dueCount > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Chieu cao co dinh: an toan trong moi context (ke ca unbounded sliver).
        height: 128,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: gradient[0].withAlpha(70), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // spaceBetween thay cho Spacer: khong can constraint co dinh tu cha.
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(hasDue ? '\u{1F4DA}' : '\u{2705}', style: const TextStyle(fontSize: 20))),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 15),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasDue ? dueTitle : 'All done!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.2),
                ),
                const SizedBox(height: 2),
                Text(
                  hasDue ? '$dueCount $dueLabel' : doneSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
