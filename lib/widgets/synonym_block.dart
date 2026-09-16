import 'package:flutter/material.dart';

/// Block synonyms mặt sau flashcard: tối đa 3 từ phổ biến nhất,
/// render chips Wrap (đủ chữ, không ellipsis). Rỗng -> shrink.
class SynonymBlock extends StatelessWidget {
  final String common;
  final Color accent;

  const SynonymBlock({
    super.key,
    this.common = '',
    required this.accent,
  });

  static List<String> split(String raw, {int? limit}) {
    final parts = raw
        .split(RegExp(r'[·,;|/\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final seen = <String>{};
    final out = <String>[];
    for (final p in parts) {
      final k = p.toLowerCase();
      if (seen.add(k)) out.add(p);
      if (limit != null && out.length >= limit) break;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commons = split(common, limit: 3);
    if (commons.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest.withAlpha(160),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sync_alt_rounded, size: 14, color: accent.withAlpha(180)),
              const SizedBox(width: 6),
              Text(
                'Common:',
                style: TextStyle(
                  fontFamily: 'Be Vietnam Pro',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: commons
                .map(
                  (s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withAlpha(22),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withAlpha(55)),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        fontFamily: 'Be Vietnam Pro',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
