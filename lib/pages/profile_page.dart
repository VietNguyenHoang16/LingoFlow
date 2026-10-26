import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/pronunciation_service.dart';
import '../services/tts_settings_service.dart';
import '../widgets/ai_api_settings_sheet.dart';
import '../widgets/pwa_install_banner.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  final int userId;

  const ProfilePage({super.key, required this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TtsSettingsService _ttsSettings = TtsSettingsService();
  final AuthService _auth = AuthService();

  TtsVoiceOption? _selectedVoice;
  double _speechRate = 0.85;
  String _phone = '';
  int _aiCount = 0;
  bool _isLoading = true;

  bool _isBackfilling = false;
  int _bfDone = 0;
  int _bfTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final voice = await _ttsSettings.getSelectedVoice();
    final rate = await _ttsSettings.getSpeechRate();
    final session = await _auth.getSession();
    var aiCount = 0;
    try {
      aiCount = (await DatabaseService().getAiConfigs()).length;
    } catch (_) {}
    setState(() {
      _selectedVoice = voice;
      _speechRate = rate;
      _phone = session?['phone'] ?? '';
      _aiCount = aiCount;
      _isLoading = false;
    });
  }

  Future<void> _openAiSettings() async {
    final changed = await AiApiSettingsSheet.show(context);
    if (changed != true) return;
    var aiCount = _aiCount;
    try {
      aiCount = (await DatabaseService().getAiConfigs()).length;
    } catch (_) {}
    if (!mounted) return;
    setState(() => _aiCount = aiCount);
  }

  Future<void> _runPronunciationBackfill() async {
    setState(() => _isBackfilling = true);
    try {
      final res = await PronunciationService().backfillUser(
        widget.userId,
        onProgress: (done, total) {
          if (mounted) {
            setState(() {
              _bfDone = done;
              _bfTotal = total;
            });
          }
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Cap nhat ${res.updated} tu, khong tim thay ${res.notFound} tu')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Loi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBackfilling = false);
    }
  }

  Future<void> _onVoiceChanged(TtsVoiceOption voice) async {
    await _ttsSettings.saveSelectedVoice(voice.id);
    final realVoice =
        _ttsSettings.findRealVoice(voice.code, voice.gender);
    if (realVoice != null) {
      await _ttsSettings.saveRealVoice(
          realVoice['name']!, realVoice['locale']!);
    }
    setState(() => _selectedVoice = voice);

    await TtsEngine().invalidate();
    await _ttsSettings.speakWith('This is a voice preview');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Giong: ${voice.name}')),
      );
    }
  }

  Future<void> _onSpeedChanged(double rate) async {
    setState(() => _speechRate = rate);
  }

  Future<void> _onSpeedChangeStart(double rate) async {
    await TtsEngine().stop();
  }

  Future<void> _onSpeedChangeEnd(double rate) async {
    await _ttsSettings.saveSpeechRate(rate);
    await TtsEngine().invalidate();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Toc do: ${rate.toStringAsFixed(2)}x'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dang xuat?'),
        content: const Text('Ban co chac muon dang xuat khong?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: Colors.red),
            child: const Text('Dang xuat'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _auth.clearSession();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      }
    }
  }

  String _maskPhone(String phone) {
    if (phone.length < 6) return phone;
    final prefix = phone.substring(0, 3);
    final suffix = phone.substring(phone.length - 3);
    return '$prefix${'*' * (phone.length - 6)}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Ho so'),
        ),
        body: Center(
          child: CircularProgressIndicator(
              color: theme.colorScheme.primary),
        ),
      );
    }

    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverAppBar(
            pinned: true,
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            title: Text(
              'Settings',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.5,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Personal info card
                _buildCard(
                  theme: theme,
                  isDark: isDark,
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.person_outline_rounded,
                            color: theme.colorScheme.onSurface,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _maskPhone(_phone),
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'User ID: ${widget.userId}',
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
                ),
                const SizedBox(height: 16),

                // PWA install card (web only, auto hides when installed/dismissed)
                if (kIsWeb)
                  _buildCard(
                    theme: theme,
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Ung dung', Icons.install_mobile_rounded, theme),
                        const SizedBox(height: 4),
                        Text(
                          'Cai VocabPro nhu app de mo nhanh va toan man hinh',
                          style: TextStyle(
                            fontFamily: 'Be Vietnam Pro',
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const PwaInstallBanner(compact: true),
                      ],
                    ),
                  ),
                if (kIsWeb) const SizedBox(height: 16),

                // Voice settings card
                _buildCard(
                  theme: theme,
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Giong doc',
                          Icons.record_voice_over_rounded,
                          theme),
                      const SizedBox(height: 4),
                      Text(
                        'Chon giong doc cho toan bo app',
                        style: TextStyle(
                          fontFamily: 'Be Vietnam Pro',
                          fontSize: 12,
                          color:
                              theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: TtsSettingsService.voices.length,
                          itemBuilder: (context, index) {
                            final voice =
                                TtsSettingsService.voices[index];
                            final isSelected =
                                voice.id == _selectedVoice?.id;
                            final realVoice =
                                _ttsSettings.findRealVoice(
                                    voice.code, voice.gender);
                            return GestureDetector(
                              onTap: () => _onVoiceChanged(voice),
                              child: Container(
                                margin: const EdgeInsets.only(
                                    bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                          .withAlpha(20)
                                      : theme.colorScheme
                                          .surfaceContainerLow,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                            .withAlpha(100)
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle_rounded
                                          : Icons
                                              .radio_button_unchecked_rounded,
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme
                                              .onSurfaceVariant,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            voice.name,
                                            style: TextStyle(
                                              fontFamily:
                                                  'Plus Jakarta Sans',
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                              fontSize: 14,
                                              color: isSelected
                                                  ? theme
                                                      .colorScheme.primary
                                                  : theme.colorScheme
                                                      .onSurface,
                                            ),
                                          ),
                                          if (realVoice != null)
                                            Text(
                                              realVoice['name']!,
                                              style: TextStyle(
                                                fontFamily:
                                                    'Be Vietnam Pro',
                                                fontSize: 11,
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Speech speed card
                _buildCard(
                  theme: theme,
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Toc do doc',
                          Icons.speed_rounded, theme),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.slow_motion_video_rounded,
                            size: 18,
                            color:
                                theme.colorScheme.onSurfaceVariant,
                          ),
                          Expanded(
                            child: Slider(
                              value: _speechRate,
                              min: 0.25,
                              max: 1.5,
                              divisions: 25,
                              onChangeStart: _onSpeedChangeStart,
                              onChanged: _onSpeedChanged,
                              onChangeEnd: _onSpeedChangeEnd,
                            ),
                          ),
                          Icon(
                            Icons.fast_forward_rounded,
                            size: 18,
                            color:
                                theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withAlpha(20),
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_speechRate.toStringAsFixed(2)}x',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _buildCard(
                  theme: theme,
                  isDark: isDark,
                  child: InkWell(
                    onTap: _openAiSettings,
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildSectionTitle(
                                  'API tạo ví dụ', Icons.key_rounded, theme),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tối đa 3 API, ưu tiên từ trên xuống. Đã cấu hình $_aiCount/3.',
                          style: TextStyle(
                            fontFamily: 'Be Vietnam Pro',
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Pronunciation data card
                _buildCard(
                  theme: theme,
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Du lieu',
                          Icons.graphic_eq_rounded, theme),
                      const SizedBox(height: 4),
                      Text(
                        'Tu dong dien phien am IPA cho tu con thieu',
                        style: TextStyle(
                          fontFamily: 'Be Vietnam Pro',
                          fontSize: 12,
                          color:
                              theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isBackfilling
                              ? null
                              : _runPronunciationBackfill,
                          icon: _isBackfilling
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_fix_high_rounded,
                                  size: 18),
                          label: Text(
                            _isBackfilling
                                ? 'Dang cap nhat...'
                                : 'Cap nhat phien am',
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (_isBackfilling && _bfTotal > 0) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: _bfDone / _bfTotal,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$_bfDone/$_bfTotal',
                          style: TextStyle(
                            fontFamily: 'Be Vietnam Pro',
                            fontSize: 12,
                            color:
                                theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Logout
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded,
                        color: Colors.red, size: 18),
                    label: const Text(
                      'Dang xuat',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: Colors.red.withAlpha(120),
                          width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required ThemeData theme,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(
      String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
          ),
          child: Icon(icon, size: 16, color: theme.colorScheme.onSurface),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }


}
