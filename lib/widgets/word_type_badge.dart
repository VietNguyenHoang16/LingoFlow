import 'package:flutter/material.dart';
import 'word_type_utils.dart';

class WordTypeBadge extends StatelessWidget {
  final String typeKey;
  final bool compact;
  final double? fontSize;

  const WordTypeBadge({
    super.key,
    required this.typeKey,
    this.compact = false,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    if (typeKey.isEmpty || !kWordTypeLabel.containsKey(typeKey)) {
      return const SizedBox.shrink();
    }
    final config = wordTypeConfig(typeKey, context);
    final color = config['color'] as Color;
    final label = compact
        ? config['shortLabel'] as String
        : config['label'] as String;
    final size = fontSize ?? (compact ? 11.0 : 11.0);

    final pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(compact ? 30 : 25),
        borderRadius: BorderRadius.circular(compact ? 10 : 14),
        border: Border.all(color: color.withAlpha(compact ? 80 : 50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            Icon(config['icon'] as IconData, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Be Vietnam Pro',
              fontSize: size,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );

    return Tooltip(
      message: config['label'] as String,
      child: pill,
    );
  }
}
