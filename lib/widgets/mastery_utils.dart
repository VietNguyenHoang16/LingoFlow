import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

Map<String, dynamic> masteryConfig(int level, BuildContext context) {
  final colors = context.lingoColors;
  switch (level) {
    case 0:
      return {'label': 'Mới', 'color': colors.masteryNew, 'icon': Icons.fiber_new};
    case 1:
      return {'label': 'Đang học', 'color': colors.masteryLearning, 'icon': Icons.menu_book};
    case 2:
      return {'label': 'Đang ôn', 'color': colors.masteryReviewing, 'icon': Icons.refresh};
    case 3:
      return {'label': 'Đã thuộc', 'color': colors.masteryMastered, 'icon': Icons.star};
    default:
      return {'label': 'Không rõ', 'color': colors.masteryNew, 'icon': Icons.help};
  }
}
