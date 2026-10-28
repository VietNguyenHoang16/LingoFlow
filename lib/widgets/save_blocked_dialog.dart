import 'package:flutter/material.dart';

import '../services/network_error.dart';

/// Hộp thoại chặn khi không lưu được tiến độ (mất mạng / server lỗi).
///
/// Trả về `true` khi người dùng bấm "Thử lại" và lần lưu lại thành công,
/// `false` khi họ chọn thoát. Không thể đóng bằng cách chạm ra ngoài: mục đích
/// là để người dùng biết rõ lượt ôn hiện tại chưa được lưu.
Future<bool> showSaveBlockedDialog({
  required BuildContext context,
  required String message,
  required Future<void> Function() onRetry,
  VoidCallback? onExit,
  Object? error,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SaveBlockedDialog(
      message: message,
      onRetry: onRetry,
      offline: error == null || isNetworkError(error),
      onExit: onExit,
    ),
  );
  return saved ?? false;
}

class _SaveBlockedDialog extends StatefulWidget {
  final String message;
  final Future<void> Function() onRetry;
  final bool offline;
  final VoidCallback? onExit;

  const _SaveBlockedDialog({
    required this.message,
    required this.onRetry,
    required this.offline,
    this.onExit,
  });

  @override
  State<_SaveBlockedDialog> createState() => _SaveBlockedDialogState();
}

class _SaveBlockedDialogState extends State<_SaveBlockedDialog> {
  bool _retrying = false;
  String? _retryError;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _retryError = null;
    });
    try {
      await widget.onRetry();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _retrying = false;
        _retryError = isNetworkError(e)
            ? 'Vẫn chưa có kết nối. Kiểm tra WiFi / dữ liệu di động rồi thử lại.'
            : e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _exit() {
    Navigator.pop(context, false);
    widget.onExit?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Dialog(
      backgroundColor: colors.surfaceContainerLowest,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.errorContainer.withAlpha(150),
                ),
                child: Icon(
                  widget.offline
                      ? Icons.wifi_off_rounded
                      : Icons.cloud_off_rounded,
                  size: 30,
                  color: colors.error,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                widget.offline ? 'Mất kết nối mạng' : 'Chưa lưu được tiến độ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Be Vietnam Pro',
                fontSize: 13.5,
                height: 1.45,
                color: colors.onSurfaceVariant,
              ),
            ),
            if (_retryError != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.errorContainer.withAlpha(120),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _retryError!,
                  style: TextStyle(
                    fontFamily: 'Be Vietnam Pro',
                    fontSize: 12.5,
                    height: 1.4,
                    color: colors.onErrorContainer,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: _retrying ? null : _exit,
                  child: const Text('Thoát'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _retrying ? null : _retry,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: _retrying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Text('Thử lại'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
