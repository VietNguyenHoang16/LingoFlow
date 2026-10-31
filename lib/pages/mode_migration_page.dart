import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../services/word_change_bus.dart';

/// Màn duyệt phân loại lại toàn bộ từ cũ thành Học ngay / Nên biết.
/// AI gợi ý theo mục tiêu giao tiếp + IT; người dùng sửa bằng 1 chạm rồi áp dụng.
class ModeMigrationPage extends StatefulWidget {
  final int userId;
  const ModeMigrationPage({super.key, required this.userId});

  @override
  State<ModeMigrationPage> createState() => _ModeMigrationPageState();
}

class _ModeMigrationPageState extends State<ModeMigrationPage> {
  final DatabaseService _db = DatabaseService();

  bool _isLoading = true;
  bool _isClassifying = false;
  bool _isApplying = false;
  Object? _loadError;
  List<Map<String, dynamic>> _items = [];
  final Map<int, String> _originalMode = {};
  int _classified = 0;
  int _classifyTotal = 0;
  String? _classifyError;

  int get _changedCount => _items
      .where((w) => (w['mode'] ?? 'active') != _originalMode[w['id']])
      .length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final words = await _db.getMigrationCandidates(widget.userId);
      if (!mounted) return;
      _originalMode.clear();
      for (final w in words) {
        final mode = (w['learning_mode'] ?? 'active').toString();
        _originalMode[w['id'] as int] = mode;
      }
      setState(() {
        _items = words
            .map((w) => {...w, 'mode': (w['learning_mode'] ?? 'active').toString()})
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e;
      });
    }
  }

  Future<void> _classifyWithAi() async {
    if (_isClassifying || _items.isEmpty) return;
    setState(() {
      _isClassifying = true;
      _classifyError = null;
      _classified = 0;
      _classifyTotal = _items.length;
    });

    const chunkSize = 30;
    try {
      for (var start = 0; start < _items.length; start += chunkSize) {
        final end = (start + chunkSize).clamp(0, _items.length);
        final chunk = _items.sublist(start, end);
        final words = chunk.map((w) => (w['word'] ?? '').toString()).toList();
        final infos = await _db.enrichWords(words);
        final byWord = {
          for (final info in infos) info.word.toLowerCase(): info,
        };
        if (!mounted) return;
        setState(() {
          for (final item in chunk) {
            final info = byWord[(item['word'] ?? '').toString().toLowerCase()];
            if (info == null || !info.isUsable) continue;
            // AI "skip" (không ưu tiên) -> giữ ở Nên biết, người dùng có thể xoá sau.
            item['mode'] =
                info.learningMode == 'active' ? 'active' : 'passive';
            if (info.collocations.isNotEmpty &&
                (item['collocations'] ?? '').toString().isEmpty) {
              item['collocations'] = info.collocations;
            }
          }
          _classified = end;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _classifyError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isClassifying = false);
    }
  }

  void _cycleMode(Map<String, dynamic> item) {
    setState(() {
      item['mode'] = (item['mode'] ?? 'active') == 'active' ? 'passive' : 'active';
    });
  }

  void _setAll(String mode) {
    setState(() {
      for (final item in _items) {
        item['mode'] = mode;
      }
    });
  }

  Future<void> _apply() async {
    final changed = _items
        .where((w) => (w['mode'] ?? 'active') != _originalMode[w['id']])
        .toList();
    if (changed.isEmpty || _isApplying) return;
    setState(() => _isApplying = true);
    try {
      final updated = await _db.bulkSetLearningMode([
        for (final w in changed)
          {'id': w['id'] as int, 'mode': (w['mode'] ?? 'active').toString()},
      ]);
      WordChangeBus().notifyChanged('mode-migration');
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isApplying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lỗi: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Phân loại lại từ vựng'),
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
                  Text(
                    'AI xếp từ thành Học ngay (dùng được ngay) hoặc Nên biết (chỉ cần hiểu). '
                    'Chạm vào chip để sửa trước khi áp dụng.',
                    style: TextStyle(
                      fontFamily: 'Be Vietnam Pro',
                      fontSize: 12,
                      height: 1.45,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isClassifying ? null : () => _setAll('active'),
                          child: const Text('Tất cả Học ngay'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isClassifying ? null : () => _setAll('passive'),
                          child: const Text('Tất cả Nên biết'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: FilledButton.icon(
                      onPressed: _isClassifying ? null : _classifyWithAi,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(
                        _isClassifying
                            ? 'AI đang phân loại $_classified/$_classifyTotal…'
                            : 'AI phân loại giúp tôi',
                      ),
                    ),
                  ),
                  if (_isClassifying) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: _classifyTotal == 0
                          ? null
                          : _classified / _classifyTotal,
                      minHeight: 3,
                    ),
                  ],
                  if (_classifyError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Lỗi AI: $_classifyError',
                      style: TextStyle(
                        fontFamily: 'Be Vietnam Pro',
                        fontSize: 12,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(child: _buildBody(theme)),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(80)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isApplying || _changedCount == 0 ? null : _apply,
                    child: Text(
                      _isApplying
                          ? 'Đang áp dụng…'
                          : 'Áp dụng ($_changedCount thay đổi)',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
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
    if (_loadError != null) {
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
        child: Text(
          'Chưa có từ nào để phân loại',
          style: TextStyle(
            fontFamily: 'Be Vietnam Pro',
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      itemCount: _items.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: theme.colorScheme.outlineVariant.withAlpha(90),
      ),
      itemBuilder: (context, index) {
        final item = _items[index];
        final word = (item['word'] ?? '').toString();
        final meaning = (item['meaning'] ?? '').toString();
        final mode = (item['mode'] ?? 'active').toString();
        final isPassive = mode == 'passive';
        final color = isPassive
            ? theme.colorScheme.tertiary
            : theme.colorScheme.primary;
        final changed = mode != _originalMode[item['id']];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Be Vietnam Pro',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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
              if (changed)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.edit_rounded,
                      size: 12, color: theme.colorScheme.outline),
                ),
              GestureDetector(
                onTap: () => _cycleMode(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withAlpha(90)),
                  ),
                  child: Text(
                    isPassive ? 'Nên biết' : 'Học ngay',
                    style: TextStyle(
                      fontFamily: 'Be Vietnam Pro',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
