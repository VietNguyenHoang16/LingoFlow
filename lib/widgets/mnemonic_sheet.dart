import 'package:flutter/material.dart';

/// Nút nhỏ "Mẹo nhớ" — chỉ hiện khi từ có mẹo nhớ.
class MnemonicChip extends StatelessWidget {
  final String word;
  final String mnemonic;
  final Color? accent;
  final bool compact;

  const MnemonicChip({
    super.key,
    required this.word,
    required this.mnemonic,
    this.accent,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = mnemonic.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    final color = accent ?? Theme.of(context).colorScheme.primary;

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => showMnemonicSheet(
            context: context,
            word: word,
            mnemonic: text,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 12,
              vertical: compact ? 5 : 7,
            ),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withAlpha(60)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: compact ? 14 : 16,
                  color: color,
                ),
                const SizedBox(width: 5),
                Text(
                  'Mẹo nhớ',
                  style: TextStyle(
                    fontFamily: 'Be Vietnam Pro',
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mở mẹo nhớ trong bottom sheet cuộn được (đoạn dài không chiếm hết màn hình).
Future<void> showMnemonicSheet({
  required BuildContext context,
  required String word,
  required String mnemonic,
}) {
  final theme = Theme.of(context);
  final accent = theme.colorScheme.primary;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Icon(Icons.lightbulb_rounded, size: 20, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  word,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Đóng',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            mnemonic.trim(),
            style: TextStyle(
              fontFamily: 'Be Vietnam Pro',
              fontSize: 15,
              height: 1.65,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    ),
  );
}
