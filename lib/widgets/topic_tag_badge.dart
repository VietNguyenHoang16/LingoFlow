import 'package:flutter/material.dart';

/// Chip nhãn chủ đề tự do của từ vựng. Rỗng thì ẩn.
class TopicTagBadge extends StatelessWidget {
  final String tag;
  final bool onColoredSurface;
  final double maxWidth;

  const TopicTagBadge({
    super.key,
    required this.tag,
    this.onColoredSurface = false,
    this.maxWidth = 100,
  });

  @override
  Widget build(BuildContext context) {
    if (tag.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final color = theme.colorScheme.tertiary;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: onColoredSurface
              ? theme.colorScheme.onPrimary.withAlpha(35)
              : color.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: onColoredSurface
                ? theme.colorScheme.onPrimary.withAlpha(90)
                : color.withAlpha(80),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sell_outlined, size: 11, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                tag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Be Vietnam Pro',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
