import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LingoBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final List<NavItem> items;
  final void Function(int index)? onTap;

  const LingoBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.items,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.lingoColors;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.surfaceContainerLowest,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(12),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final isActive = i == currentIndex;
          return GestureDetector(
            onTap: () => onTap?.call(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: isActive ? 20 : 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isActive ? colors.navActiveBg : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    items[i].icon,
                    color: isActive
                        ? colors.navActiveContent
                        : colors.navInactiveContent,
                    size: 22,
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 6),
                    Text(
                      items[i].label,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.navActiveContent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class NavItem {
  final IconData icon;
  final String label;
  const NavItem({required this.icon, required this.label});
}
