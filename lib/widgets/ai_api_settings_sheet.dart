import 'package:flutter/material.dart';

import '../services/ai_settings_service.dart';
import '../services/database_service.dart';

class AiApiSettingsSheet extends StatefulWidget {
  const AiApiSettingsSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const AiApiSettingsSheet(),
    );
  }

  @override
  State<AiApiSettingsSheet> createState() => _AiApiSettingsSheetState();
}

class _ProviderForm {
  final TextEditingController name;
  final TextEditingController baseUrl;
  final TextEditingController apiKey;
  final TextEditingController model;

  bool obscure = true;
  bool testing = false;
  bool testOk = false;
  String? testMessage;

  _ProviderForm({AiProviderConfig? config})
    : name = TextEditingController(text: config?.name ?? ''),
      baseUrl = TextEditingController(text: config?.baseUrl ?? ''),
      apiKey = TextEditingController(text: config?.apiKey ?? ''),
      model = TextEditingController(text: config?.model ?? '');

  bool get isEmpty =>
      name.text.trim().isEmpty &&
      baseUrl.text.trim().isEmpty &&
      apiKey.text.trim().isEmpty &&
      model.text.trim().isEmpty;

  bool get isComplete =>
      baseUrl.text.trim().isNotEmpty &&
      apiKey.text.trim().isNotEmpty &&
      model.text.trim().isNotEmpty;

  AiProviderConfig toConfig() => AiProviderConfig(
    name: name.text.trim(),
    baseUrl: baseUrl.text.trim(),
    apiKey: apiKey.text.trim(),
    model: model.text.trim(),
  );

  void dispose() {
    name.dispose();
    baseUrl.dispose();
    apiKey.dispose();
    model.dispose();
  }
}

class _AiApiSettingsSheetState extends State<AiApiSettingsSheet> {
  final DatabaseService _db = DatabaseService();
  final List<_ProviderForm> _forms = [];

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final form in _forms) {
      form.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final configs = await _db.getAiConfigs();
      if (!mounted) return;
      setState(() {
        for (final form in _forms) {
          form.dispose();
        }
        _forms
          ..clear()
          ..addAll(configs.map((config) => _ProviderForm(config: config)));
        if (_forms.isEmpty) _forms.add(_ProviderForm());
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        for (final form in _forms) {
          form.dispose();
        }
        _forms
          ..clear()
          ..add(_ProviderForm());
        _loading = false;
        _loadError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _add() {
    if (_forms.length >= AiProviderConfig.maxProviders) return;
    setState(() => _forms.add(_ProviderForm()));
  }

  void _remove(int index) {
    final form = _forms.removeAt(index);
    form.dispose();
    setState(() {
      if (_forms.isEmpty) _forms.add(_ProviderForm());
    });
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _forms.length) return;
    setState(() {
      final form = _forms.removeAt(index);
      _forms.insert(target, form);
    });
  }

  Future<void> _test(_ProviderForm form) async {
    if (!form.isComplete) {
      setState(() {
        form.testOk = false;
        form.testMessage = 'Nhập đủ Base URL, API key và model.';
      });
      return;
    }
    setState(() {
      form.testing = true;
      form.testMessage = null;
    });
    try {
      final result = await _db.testAiProvider(form.toConfig());
      if (!mounted) return;
      final ok = result['ok'] == true;
      final latency = (result['latencyMs'] as num?)?.toInt() ?? 0;
      setState(() {
        form.testing = false;
        form.testOk = ok;
        form.testMessage = ok
            ? 'Kết nối OK · ${latency}ms'
            : (result['message']?.toString() ?? 'Không kết nối được.');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        form.testing = false;
        form.testOk = false;
        form.testMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _save() async {
    if (_loadError != null) return;
    final configs = <AiProviderConfig>[];
    for (final form in _forms) {
      if (form.isEmpty) continue;
      if (!form.isComplete) {
        setState(() => _error = 'Mỗi API cần đủ Base URL, API key và model.');
        return;
      }
      configs.add(form.toConfig());
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _db.saveAiConfigs(configs);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final height = (media.size.height * 0.9 - bottomInset).clamp(
      280.0,
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
                        'API tạo ví dụ',
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
                  'Tối đa 3 API, thử từ trên xuống khi tạo ví dụ. Key chỉ lưu trên thiết bị này.',
                  style: TextStyle(
                    fontFamily: 'Be Vietnam Pro',
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _loadError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _loadError!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Be Vietnam Pro',
                                  fontSize: 13,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        itemCount: _forms.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildProviderCard(
                            theme: theme,
                            index: index,
                            form: _forms[index],
                          ),
                        ),
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
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _loadError == null &&
                                _forms.length < AiProviderConfig.maxProviders
                            ? _add
                            : null,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          _forms.length < AiProviderConfig.maxProviders
                              ? 'Thêm API'
                              : 'Tối đa 3 API',
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving || _loadError != null ? null : _save,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          _saving ? 'Đang lưu...' : 'Lưu',
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w700,
                          ),
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

  Widget _buildProviderCard({
    required ThemeData theme,
    required int index,
    required _ProviderForm form,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withAlpha(80),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'Ưu tiên ${index + 1}',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Đưa lên',
                onPressed: index > 0 ? () => _move(index, -1) : null,
                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Đưa xuống',
                onPressed: index < _forms.length - 1
                    ? () => _move(index, 1)
                    : null,
                icon: const Icon(Icons.arrow_downward_rounded, size: 18),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Xoá',
                onPressed: () => _remove(index),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _field(
            controller: form.name,
            label: 'Tên gợi nhớ (tuỳ chọn)',
            hint: 'Xkiro, Gemini...',
          ),
          _field(
            controller: form.baseUrl,
            label: 'Base URL',
            hint: 'https://api.xkiro.com/v1',
            keyboardType: TextInputType.url,
          ),
          _field(
            controller: form.apiKey,
            label: 'API Key',
            hint: 'sk-...',
            obscure: form.obscure,
            suffix: IconButton(
              onPressed: () => setState(() => form.obscure = !form.obscure),
              icon: Icon(
                form.obscure
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 18,
              ),
            ),
          ),
          _field(
            controller: form.model,
            label: 'Model',
            hint: 'openai/gpt-5.6-sol',
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: form.testing ? null : () => _test(form),
                icon: form.testing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering_rounded, size: 16),
                label: Text(
                  form.testing ? 'Đang thử...' : 'Kiểm tra',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (form.testMessage != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    form.testMessage!,
                    style: TextStyle(
                      fontFamily: 'Be Vietnam Pro',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: form.testOk
                          ? Colors.green
                          : theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(fontFamily: 'Be Vietnam Pro', fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}
