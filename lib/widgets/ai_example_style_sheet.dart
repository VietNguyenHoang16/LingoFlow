import 'package:flutter/material.dart';

import '../services/ai_settings_service.dart';
import '../services/database_service.dart';
import '../services/network_error.dart';
import 'save_feedback.dart';

/// Khung chỉnh cách AI chọn nghĩa và viết câu ví dụ.
///
/// Cài đặt lưu theo tài khoản (server) nên mở máy khác vẫn giữ nguyên; mọi lần
/// tạo nghĩa/ví dụ sau đó đều dùng ngay cấu hình này.
typedef AiExampleStyleLoader = Future<AiExampleStyle> Function();
typedef AiExampleStyleSaver = Future<AiExampleStyle> Function(
  AiExampleStyle style,
);

class AiExampleStyleSheet extends StatefulWidget {
  final AiExampleStyleLoader? loader;
  final AiExampleStyleSaver? saver;

  const AiExampleStyleSheet({super.key, this.loader, this.saver});

  static Future<AiExampleStyle?> show(
    BuildContext context, {
    AiExampleStyleLoader? loader,
    AiExampleStyleSaver? saver,
  }) {
    return showModalBottomSheet<AiExampleStyle>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => AiExampleStyleSheet(loader: loader, saver: saver),
    );
  }

  @override
  State<AiExampleStyleSheet> createState() => _AiExampleStyleSheetState();
}

class _AiExampleStyleSheetState extends State<AiExampleStyleSheet> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _custom = TextEditingController();

  AiExampleStyle _style = AiExampleStyle.defaults;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  AiExampleStyle get _currentStyle =>
      _style.copyWith(custom: AiExampleStyle.normalizeCustom(_custom.text));

  Future<AiExampleStyle> _loadStyle() =>
      widget.loader?.call() ?? _db.getAiExampleStyle();

  Future<AiExampleStyle> _saveStyle(AiExampleStyle style) =>
      widget.saver?.call(style) ?? _db.saveAiExampleStyle(style);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final style = await _loadStyle();
      if (!mounted) return;
      setState(() {
        _style = style;
        _custom.text = style.custom;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = isNetworkError(error)
            ? 'Không có mạng nên chưa tải được cài đặt.'
            : error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _toggleContext(String id) {
    final contexts = [..._style.contexts];
    if (contexts.contains(id)) {
      contexts.remove(id);
    } else {
      contexts.add(id);
    }
    setState(() => _style = _style.copyWith(contexts: contexts));
  }

  void _reset() {
    _custom.text = '';
    setState(() {
      _style = AiExampleStyle.defaults;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving || _loading || _loadError != null) return;
    final style = _currentStyle;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await runWithSaveFeedback<AiExampleStyle>(
        context: context,
        word: 'Cách AI sinh ví dụ',
        action: () => _saveStyle(style),
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = isNetworkError(error)
            ? 'Không có mạng. Kết nối lại rồi lưu nhé.'
            : 'Không lưu được: ${error.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final height = (media.size.height * 0.92 - bottomInset).clamp(
      320.0,
      media.size.height,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cách AI sinh ví dụ',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Áp cho lần tạo nghĩa và câu ví dụ tiếp theo. Lưu theo tài khoản của bạn.',
                  style: TextStyle(
                    fontFamily: 'Be Vietnam Pro',
                    fontSize: 12,
                    height: 1.4,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _loadError != null
                    ? _buildLoadError(theme)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                        children: [
                          _buildSenseCard(theme),
                          const SizedBox(height: 14),
                          _buildContextCard(theme),
                          const SizedBox(height: 14),
                          _buildCustomCard(theme),
                          const SizedBox(height: 14),
                          _buildPreviewCard(theme),
                        ],
                      ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      fontFamily: 'Be Vietnam Pro',
                      fontSize: 12,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: _loading || _saving ? null : _reset,
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: const Text(
                        'Mặc định',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _saving || _loading || _loadError != null
                          ? null
                          : _save,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                      ),
                      child: Text(
                        _saving ? 'Đang lưu…' : 'Lưu',
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNetworkError(_loadError!) || _loadError!.contains('mạng')
                  ? Icons.wifi_off_rounded
                  : Icons.cloud_off_rounded,
              size: 34,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Be Vietnam Pro',
                fontSize: 13,
                height: 1.45,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSenseCard(ThemeData theme) {
    final colors = theme.colorScheme;
    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Chọn nghĩa để dạy',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                  ),
                ),
              ),
              Switch.adaptive(
                value: _style.skipRareSenses,
                onChanged: (value) => setState(
                  () => _style = _style.copyWith(skipRareSenses: value),
                ),
              ),
            ],
          ),
          Text(
            _style.skipRareSenses
                ? 'Bỏ qua nghĩa hiếm / nghĩa đen ít dùng. concrete → “cụ thể, rõ ràng” (không phải “bê tông”); harness → “tận dụng, khai thác” (không phải “yên cương”).'
                : 'AI có thể lấy nghĩa đen hoặc nghĩa ít gặp nếu nó thấy phù hợp.',
            style: TextStyle(
              fontFamily: 'Be Vietnam Pro',
              fontSize: 12.5,
              height: 1.45,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextCard(ThemeData theme) {
    final colors = theme.colorScheme;
    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bối cảnh câu ví dụ',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'AI đặt câu trong những tình huống này khi phù hợp. Bỏ chọn hết = AI tự chọn.',
            style: TextStyle(
              fontFamily: 'Be Vietnam Pro',
              fontSize: 12.5,
              height: 1.45,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final context in kAiExampleContexts)
                _contextChip(theme, context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contextChip(ThemeData theme, AiExampleContext context) {
    final colors = theme.colorScheme;
    final selected = _style.contexts.contains(context.id);
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => _toggleContext(context.id),
      label: Text(
        context.label,
        style: TextStyle(
          fontFamily: 'Be Vietnam Pro',
          fontSize: 12.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? colors.primary : colors.onSurfaceVariant,
        ),
      ),
      backgroundColor: colors.surfaceContainerHighest.withAlpha(90),
      selectedColor: colors.primary.withAlpha(28),
      side: BorderSide(
        color: selected
            ? colors.primary.withAlpha(150)
            : colors.outlineVariant.withAlpha(140),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildCustomCard(ThemeData theme) {
    final colors = theme.colorScheme;
    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yêu cầu riêng',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ghép thẳng vào prompt. Ví dụ: câu ngắn dưới 12 từ, dùng thì hiện tại đơn, tránh tên riêng.',
            style: TextStyle(
              fontFamily: 'Be Vietnam Pro',
              fontSize: 12.5,
              height: 1.45,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _custom,
            minLines: 2,
            maxLines: 4,
            maxLength: AiExampleStyle.maxCustomLength,
            onChanged: (_) => setState(() => _error = null),
            style: const TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'VD: ưu tiên ví dụ ở công ty, câu ngắn, không dùng tên riêng',
              hintStyle: TextStyle(
                fontFamily: 'Be Vietnam Pro',
                fontSize: 12.5,
                color: colors.onSurfaceVariant.withAlpha(160),
              ),
              isDense: true,
              filled: true,
              fillColor: colors.surfaceContainerHighest.withAlpha(70),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.outlineVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(ThemeData theme) {
    final colors = theme.colorScheme;
    final style = _currentStyle;
    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 16, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                'Chỉ dẫn gửi AI',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withAlpha(70),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outlineVariant.withAlpha(120)),
            ),
            child: Text(
              buildAiExampleStylePreview(style),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.55,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(ThemeData theme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}
