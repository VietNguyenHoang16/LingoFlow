import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Huy giua chung mot lan luu (vd AI khong tra ve nghia): lop phu phai tan
/// ngay va khong duoc hien "Da luu" vi that ra chua ghi gi.
class SaveAborted implements Exception {
  final String message;

  const SaveAborted(this.message);
}

/// Chạy [action] trong lúc phủ một lớp khoá thao tác "Đang lưu…".
///
/// - Thành công: lớp phủ đổi sang dấu tick "Đã lưu" + tên từ rồi tan dần.
/// - Lỗi: lớp phủ được gỡ ngay và lỗi được ném lại cho nơi gọi rollback.
///
/// Mục đích: người dùng biết dữ liệu đang được ghi, không chạm nhầm trong lúc
/// chờ, và thấy rõ "đã lưu xong" thay vì màn hình tự nhảy một cái.
Future<T> runWithSaveFeedback<T>({
  required BuildContext context,
  required String word,
  required Future<T> Function() action,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final controller = _SaveFeedbackController();
  late final OverlayEntry entry;
  var finished = false;

  // `OverlayEntry.mounted` chi true sau frame dau tien, trong khi action co the
  // loi truoc do -> phai go bang co cua overlay, neu khong spinner se quay mai.
  void removeEntry() {
    if (finished) return;
    finished = true;
    if (overlay.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => _SaveFeedbackLayer(
      controller: controller,
      word: word,
      onFinished: removeEntry,
    ),
  );
  overlay.insert(entry);

  try {
    final result = await action();
    controller.markSaved();
    unawaited(HapticFeedback.mediumImpact());
    return result;
  } catch (_) {
    removeEntry();
    rethrow;
  }
}

class _SaveFeedbackController extends ChangeNotifier {
  bool _saved = false;

  bool get saved => _saved;

  void markSaved() {
    if (_saved) return;
    _saved = true;
    notifyListeners();
  }
}

class _SaveFeedbackLayer extends StatefulWidget {
  final _SaveFeedbackController controller;
  final String word;
  final VoidCallback onFinished;

  const _SaveFeedbackLayer({
    required this.controller,
    required this.word,
    required this.onFinished,
  });

  @override
  State<_SaveFeedbackLayer> createState() => _SaveFeedbackLayerState();
}

class _SaveFeedbackLayerState extends State<_SaveFeedbackLayer>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _success;
  late final AnimationController _exit;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..forward();
    _success = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    widget.controller.addListener(_handleSaved);
    _success.addStatusListener((status) {
      if (status == AnimationStatus.completed) _close();
    });
    // Action co the xong truoc frame dau tien (vd test / cache) -> ap dung
    // trang thai da luu ngay de khong quay spinner mai mai.
    if (widget.controller.saved) {
      _saved = true;
      _success.forward();
    }
  }

  void _handleSaved() {
    if (!widget.controller.saved || _saved) return;
    setState(() => _saved = true);
    _success.forward();
  }

  Future<void> _close() async {
    await _exit.forward();
    if (!mounted) return;
    widget.onFinished();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleSaved);
    widget.controller.dispose();
    _entrance.dispose();
    _success.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: Listenable.merge([_entrance, _exit, _success]),
        builder: (context, _) {
          final appear = Curves.easeOutCubic.transform(_entrance.value);
          final fade = appear * (1 - Curves.easeInCubic.transform(_exit.value));
          final tick = const Interval(
            0,
            0.5,
            curve: Curves.easeOutCubic,
          ).transform(_success.value);
          final pop = const Interval(
            0,
            0.4,
            curve: Curves.easeOutBack,
          ).transform(_success.value);

          return Stack(
            children: [
              // Chan moi cu cham xuong man hinh ben duoi trong luc luu.
              ModalBarrier(dismissible: false, color: Colors.transparent),
              Positioned.fill(
                child: Opacity(
                  opacity: fade.clamp(0.0, 1.0),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: 7 * appear,
                      sigmaY: 7 * appear,
                    ),
                    child: ColoredBox(color: colors.scrim.withAlpha(36)),
                  ),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: fade.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.94 + 0.06 * appear,
                    child: Container(
                      width: 244,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: colors.outlineVariant.withAlpha(150),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow.withAlpha(30),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: _saved
                                  ? Transform.scale(
                                      scale: pop.clamp(0.6, 1.06),
                                      child: CustomPaint(
                                        key: const ValueKey('saved'),
                                        size: const Size.square(64),
                                        painter: _CheckPainter(
                                          progress: tick,
                                          color: colors.primary,
                                        ),
                                      ),
                                    )
                                  : Center(
                                      key: const ValueKey('saving'),
                                      child: SizedBox(
                                        width: 42,
                                        height: 42,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.6,
                                          color: colors.primary,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            child: Text(
                              _saved ? 'Đã lưu' : 'Đang lưu…',
                              key: ValueKey(_saved),
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.word,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Be Vietnam Pro',
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Vòng tròn nền + dấu tick vẽ dần theo [progress] (0..1).
class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = color.withAlpha(24),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = color.withAlpha(60),
    );

    final check = Path()
      ..moveTo(size.width * 0.30, size.height * 0.53)
      ..lineTo(size.width * 0.45, size.height * 0.68)
      ..lineTo(size.width * 0.72, size.height * 0.36);
    if (progress <= 0) return;
    final metric = check.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
