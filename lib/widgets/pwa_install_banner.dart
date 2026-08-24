import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/pwa_install_service.dart';

class PwaInstallBanner extends StatefulWidget {
  const PwaInstallBanner({super.key, this.compact = false});

  /// compact=true -> small inline row (for profile), false -> large banner
  final bool compact;

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner> {
  final PwaInstallService _pwa = PwaInstallService();
  bool _visible = false;
  bool _checking = true;
  StreamSubscription? _subPrompt;
  StreamSubscription? _subInstalled;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    _check();
    _subPrompt = _pwa.onPromptReady.listen((_) => _check());
    _subInstalled = _pwa.onInstalled.listen((_) {
      if (mounted) setState(() => _visible = false);
    });
    // Poll for first 8s because beforeinstallprompt may fire late
    int ticks = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      ticks++;
      if (ticks > 8) {
        _pollTimer?.cancel();
        return;
      }
      final show = await _pwa.shouldShowPrompt();
      if (show && mounted && !_visible) setState(() => _visible = true);
      if (show) _pollTimer?.cancel();
    });
  }

  Future<void> _check() async {
    final show = await _pwa.shouldShowPrompt();
    if (!mounted) return;
    setState(() {
      _visible = show;
      _checking = false;
    });
  }

  Future<void> _onInstallTap() async {
    if (_pwa.isIOS) {
      if (!mounted) return;
      _showIOSSheet(context);
      return;
    }
    if (_pwa.canPrompt) {
      final outcome = await _pwa.promptInstall();
      if (!mounted) return;
      if (outcome == 'accepted') {
        await _pwa.dismiss(days: 365);
        if (!mounted) return;
        setState(() => _visible = false);
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang cài đặt ứng dụng...')),
        );
      } else if (outcome == 'dismissed') {
        // keep banner, optional brief dismiss
      }
    } else {
      // Fallback: if no prompt but not iOS (e.g., desktop), show generic sheet
      if (!mounted) return;
      _showGenericSheet(context);
    }
  }

  Future<void> _onDismiss() async {
    await _pwa.dismiss(days: 7);
    if (mounted) setState(() => _visible = false);
  }

  @override
  void dispose() {
    _subPrompt?.cancel();
    _subInstalled?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    if (_checking) return const SizedBox.shrink();
    if (!_visible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.compact) {
      return _buildCompact(theme, isDark);
    }
    return _buildBanner(theme, isDark);
  }

  Widget _buildBanner(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.primary.withAlpha(isDark ? 40 : 30),
          width: 1.2,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: theme.colorScheme.primary.withAlpha(18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.primary.withAlpha(190)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.install_mobile_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pwa.isIOS ? 'Cài LingoFlow lên iPhone' : 'Cài LingoFlow',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _pwa.isIOS ? 'Thêm vào MH chính để mở như app' : 'Mở nhanh, dùng offline, toàn màn hình',
                  style: TextStyle(
                    fontFamily: 'Be Vietnam Pro',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _onDismiss,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh.withAlpha(isDark ? 80 : 100),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: _onInstallTap,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                _pwa.isIOS ? 'Hướng dẫn' : 'Cài đặt',
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(isDark ? 30 : 18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.primary.withAlpha(40)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.install_mobile_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cài ứng dụng',
                    style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: theme.colorScheme.onSurface)),
                Text(_pwa.isIOS ? 'Thêm vào MH chính (iOS)' : 'Cài như app native',
                    style: TextStyle(
                        fontFamily: 'Be Vietnam Pro',
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          FilledButton(
            onPressed: _onInstallTap,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(_pwa.isIOS ? 'Xem' : 'Cài',
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showIOSSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const IOSInstallSheet(),
    );
  }

  void _showGenericSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const GenericInstallSheet(),
    );
  }
}

class PwaInstallIconButton extends StatefulWidget {
  const PwaInstallIconButton({super.key});

  @override
  State<PwaInstallIconButton> createState() => _PwaInstallIconButtonState();
}

class _PwaInstallIconButtonState extends State<PwaInstallIconButton> {
  final PwaInstallService _pwa = PwaInstallService();
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    _check();
    // re-check when prompt ready
    _pwa.onPromptReady.listen((_) => _check());
    _pwa.onInstalled.listen((_) {
      if (mounted) setState(() => _visible = false);
    });
  }

  Future<void> _check() async {
    final v = await _pwa.shouldShowPrompt();
    if (mounted) setState(() => _visible = v);
  }

  Future<void> _onTap() async {
    if (_pwa.isIOS) {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const IOSInstallSheet(),
      );
      return;
    }
    if (_pwa.canPrompt) {
      final o = await _pwa.promptInstall();
      if (o == 'accepted' && mounted) {
        await _pwa.dismiss(days: 365);
        setState(() => _visible = false);
      }
    } else {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => const GenericInstallSheet(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !_visible) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: _onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withAlpha(18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.primary.withAlpha(60), width: 1.2),
        ),
        child: Icon(Icons.install_mobile_rounded, color: theme.colorScheme.primary, size: 20),
      ),
    );
  }
}

class IOSInstallSheet extends StatelessWidget {
  const IOSInstallSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 18),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.primaryContainer]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.install_mobile_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 14),
            Text('Cài LingoFlow lên iPhone',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w800, fontSize: 18, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 6),
            Text('Mở như app thật, toàn màn hình, không cần gõ lại địa chỉ',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 13, color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
            const SizedBox(height: 20),
            _step(
              theme: theme,
              isDark: isDark,
              number: '1',
              icon: Icons.ios_share_rounded,
              title: 'Nhấn nút Chia sẻ',
              subtitle: 'Biểu tượng ô vuông có mũi tên lên ở thanh dưới Safari',
            ),
            const SizedBox(height: 12),
            _step(
              theme: theme,
              isDark: isDark,
              number: '2',
              icon: Icons.add_box_outlined,
              title: 'Chọn “Thêm vào MH chính”',
              subtitle: 'Kéo menu lên, tìm “Add to Home Screen”',
            ),
            const SizedBox(height: 12),
            _step(
              theme: theme,
              isDark: isDark,
              number: '3',
              icon: Icons.check_circle_outline_rounded,
              title: 'Nhấn “Thêm”',
              subtitle: 'Góc trên bên phải, sau đó mở app từ màn hình chính',
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Mẹo: Sau khi thêm, nhấn giữ icon để di chuyển như app thường.',
                        style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 12, color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Đã hiểu', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await PwaInstallService().dismiss(days: 7);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text('Ẩn trong 7 ngày', style: TextStyle(fontFamily: 'Be Vietnam Pro', color: theme.colorScheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step({required ThemeData theme, required bool isDark, required String number, required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerLow : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontFamily: 'Plus Jakarta Sans')),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withAlpha(isDark ? 60 : 80),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700, fontSize: 13, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 11, color: theme.colorScheme.onSurfaceVariant, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GenericInstallSheet extends StatelessWidget {
  const GenericInstallSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 18),
            Icon(Icons.install_mobile_rounded, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Cài đặt LingoFlow',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w800, fontSize: 18, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text('Trình duyệt của bạn hỗ trợ cài PWA.\nNhấn menu trình duyệt → “Cài đặt ứng dụng” hoặc “Add to Home Screen”.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 13, color: theme.colorScheme.onSurfaceVariant, height: 1.5)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đã hiểu', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
