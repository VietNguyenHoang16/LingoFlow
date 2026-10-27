import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'synonym_block.dart';
import 'topic_tag_badge.dart';
import 'word_type_badge.dart';

/// Flashcard 3D lật mặt trước/sau dùng chung cho Recent + Category.
/// Mặt trước: badges, từ lớn căn giữa + loa, phiên âm, gợi ý lật.
/// Mặt sau: nghĩa + hộp ví dụ (câu + dịch) theo mẫu tham khảo.
/// Nút sửa/xóa KHÔNG nằm trên card — long-press để mở menu thao tác.
class FlipWordCard extends StatefulWidget {
  final bool isFlipped;
  final String word;
  final String pronunciation;
  final String meaning;
  final String wordType;
  final String topicTag;
  final String? metaLabel;
  final String? createdLabel;
  final String example;
  final String? exampleTranslation;
  final String? exampleTarget;
  final String commonSynonyms;
  final Color accent;
  final bool isDifficult;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onSpeak;

  const FlipWordCard({
    super.key,
    required this.isFlipped,
    required this.word,
    required this.pronunciation,
    required this.meaning,
    required this.wordType,
    required this.topicTag,
    this.metaLabel,
    this.createdLabel,
    required this.example,
    this.exampleTranslation,
    this.exampleTarget,
    this.commonSynonyms = '',
    required this.accent,
    this.isDifficult = false,
    required this.onTap,
    required this.onLongPress,
    required this.onSpeak,
  });

  @override
  State<FlipWordCard> createState() => _FlipWordCardState();
}

class _FlipWordCardState extends State<FlipWordCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    if (widget.isFlipped) _controller.value = 1;
  }

  @override
  void didUpdateWidget(FlipWordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      if (widget.isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final showBack = _animation.value >= 0.5;
          // Mat sau cao hon mat truoc khi vi du dai -> de chieu cao chay muot
          // thay vi nhay giat luc lat the.
          return AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(math.pi * _animation.value),
              child: showBack
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(math.pi),
                      child: _CardBack(
                        word: widget.word,
                        pronunciation: widget.pronunciation,
                        meaning: widget.meaning,
                        example: widget.example,
                        exampleTranslation: widget.exampleTranslation,
                        exampleTarget: widget.exampleTarget,
                        commonSynonyms: widget.commonSynonyms,
                        accent: widget.accent,
                        theme: theme,
                        onSpeak: widget.onSpeak,
                      ),
                    )
                  : _CardFront(
                      word: widget.word,
                      pronunciation: widget.pronunciation,
                      wordType: widget.wordType,
                      topicTag: widget.topicTag,
                      metaLabel: widget.metaLabel,
                      createdLabel: widget.createdLabel,
                      isDifficult: widget.isDifficult,
                      accent: widget.accent,
                      theme: theme,
                      onSpeak: widget.onSpeak,
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  final String word;
  final String pronunciation;
  final String wordType;
  final String topicTag;
  final String? metaLabel;
  final String? createdLabel;
  final bool isDifficult;
  final Color accent;
  final ThemeData theme;
  final VoidCallback onSpeak;

  const _CardFront({
    required this.word,
    required this.pronunciation,
    required this.wordType,
    required this.topicTag,
    this.metaLabel,
    this.createdLabel,
    required this.isDifficult,
    required this.accent,
    required this.theme,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (wordType.isNotEmpty) WordTypeBadge(typeKey: wordType, compact: true),
              if (topicTag.isNotEmpty) TopicTagBadge(tag: topicTag),
              if (createdLabel != null && createdLabel!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    createdLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Be Vietnam Pro',
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        word,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onSpeak,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accent.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.volume_up_rounded, color: accent, size: 22),
                      ),
                    ),
                  ],
                ),
                if (pronunciation.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '/$pronunciation/',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Be Vietnam Pro',
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            children: [
              if (isDifficult)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 15, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      'Từ khó',
                      style: TextStyle(
                        fontFamily: 'Be Vietnam Pro',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                )
              else if (metaLabel != null && metaLabel!.isNotEmpty)
                Flexible(
                  child: Text(
                    metaLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Be Vietnam Pro',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flip_rounded, size: 15, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    'Chạm để lật',
                    style: TextStyle(
                      fontFamily: 'Be Vietnam Pro',
                      fontSize: 12,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  final String word;
  final String pronunciation;
  final String meaning;
  final String example;
  final String? exampleTranslation;
  final String? exampleTarget;
  final String commonSynonyms;
  final Color accent;
  final ThemeData theme;
  final VoidCallback onSpeak;

  const _CardBack({
    required this.word,
    required this.pronunciation,
    required this.meaning,
    required this.example,
    this.exampleTranslation,
    this.exampleTarget,
    this.commonSynonyms = '',
    required this.accent,
    required this.theme,
    required this.onSpeak,
  });

  Widget _buildExampleSentence() {
    final baseStyle = TextStyle(
      fontFamily: 'Be Vietnam Pro',
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: theme.colorScheme.onSurface,
      height: 1.55,
    );
    // Light mode: nen trang sach -> nhu cao tu can hoc bang den dam.
    final highlight = theme.brightness == Brightness.dark
        ? accent
        : theme.colorScheme.onSurface;
    final target = (exampleTarget ?? '').trim();
    // Khong gioi han dong: vi du dai hien thi tron ven, the tu cao len va
    // danh sach cuon de doc tiep (truoc day bi cat o 3 dong + ellipsis).
    if (target.isEmpty || !example.toLowerCase().contains(target.toLowerCase())) {
      return Text(example, style: baseStyle);
    }
    final lower = example.toLowerCase();
    final idx = lower.indexOf(target.toLowerCase());
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: example.substring(0, idx)),
          TextSpan(
            text: example.substring(idx, idx + target.length),
            style: TextStyle(fontWeight: FontWeight.w700, color: highlight),
          ),
          TextSpan(text: example.substring(idx + target.length)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
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
                    fontSize: 20,
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
                  borderRadius: BorderRadius.circular(14),
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
          const SizedBox(height: 10),
          // Nghia hien thi du (khong gioi han dong) - nghia dai van doc duoc het.
          Text(
            meaning,
            style: TextStyle(
              fontFamily: 'Be Vietnam Pro',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (pronunciation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '/$pronunciation/',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Be Vietnam Pro',
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (example.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                // Nen tint nhe + vien accent mo: cau vi du dai van tach khoi
                // phan nghia thay vi thanh mot khoi chu lien mach.
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withAlpha(40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.format_quote_rounded,
                        size: 14,
                        color: accent.withAlpha(150),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ví dụ',
                        style: TextStyle(
                          fontFamily: 'Be Vietnam Pro',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: accent.withAlpha(190),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildExampleSentence(),
                  if (exampleTranslation != null && exampleTranslation!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '→ ${exampleTranslation!}',
                      style: TextStyle(
                        fontFamily: 'Be Vietnam Pro',
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          SynonymBlock(
            common: commonSynonyms,
            accent: accent,
          ),
          const SizedBox(height: 12),
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
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flip_rounded, size: 15, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    'Chạm để lật lại',
                    style: TextStyle(
                      fontFamily: 'Be Vietnam Pro',
                      fontSize: 12,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
