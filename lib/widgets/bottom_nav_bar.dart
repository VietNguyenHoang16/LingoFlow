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
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(220),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withAlpha(15),
            blurRadius: 32,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final isActive = i == currentIndex;
          return GestureDetector(
            onTap: () => onTap?.call(i),
            child: _NavItemWidget(
              item: items[i],
              isActive: isActive,
              activeBg: colors.navActiveBg,
              activeContent: colors.navActiveContent,
              inactiveContent: colors.navInactiveContent,
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

class _NavItemWidget extends StatelessWidget {
  final NavItem item;
  final bool isActive;
  final Color activeBg;
  final Color activeContent;
  final Color inactiveContent;

  const _NavItemWidget({
    required this.item,
    required this.isActive,
    required this.activeBg,
    required this.activeContent,
    required this.inactiveContent,
  });

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: activeBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, color: activeContent, size: 22),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontFamily: 'Be Vietnam Pro',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: activeContent,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, color: inactiveContent, size: 22),
        const SizedBox(height: 4),
        Text(
          item.label,
          style: TextStyle(
            fontFamily: 'Be Vietnam Pro',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: inactiveContent,
          ),
        ),
      ],
    );
  }
}
