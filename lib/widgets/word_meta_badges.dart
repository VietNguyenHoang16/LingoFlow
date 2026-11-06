import 'package:flutter/material.dart';

/// Trình độ CEFR dùng cho field `word_level`.
const List<String> kCefrLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

/// Độ thông dụng: thang điểm 1..10.
const int kCommonnessMax = 10;

/// Kết quả từ bảng chọn: [value] là giá trị mới; null nghĩa là bỏ chọn (về
/// "chưa chọn"). Hàm picker trả về null = người dùng hủy, không đổi gì.
class MetaPick<T> {
  final T? value;
  const MetaPick(this.value);
}

/// Hai chip "Trình độ" + "Độ thông dụng" của một từ, dùng ở màn Ôn tập /
/// Luyện tập. Luôn hiện cả hai để chạm vào chỉnh ngay; khi chưa chọn thì hiện
/// dạng gợi ý (mờ, có dấu +).
class WordMetaBadges extends StatelessWidget {
  final int? commonness;
  final String? wordLevel;
  final VoidCallback? onTapLevel;
  final VoidCallback? onTapCommonness;

  const WordMetaBadges({
    super.key,
    required this.commonness,
    required this.wordLevel,
    this.onTapLevel,
    this.onTapCommonness,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _MetaPill(
          text: wordLevel ?? 'Trình độ',
          active: wordLevel != null,
          tooltip: 'Trình độ từ (CEFR)',
          onTap: onTapLevel,
        ),
        _MetaPill(
          text: commonness != null ? '$commonness/$kCommonnessMax' : 'Thông dụng',
          active: commonness != null,
          tooltip: 'Độ thông dụng (1–10)',
          onTap: onTapCommonness,
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String text;
  final bool active;
  final String tooltip;
  final VoidCallback? onTap;

  const _MetaPill({
    required this.text,
    required this.active,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? theme.colorScheme.primary.withAlpha(28) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active
              ? theme.colorScheme.primary.withAlpha(90)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? Icons.check_rounded : Icons.add_rounded, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
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
    final withTooltip = Tooltip(message: tooltip, child: pill);
    if (onTap == null) return withTooltip;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: withTooltip,
    );
  }
}

/// Bảng chọn Trình độ CEFR. Trả về [MetaPick] (giá trị mới hoặc bỏ chọn),
/// null nếu người dùng hủy.
Future<MetaPick<String>?> showLevelPicker(BuildContext context, String? current) {
  final theme = Theme.of(context);
  return showModalBottomSheet<MetaPick<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _PickerSheet<String>(
      title: 'Trình độ từ (CEFR)',
      values: kCefrLevels,
      labelOf: (v) => v,
      current: current,
    ),
  );
}

/// Bảng chọn Độ thông dụng (1–10).
Future<MetaPick<int>?> showCommonnessPicker(BuildContext context, int? current) {
  final theme = Theme.of(context);
  return showModalBottomSheet<MetaPick<int>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _PickerSheet<int>(
      title: 'Độ thông dụng (1–10)',
      values: List<int>.generate(kCommonnessMax, (i) => i + 1),
      labelOf: (v) => '$v',
      current: current,
    ),
  );
}

class _PickerSheet<T> extends StatelessWidget {
  final String title;
  final List<T> values;
  final String Function(T) labelOf;
  final T? current;

  const _PickerSheet({
    required this.title,
    required this.values,
    required this.labelOf,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Chạm lại mục đang chọn để bỏ',
              style: TextStyle(
                fontFamily: 'Be Vietnam Pro',
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: values.map((v) {
                final selected = v == current;
                return GestureDetector(
                  onTap: () => Navigator.pop(context, MetaPick<T>(selected ? null : v)),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 52),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? theme.colorScheme.primary.withAlpha(40) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.primary.withAlpha(180)
                            : theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      labelOf(v),
                      style: TextStyle(
                        fontFamily: 'Be Vietnam Pro',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
