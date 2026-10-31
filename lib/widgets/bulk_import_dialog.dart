import 'package:flutter/material.dart';
import '../services/bulk_word_importer.dart';
import '../services/database_service.dart';
import '../widgets/word_type_badge.dart';

/// Modal paste text + preview + import. Trả về số từ đã insert thành công
/// (0 nếu user đóng trước khi import).
class BulkImportDialog extends StatefulWidget {
  final int userId;
  final String? defaultWordType;

  /// Text điền sẵn vào ô dán từ (dùng khi bấm "Thêm từ" từ ô tìm kiếm).
  final String initialText;

  /// Tự chạy bước "Phân tích bằng AI" ngay khi mở dialog.
  final bool autoAnalyze;

  /// Import xong (không lỗi, không huỷ) thì tự đóng dialog — dùng cho luồng
  /// "Thêm từ" nhanh từ ô tìm kiếm.
  final bool closeOnSuccess;

  const BulkImportDialog({
    super.key,
    required this.userId,
    this.defaultWordType,
    this.initialText = '',
    this.autoAnalyze = false,
    this.closeOnSuccess = false,
  });

  static Future<int> show(
    BuildContext context, {
    required int userId,
    String? defaultWordType,
    String initialText = '',
    bool autoAnalyze = false,
    bool closeOnSuccess = false,
  }) async {
    final n = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BulkImportDialog(
        userId: userId,
        defaultWordType: defaultWordType,
        initialText: initialText,
        autoAnalyze: autoAnalyze,
        closeOnSuccess: closeOnSuccess,
      ),
    );
    return n ?? 0;
  }

  @override
  State<BulkImportDialog> createState() => _BulkImportDialogState();
}

class _BulkImportDialogState extends State<BulkImportDialog> {
  static const _example = 'serendipity, resilient, break the ice, commute';

  // Bước AI lấy nghĩa + loại từ (stage 4) - hiện trước preview.
  static const int _stageAnalyzing = 4;

  final _controller = TextEditingController();
  final _importer = BulkWordImporter();

  // 0: paste, 1: preview, 2: importing, 3: result
  int _stage = 0;
  bool _cancelled = false;
  bool _isProcessing = false;

  List<ImportLine> _lines = const [];
  int _validCount = 0;
  int _activeCount = 0;
  int _passiveCount = 0;
  int _skipCount = 0;
  int _errorCount = 0;
  int _duplicateCount = 0;

