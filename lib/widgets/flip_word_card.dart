import 'dart:math' as math;

import 'package:flutter/material.dart';

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
          return Transform(
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
      height: 1.5,
    );
    // Light mode: accent tren nen nhat tuong phan thap -> dung cham dam.
    final highlight = theme.brightness == Brightness.dark
        ? accent
        : const Color(0xFF3730A3);
    final target = (exampleTarget ?? '').trim();
    if (target.isEmpty || !example.toLowerCase().contains(target.toLowerCase())) {
      return Text(example, maxLines: 3, overflow: TextOverflow.ellipsis, style: baseStyle);
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
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
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
        gradient: LinearGradient(
          colors: [
            accent.withAlpha(22),
            theme.colorScheme.surfaceContainerLowest,
            theme.colorScheme.surfaceContainerLow,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
          const SizedBox(height: 10),
          Text(
            meaning,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest.withAlpha(160),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildExampleSentence(),
                  if (exampleTranslation != null && exampleTranslation!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '→ ${exampleTranslation!}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Be Vietnam Pro',
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
