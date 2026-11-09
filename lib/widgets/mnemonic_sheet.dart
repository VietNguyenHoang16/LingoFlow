import 'package:flutter/material.dart';

/// Nút nhỏ "Mẹo nhớ". Có [onEdit] thì luôn hiện (rỗng = "Thêm mẹo nhớ");
/// không có [onEdit] thì chỉ hiện khi từ đã có mẹo nhớ.
class MnemonicChip extends StatelessWidget {
  final String word;
  final String mnemonic;
  final Color? accent;
  final bool compact;
  final Future<void> Function()? onEdit;

  const MnemonicChip({
    super.key,
    required this.word,
    required this.mnemonic,
    this.accent,
    this.compact = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final text = mnemonic.trim();
    final hasText = text.isNotEmpty;
    if (!hasText && onEdit == null) return const SizedBox.shrink();
    final color = accent ?? Theme.of(context).colorScheme.primary;

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            if (hasText) {
              showMnemonicSheet(
                context: context,
                word: word,
                mnemonic: text,
                onEdit: onEdit,
              );
            } else {
              onEdit?.call();
            }
          },
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
                  hasText
                      ? Icons.lightbulb_outline_rounded
                      : Icons.add_circle_outline_rounded,
                  size: compact ? 14 : 16,
                  color: color,
                ),
                const SizedBox(width: 5),
                Text(
                  hasText ? 'Mẹo nhớ' : 'Thêm mẹo nhớ',
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

/// Icon nhỏ cạnh từ (dùng ở màn Ôn tập / Luyện tập) — không chiếm thêm chiều cao.
class MnemonicIconButton extends StatelessWidget {
  final String word;
  final String mnemonic;
  final Color? accent;
  final Future<void> Function()? onEdit;
  final double size;

  const MnemonicIconButton({
    super.key,
    required this.word,
    required this.mnemonic,
    this.accent,
    this.onEdit,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final text = mnemonic.trim();
    final hasText = text.isNotEmpty;
    if (!hasText && onEdit == null) return const SizedBox.shrink();
    final color = accent ?? Theme.of(context).colorScheme.primary;

    return IconButton(
      onPressed: () {
        if (hasText) {
          showMnemonicSheet(
            context: context,
            word: word,
            mnemonic: text,
            onEdit: onEdit,
          );
        } else {
          onEdit?.call();
        }
      },
      icon: Icon(
        hasText ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
        size: size,
        color: color,
      ),
      tooltip: hasText ? 'Mẹo nhớ' : 'Thêm mẹo nhớ',
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints(minWidth: size + 12, minHeight: size + 12),
    );
  }
}

/// Mở mẹo nhớ trong bottom sheet cuộn được (đoạn dài không chiếm hết màn hình).
Future<void> showMnemonicSheet({
  required BuildContext context,
  required String word,
  required String mnemonic,
  Future<void> Function()? onEdit,
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
              if (onEdit != null)
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onEdit();
                  },
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Sửa mẹo nhớ',
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