  int _analyzeTotal = 0;
  int _done = 0;
  int _total = 0;
  int _fetched = 0;
  int _fetchTotal = 0;
  // 0: đang lấy phát âm, 1: đang lưu
  int _phase = 0;
  int _inserted = 0;
  bool _wasCancelled = false;
  List<BulkAddFailure> _failedWords = const [];
  String? _retryLabel;
  String? _fatalError;
  DateTime _lastProgressTick = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialText.trim();
    if (initial.isNotEmpty) {
      _controller.text = initial;
    }
    // Mo tu o tim kiem: phan tich AI ngay de thay nghia/loai tu truoc khi them.
    if (widget.autoAnalyze && initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goPreview();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _goPreview() async {
    setState(() {
      _isProcessing = true;
      _fatalError = null;
      _stage = _stageAnalyzing;
      _analyzeTotal = 0;
    });
    try {
      // 1. Tach danh sach tu + bo tu da co (nhanh, 1 request DB).
      final parsed = _importer.parseWords(_controller.text);
      final checked = await _importer.checkDuplicates(widget.userId, parsed);
      if (!mounted) return;
      setState(() {
        _lines = checked;
        _analyzeTotal =
            checked.where((l) => l.error == null).length;
        _applyCounts(checked);
      });
      // 2. AI lay nghia tieng Viet + loai tu cho tung tu con lai.
      final enriched = await _importer.enrichMeanings(widget.userId, checked);
      if (!mounted) return;
      setState(() {
        _lines = enriched;
        _applyCounts(enriched);
        _stage = 1;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fatalError = e.toString().replaceFirst('Exception: ', '');
        _stage = 0;
        _isProcessing = false;
      });
    }
  }

  void _applyCounts(List<ImportLine> lines) {
    int active = 0, passive = 0, skipped = 0, dup = 0;
    for (final l in lines) {
      if (l.isValid) {
        if (l.learningMode == ImportLine.modePassive) {
          passive++;
        } else {
          active++;
        }
      } else if (l.isSkip) {
        skipped++;
      } else if (l.isDuplicate) {
        dup++;
      }
    }
    _activeCount = active;
    _passiveCount = passive;
    _skipCount = skipped;
    _validCount = active + passive;
    _duplicateCount = dup;
    _errorCount = lines.length - active - passive - skipped - dup;
  }

  /// Đổi loại từ: Học ngay → Nên biết → Bỏ qua → Học ngay.
  /// "Bỏ qua" thay cho thao tác loại trừ trước đây: không tick, không gửi lên.
  void _cycleMode(ImportLine line, String next) {
    setState(() {
      line.learningMode = next;
      _applyCounts(_lines);
    });
  }

  Future<void> _goImport() async {
    setState(() {
      _stage = 2;
      _cancelled = false;
      _done = 0;
      _total = _validCount;
      _fetched = 0;
      _fetchTotal = _validCount;
      _phase = 0;
      _inserted = 0;
      _wasCancelled = false;
      _failedWords = const [];
      _retryLabel = null;
      _fatalError = null;
      _isProcessing = true;
    });

    bool shouldTick(int done, int total) {
      if (done >= total) return true;
      final now = DateTime.now();
      if (now.difference(_lastProgressTick).inMilliseconds < 80) return false;
      _lastProgressTick = now;
      return true;
    }

    final result = await _importer.importBatch(
      widget.userId,
      _lines.where((l) => l.isValid).toList(growable: false),
      onFetchProgress: (fetched, total) {
        if (!mounted) return;
        if (!shouldTick(fetched, total)) return;
        setState(() {
          _fetched = fetched;
          _fetchTotal = total;
          _phase = 0;
        });
      },
      onProgress: (done, total) {
        if (!mounted) return;
        if (!shouldTick(done, total)) return;
        setState(() {
          _done = done;
          _total = total;
          _phase = 1;
        });
      },
      onRetry: (round, remaining) {
        if (!mounted) return;
        setState(() {
          _retryLabel = 'Đang thử lại $remaining từ (lượt $round)…';
          _phase = 1;
        });
      },
      isCancelled: () => _cancelled,
    );

    if (!mounted) return;
    setState(() {
      _inserted = result.insertedCount;
      _wasCancelled = result.cancelled;
      _failedWords = result.failedWords;
      _stage = 3;
      _isProcessing = false;
    });
    // Luong them nhanh tu o tim kiem: them xong thi dong luon, khong bat
    // nguoi dung bam them "Dong".
    if (widget.closeOnSuccess &&
        !result.cancelled &&
        result.failedWords.isEmpty &&
        result.insertedCount > 0) {
      Navigator.of(context).pop(result.insertedCount);
    }
  }

  void _cancel() {
    if (_stage == 2) {
      setState(() => _cancelled = true);
    } else {
      Navigator.of(context).pop(_inserted);
    }
  }

  void _back() {
    setState(() {
      _stage = 0;
      _lines = const [];
      _activeCount = 0;
      _passiveCount = 0;
      _skipCount = 0;
    });
  }

  void _close() {
    Navigator.of(context).pop(_inserted);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.playlist_add_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Import từ hàng loạt',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: 'Be Vietnam Pro',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _isProcessing ? null : _cancel,
                    icon: const Icon(Icons.close),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildStage(theme)),
              const SizedBox(height: 12),
              _buildActions(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStage(ThemeData theme) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _buildStageChild(theme, _stage),
    );
  }

