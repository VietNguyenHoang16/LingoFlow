import 'package:flutter/material.dart';

import '../services/meaning_choice_options.dart';
import 'animated_pressable.dart';

/// Cach tra loi khi on tap / luyen tap: go tu hoac chon nghia.
/// Chon truoc khi vao phien, khong doi trong phien.
enum AnswerInputMode { typing, choice }

/// Danh sách nút lựa chọn nghĩa cho chế độ "nhìn từ chọn nghĩa".
/// Stateless: trang cha giữ trạng thái đã trả lời (hiện đáp án + chấm điểm).
class MeaningChoiceCard extends StatelessWidget {
  const MeaningChoiceCard({
    super.key,
    required this.options,
    required this.onSelected,
    this.compact = false,
  });

  final List<MeaningOption> options;
  final ValueChanged<int> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AnimatedPressable(
              onTap: () => onSelected(i),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: compact ? 12 : 14,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    // Chip so 1-4: phim tat tren ban phim cung (web/PC/iPad).
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(28),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                          fontFamily: 'Be Vietnam Pro',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        options[i].meaning,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 14 : 15,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: theme.colorScheme.onSurface,
                          fontFamily: 'Be Vietnam Pro',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
