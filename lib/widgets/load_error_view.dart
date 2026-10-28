import 'package:flutter/material.dart';

import '../services/network_error.dart';

/// Trạng thái lỗi khi tải dữ liệu (mất mạng / server lỗi).
///
/// Dùng thay cho danh sách rỗng để người dùng không bị hiểu nhầm là "đã hết
/// việc" trong khi thực ra chưa tải được gì.
class LoadErrorView extends StatelessWidget {
  final Object? error;
  final String fallbackTitle;
  final String fallbackMessage;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const LoadErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onBack,
    this.fallbackTitle = 'Không tải được dữ liệu',
    this.fallbackMessage = 'Đã có lỗi khi tải dữ liệu. Vui lòng thử lại.',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final offline = error != null && isNetworkError(error!);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primaryContainer.withAlpha(190),
                    colors.surfaceContainerLow,
                  ],
                ),
                border: Border.all(color: colors.outlineVariant.withAlpha(120)),
              ),
              child: Icon(
                offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
                size: 40,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              offline ? 'Cần kết nối mạng' : fallbackTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              offline
                  ? 'Không tải được danh sách từ. Bật WiFi / dữ liệu di động rồi thử lại để không mất tiến độ ôn tập.'
                  : fallbackMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Be Vietnam Pro',
                fontSize: 13.5,
                height: 1.5,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(170, 46),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(onPressed: onBack, child: const Text('Quay lại')),
          ],
        ),
      ),
    );
  }
}
