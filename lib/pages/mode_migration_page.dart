import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/database_service.dart';
import '../services/word_change_bus.dart';

/// Phân loại từ vựng theo lô 20 từ.
///
/// Mỗi từ có một nút lớn 2 bên **Học ngay / Nên biết** (bấm bên nào sáng bên
/// đó). Có nút copy nhanh 20 từ (chỉ từ tiếng Anh, cách nhau dấu phẩy) để dán
/// sang chỗ khác, và nút Nộp: từ đã nộp có trạng thái nên lần sau không hiện.
class ModeMigrationPage extends StatefulWidget {
  final int userId;
  const ModeMigrationPage({super.key, required this.userId});

  @override
  State<ModeMigrationPage> createState() => _ModeMigrationPageState();
}

class _ModeMigrationPageState extends State<ModeMigrationPage> {
  static const int _batchSize = 20;

  final DatabaseService _db = DatabaseService();
  final Map<int, String> _selected = {};

  List<Map<String, dynamic>> _items = [];
  int _remaining = 0;
  int _total = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isAiLoading = false;
  Object? _error;

  bool get _allSelected =>
      _items.isNotEmpty &&
      _items.every((w) => _selected.containsKey(w['id'] as int));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await _db.getUnclassifiedWords(widget.userId, limit: _batchSize);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _remaining = page.remaining;
        _total = page.total;
        _selected.clear();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e;
      });
    }
  }

  Future<void> _copyWords() async {
    if (_items.isEmpty) return;
    final text = _items.map((w) => (w['word'] ?? '').toString()).join(', ');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã copy ${_items.length} từ')),
    );
  }

  void _pick(int id, String mode) {
    setState(() {
      if (_selected[id] == mode) {
        _selected.remove(id);
      } else {
        _selected[id] = mode;
      }
    });
  }

  void _selectAll(String mode) {
    setState(() {
      for (final w in _items) {
        _selected[w['id'] as int] = mode;
      }
    });
  }

  Future<void> _aiSuggest() async {
    if (_items.isEmpty || _isAiLoading) return;
    setState(() => _isAiLoading = true);
    try {
      final infos = await _db.enrichWords(
        _items.map((w) => (w['word'] ?? '').toString()).toList(),
      );
      final byWord = {for (final info in infos) info.word.toLowerCase(): info};
      if (!mounted) return;
      setState(() {
        for (final w in _items) {
          final info = byWord[(w['word'] ?? '').toString().toLowerCase()];
          if (info == null || !info.isUsable) continue;
          _selected[w['id'] as int] =
              info.learningMode == 'active' ? 'active' : 'passive';
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI lỗi: ${e.toString().replaceFirst('Exception: ', '')}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isAiLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_allSelected || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final items = [
        for (final w in _items)
          {'id': w['id'] as int, 'mode': _selected[w['id']]},
      ];
      final updated = await _db.bulkClassifyWords(items.cast<Map<String, dynamic>>());
      WordChangeBus().notifyChanged('mode-classified');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã lưu $updated từ')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString().replaceFirst('Exception: ', '')}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final classified = _total - _remaining;
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Phân loại từ vựng'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _remaining > 0
                              ? 'Còn $_remaining/$_total từ chưa phân loại'
                              : 'Đã phân loại $_total/$_total từ',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        'Lô ${_items.length}/$_batchSize',
                        style: TextStyle(
                          fontFamily: 'Be Vietnam Pro',
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _total == 0 ? 0 : classified / _total,
                      minHeight: 5,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('classify-copy'),
                          onPressed: _items.isEmpty ? null : _copyWords,
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: Text('Copy ${_items.length} từ'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _items.isEmpty || _isAiLoading
                              ? null
                              : _aiSuggest,
                          icon: _isAiLoading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_awesome_rounded, size: 16),
                          label: Text(_isAiLoading ? 'Đang hỏi AI…' : 'AI gợi ý'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed:
                              _items.isEmpty ? null : () => _selectAll('active'),
                          child: const Text('Tất cả Học ngay'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed:
                              _items.isEmpty ? null : () => _selectAll('passive'),
                          child: const Text('Tất cả Nên biết'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(theme)),
            if (_items.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                        color: theme.colorScheme.outlineVariant.withAlpha(80)),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Đã chọn ${_selected.length}/${_items.length} từ',
                        style: TextStyle(
                          fontFamily: 'Be Vietnam Pro',
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          key: const ValueKey('classify-submit'),
                          onPressed:
                              _allSelected && !_isSubmitting ? _submit : null,
                          child: Text(
                            _isSubmitting
                                ? 'Đang lưu…'
                                : 'Nộp ${_items.length} từ',
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Không tải được danh sách từ',
              style: TextStyle(
                fontFamily: 'Be Vietnam Pro',
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.task_alt_rounded,
                  size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                _total == 0 ? 'Chưa có từ nào để phân loại' : 'Đã phân loại tất cả từ!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Xong'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final word = _items[index];
        final id = word['id'] as int;
        final wordText = (word['word'] ?? '').toString();
        final meaning = (word['meaning'] ?? '').toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      '${index + 1}.',
                      style: TextStyle(
                        fontFamily: 'Be Vietnam Pro',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wordText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (meaning.isNotEmpty)
                          Text(
                            meaning,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Be Vietnam Pro',
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildToggle(theme, id),
            ],
          ),
        );
      },
    );
  }

  /// Nút lớn 2 bên kiểu on/off: bấm bên nào thì bên đó sáng lên.
  Widget _buildToggle(ThemeData theme, int id) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: _toggleSide(
              id,
              'active',
              'Học ngay',
              Icons.bolt_rounded,
              theme.colorScheme.primary,
              theme,
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: theme.colorScheme.outlineVariant,
          ),
          Expanded(
            child: _toggleSide(
              id,
              'passive',
              'Nên biết',
              Icons.visibility_outlined,
              theme.colorScheme.tertiary,
              theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleSide(
    int id,
    String mode,
    String label,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    final on = _selected[id] == mode;
    return InkWell(
      key: ValueKey('classify-$mode-$id'),
      onTap: () => _pick(id, mode),
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: on ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: on ? Colors.white : color.withAlpha(190),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Be Vietnam Pro',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: on ? Colors.white : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
