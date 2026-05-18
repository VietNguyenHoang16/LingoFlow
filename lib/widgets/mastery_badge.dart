import 'package:flutter/material.dart';
import 'mastery_utils.dart';

class MasteryBadge extends StatelessWidget {
  final int level;
  const MasteryBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final config = masteryConfig(level, context);
    final color = config['color'] as Color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config['icon'] as IconData, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            config['label'] as String,
            style: TextStyle(
              fontFamily: 'Be Vietnam Pro',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
