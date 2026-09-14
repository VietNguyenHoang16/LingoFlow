import 'package:flutter/material.dart';

/// Panel ví dụ kiểu mặt sau flashcard cho màn Review.
/// Nền sáng, chữ tối — đặt dưới thẻ đáp án gradient sau khi người dùng
/// nhập từ (hoặc bấm Show answer ở chế độ grammar).
/// Trả [SizedBox.shrink] khi [example] rỗng.
class ReviewExamplePanel extends StatelessWidget {
  final String word;
  final String example;
  final String? translation;
  final String? target;
  final Color accent;
  final bool compact;
  final VoidCallback onSpeak;

  const ReviewExamplePanel({
    super.key,
    required this.word,
    required this.example,
    this.translation,
    this.target,
    required this.accent,
    this.compact = false,
    required this.onSpeak,
  });

  Widget _buildSentence(ThemeData theme) {
    final baseStyle = TextStyle(
      fontFamily: 'Be Vietnam Pro',
      fontSize: compact ? 13 : 14,
      color: theme.colorScheme.onSurface,
      height: 1.5,
    );
    final t = (target ?? '').trim();
    if (t.isEmpty || !example.toLowerCase().contains(t.toLowerCase())) {
      return Text(example, maxLines: 3, overflow: TextOverflow.ellipsis, style: baseStyle);
    }
    final idx = example.toLowerCase().indexOf(t.toLowerCase());
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: example.substring(0, idx)),
          TextSpan(
            text: example.substring(idx, idx + t.length),
            style: TextStyle(fontWeight: FontWeight.w700, color: accent),
          ),
          TextSpan(text: example.substring(idx + t.length)),
        ],
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (example.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(20, compact ? 8 : 12, 20, 0),
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  word,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: compact ? 18 : 20,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Định nghĩa & Ví dụ',
                  style: TextStyle(
                    fontFamily: 'Be Vietnam Pro',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSentence(theme),
                if (translation != null && translation!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '→ ${translation!}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Be Vietnam Pro',
                      fontSize: compact ? 12 : 13,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: compact ? 8 : 12),
          Row(
            children: [
              GestureDetector(
                onTap: onSpeak,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.volume_up_rounded, color: accent, size: 22),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Nghe phát âm câu ví dụ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Be Vietnam Pro',
                    fontSize: 12,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
