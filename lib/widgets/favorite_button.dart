import 'package:flutter/material.dart';

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.isFavorite,
    this.onTap,
    this.count,
    this.size = 20,
    this.tooltip,
  });

  final bool isFavorite;
  final VoidCallback? onTap;
  final int? count;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isFavorite ? const Color(0xFFE11D48) : theme.colorScheme.onSurfaceVariant;
    final icon = Icon(
      isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      color: color,
      size: size,
    );
    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: count == null
            ? icon
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  if (count! > 0) ...[
                    const SizedBox(width: 2),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
