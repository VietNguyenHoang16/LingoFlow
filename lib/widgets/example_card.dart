import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ExampleCard extends StatelessWidget {
  final String example;
  final String? pos;
  final String? translation;

  const ExampleCard({
    super.key,
    required this.example,
    this.pos,
    this.translation,
  });

  @override
  Widget build(BuildContext context) {
    if (example.isEmpty) return const SizedBox.shrink();

    final fallback = Theme.of(context).colorScheme.onSurfaceVariant;
    final accentColor = pos != null
        ? (context.lingoColors.wordTypeColors[pos!] ?? fallback)
        : fallback;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withAlpha(40)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.format_quote_rounded,
                        size: 14,
                        color: accentColor.withAlpha(150),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ví dụ:',
                        style: TextStyle(
                          fontFamily: 'Be Vietnam Pro',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accentColor.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Khong gioi han dong: vi du dai hien thi tron ven (truoc
                  // day bi cat o 2 dong + ellipsis).
                  Text(
                    example,
                    style: TextStyle(
                      fontFamily: 'Be Vietnam Pro',
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: accentColor.withAlpha(180),
                      height: 1.5,
                    ),
                  ),
                  if (translation != null && translation!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      translation!,
                      style: TextStyle(
                        fontFamily: 'Be Vietnam Pro',
                        fontSize: 12,
                        color: accentColor.withAlpha(150),
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}