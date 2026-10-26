import 'package:flutter/material.dart';

/// Hai nut on tap tren Dashboard / Review tab: tu vung den han + cau truc (grammar) den han.
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
    return Row(
      children: [
        Expanded(
          child: _ReviewButton(
            dueCount: dueWords,
            dueLabel: 'words due',
            dueTitle: 'Time to review!',
            doneSubtitle: 'Keep your streak going!',
            icon: Icons.style_outlined,
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
            icon: Icons.menu_book_outlined,
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
  final IconData icon;
  final VoidCallback onTap;

  const _ReviewButton({
    required this.dueCount,
    required this.dueLabel,
    required this.dueTitle,
    required this.doneSubtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDue = dueCount > 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 124,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Den thuần chữ trắng khi còn bài cần ôn; trắng khi đã xong.
          color: hasDue
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasDue
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: hasDue
                        ? theme.colorScheme.onPrimary.withAlpha(40)
                        : theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      hasDue ? icon : Icons.check_rounded,
                      size: 18,
                      color: hasDue
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: hasDue
                      ? theme.colorScheme.onPrimary.withAlpha(200)
                      : theme.colorScheme.onSurfaceVariant,
                  size: 16,
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
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: hasDue
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasDue ? '$dueCount $dueLabel' : doneSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Be Vietnam Pro',
                    fontSize: 12,
                    color: hasDue
                        ? theme.colorScheme.onPrimary.withAlpha(220)
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}