  Widget _buildStageChild(ThemeData theme, int stage) {
    switch (stage) {
      case 0:
        return _buildPaste(theme, key: const ValueKey(0));
      case 1:
        return _buildPreview(theme, key: const ValueKey(1));
      case 2:
        return _buildImporting(theme, key: const ValueKey(2));
      case 3:
        return _buildResult(theme, key: const ValueKey(3));
      case _stageAnalyzing:
        return _buildAnalyzing(theme, key: const ValueKey(_stageAnalyzing));
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPaste(ThemeData theme, {Key? key}) {
    return ListView(
      key: key,
      children: [
        Text(
          'Dán danh sách từ, ngăn cách bằng dấu phẩy. AI tự lấy nghĩa tiếng Việt, phân loại từ và tạo ví dụ cho từng từ. Dòng bắt đầu # là comment, dòng trống bị bỏ qua.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(150),
            fontFamily: 'Be Vietnam Pro',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          maxLines: 10,
          minLines: 8,
          autofocus: true,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
          ),
          decoration: InputDecoration(
            hintText: _example,
            hintStyle: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        if (_fatalError != null) ...[
          const SizedBox(height: 12),
          Text(
            'Lỗi: $_fatalError',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildAnalyzing(ThemeData theme, {Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 44,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            _analyzeTotal == 0
                ? 'Đang đọc danh sách từ…'
                : 'AI đang lấy nghĩa và phân loại $_analyzeTotal từ…',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'Be Vietnam Pro',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Thường mất 10–30 giây tùy số lượng từ.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(140),
              fontFamily: 'Be Vietnam Pro',
            ),
          ),
          const SizedBox(height: 18),
          const SizedBox(
            width: 180,
            child: LinearProgressIndicator(minHeight: 6),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(ThemeData theme, {Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _stat('Học ngay', _activeCount, theme.colorScheme.primary),
            _stat('Nên biết', _passiveCount, theme.colorScheme.tertiary),
            if (_skipCount > 0)
              _stat('Bỏ qua', _skipCount, theme.colorScheme.outline),
            _stat('Không dùng được', _errorCount, theme.colorScheme.error),
            _stat('Trùng từ', _duplicateCount, theme.colorScheme.onSurfaceVariant),
            _stat('Tổng dòng', _lines.length, theme.colorScheme.onSurface),
          ],
        ),
        if (_errorCount > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 16, color: theme.colorScheme.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$_errorCount từ không dùng được sẽ bị bỏ qua (xem lỗi bên dưới).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'Be Vietnam Pro',
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _lines.isEmpty
                ? const Center(child: Text('Không có dòng nào hợp lệ'))
                : ListView.separated(
                    cacheExtent: 300,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    itemCount: _lines.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: theme.dividerColor),
                    itemBuilder: (ctx, i) {
                      final l = _lines[i];
                      return _PreviewRow(
                        line: l,
                        onCycleMode: l.error == null
                            ? (next) => _cycleMode(l, next)
                            : null,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildImporting(ThemeData theme, {Key? key}) {
    final total = _total == 0 ? 1 : _total;
    // Fetch chiếm 70%, lưu chiếm 30% để bar chạy đơn điệu, không giật lùi.
    final fetchPct = (_fetchTotal == 0 ? 0.0 : _fetched / _fetchTotal).clamp(0.0, 1.0);
    final savePct = (_done / total).clamp(0.0, 1.0);
    final pct = (_phase == 0 ? fetchPct * 0.7 : 0.7 + savePct * 0.3).clamp(0.0, 1.0);
    final phaseLabel = _phase == 0
        ? 'Đang lấy phát âm $_fetched/$_fetchTotal…'
        : _retryLabel ?? 'Đang lưu $_done/$_total…';

    // Chi hien thi nhung tu THUC SU duoc import; tu "Bo qua" khong duoc tick.
    final validWords = _lines
        .where((l) => l.isValid)
        .take(20)
        .toList();
    // Số từ đã xong ở phase hiện tại để tick list.
    final tickDone = _phase == 0 ? _fetched : _done;

    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ImportSteps(active: _phase, theme: theme),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: pct),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  height: 8,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: value.clamp(0.02, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              phaseLabel,
              key: ValueKey(phaseLabel),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'Be Vietnam Pro',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(pct * 100).round()}% • ${(_phase == 0 ? 'phát âm' : 'lưu trữ')}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(140),
              fontFamily: 'Be Vietnam Pro',
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                cacheExtent: 200,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                itemCount: validWords.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: theme.dividerColor),
                itemBuilder: (ctx, i) {
                  final w = validWords[i];
                  final isDone = i < tickDone;
                  final isDoing = i == tickDone && tickDone < validWords.length;
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: isDone ? 1.0 : 0.75,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDone
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceContainerHighest,
                            ),
                            child: isDone
                                ? const Icon(Icons.check_rounded,
                                    size: 14, color: Colors.white)
                                : isDoing
                                    ? Padding(
                                        padding: const EdgeInsets.all(5),
                                        child: SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              w.word,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Be Vietnam Pro',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(ThemeData theme, {Key? key}) {
    return Center(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.6, end: 1.0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.elasticOut,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Icon(
              _inserted > 0 ? Icons.check_circle_rounded : Icons.info_rounded,
              size: 56,
              color: _inserted > 0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withAlpha(150),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _wasCancelled
                ? 'Đã dừng. Đã thêm $_inserted / $_total từ.'
                : 'Đã thêm $_inserted từ.',
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'Be Vietnam Pro',
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_errorCount + _duplicateCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Đã bỏ qua ${_errorCount + _duplicateCount} từ '
              '($_duplicateCount đã có, $_errorCount không dùng được).',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(150),
                fontFamily: 'Be Vietnam Pro',
              ),
            ),
          ],
          if (_skipCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Đã bỏ qua $_skipCount từ mà AI xếp "không ưu tiên".',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(150),
                fontFamily: 'Be Vietnam Pro',
              ),
            ),
          ],
          if (_failedWords.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${_failedWords.length} từ chưa lưu được:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontFamily: 'Be Vietnam Pro',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final failure in _failedWords)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${failure.word}: ${failure.message}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'Be Vietnam Pro',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(ThemeData theme) {
    switch (_stage) {
      case 0:
        return Row(
          children: [
            const Spacer(),
            TextButton(onPressed: _cancel, child: const Text('Hủy')),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _isProcessing ? null : _goPreview,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Phân tích bằng AI'),
            ),
          ],
        );
      case 1:
        return Row(
          children: [
            const Spacer(),
            TextButton(onPressed: _back, child: const Text('Quay lại sửa')),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: (_isProcessing || _validCount == 0)
                  ? null
                  : _goImport,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text('Import $_validCount từ'),
            ),
          ],
        );
      case 2:
        return Row(
          children: [
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => _cancelled = true),
              child: const Text('Hủy import'),
            ),
          ],
        );
      case _stageAnalyzing:
        return Row(
          children: [
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(0),
              child: const Text('Hủy'),
            ),
          ],
        );
      case 3:
        return Row(
          children: [
            if (_errorCount + _duplicateCount > 0)
              TextButton(
                onPressed: _back,
                child: const Text('Xem lại lỗi'),
              ),
            const Spacer(),
            FilledButton(onPressed: _close, child: const Text('Đóng')),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _stat(String label, int n, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $n',
          style: const TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 13),
        ),
      ],
    );
  }
}

class _ImportSteps extends StatelessWidget {
  final int active;
  final ThemeData theme;
  const _ImportSteps({required this.active, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _dot(0, Icons.record_voice_over_rounded, 'Phát âm'),
        _line(0),
        _dot(1, Icons.save_rounded, 'Lưu'),
      ],
    );
  }

  Widget _dot(int index, IconData icon, String label) {
    final isDone = index < active;
    final isActive = index == active;
    final color = (isDone || isActive)
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withAlpha(90);
    final bg = (isDone || isActive)
        ? theme.colorScheme.primary.withAlpha(25)
        : theme.colorScheme.surfaceContainerHighest;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 30,
          height: 30,
          decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
          child: Icon(
            isDone ? Icons.check_rounded : icon,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Be Vietnam Pro',
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _line(int leftIndex) {
    final filled = leftIndex < active;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 2,
          decoration: BoxDecoration(
            color: filled
                ? theme.colorScheme.primary
                : theme.dividerColor,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final ImportLine line;

  /// null = không cho đổi (dòng lỗi). Giá trị truyền vào là loại kế tiếp.
  final void Function(String next)? onCycleMode;

  const _PreviewRow({required this.line, this.onCycleMode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSkip = line.isSkip;
    final isDuplicate = line.isDuplicate;
    final isError = !line.isValid && !isSkip && !isDuplicate;
    final modeColor = line.learningMode == ImportLine.modePassive
        ? theme.colorScheme.tertiary
        : isSkip
            ? theme.colorScheme.outline
            : theme.colorScheme.primary;
    final bgColor = isSkip
        ? theme.colorScheme.surfaceContainerHigh.withAlpha(130)
        : isDuplicate
            ? theme.colorScheme.tertiary.withAlpha(14)
            : isError
                ? theme.colorScheme.error.withAlpha(15)
                : Colors.transparent;

    return ColoredBox(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '#${line.lineNumber}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        line.word,
                        style: TextStyle(
                          fontFamily: 'Be Vietnam Pro',
                          fontWeight: isError ? FontWeight.w500 : FontWeight.w600,
                        ),
                      ),
                      if ((line.wordType ?? '').isNotEmpty)
                        WordTypeBadge(typeKey: line.wordType!, compact: true),
                      if (line.error != null)
                        Text(
                          line.error!,
                          style: TextStyle(
                            fontFamily: 'Be Vietnam Pro',
                            fontSize: 11,
                            color: isDuplicate
                                ? theme.colorScheme.tertiary
                                : theme.colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                  if (line.meaning.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        line.meaning,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Be Vietnam Pro',
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withAlpha(180),
                        ),
                      ),
                    ),
                  if (line.collocations.isNotEmpty && !isSkip)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Cụm: ${line.collocations}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Be Vietnam Pro',
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: modeColor.withAlpha(200),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (onCycleMode != null) _modeChip(theme, modeColor),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(ThemeData theme, Color color) {
    final isPassive = line.learningMode == ImportLine.modePassive;
    final isSkip = line.learningMode == ImportLine.modeSkip;
    final label = isPassive ? 'Nên biết' : (isSkip ? 'Bỏ qua' : 'Học ngay');
    final icon = isPassive
        ? Icons.visibility_outlined
        : (isSkip ? Icons.block_rounded : Icons.bolt_rounded);
    final next = line.learningMode == ImportLine.modeActive
        ? ImportLine.modePassive
        : (isPassive ? ImportLine.modeSkip : ImportLine.modeActive);
    final nextLabel = next == ImportLine.modeActive
        ? 'Học ngay'
        : (next == ImportLine.modePassive ? 'Nên biết' : 'Bỏ qua');
    return Tooltip(
      message: 'Đổi sang $nextLabel',
      child: InkWell(
        key: ValueKey('import-mode-${line.lineNumber}'),
        onTap: () => onCycleMode!(next),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withAlpha(90)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Be Vietnam Pro',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
