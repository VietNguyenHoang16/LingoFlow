import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/auth_service.dart';
import '../services/tts_settings_service.dart';
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
  bool _isLoading = true;
  FlutterTts? _previewTts;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final voice = await _ttsSettings.getSelectedVoice();
    final rate = await _ttsSettings.getSpeechRate();
    final session = await _auth.getSession();
    setState(() {
      _selectedVoice = voice;
      _speechRate = rate;
      _phone = session?['phone'] ?? '';
      _isLoading = false;
    });
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

    final previewTts = FlutterTts();
    await _ttsSettings.applyTo(previewTts);
    await previewTts.speak('This is a voice preview');

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
    _previewTts = FlutterTts();
    await _previewTts?.stop();
  }

  Future<void> _onSpeedChangeEnd(double rate) async {
    await _ttsSettings.saveSpeechRate(rate);
    if (_previewTts != null) {
      await _ttsSettings.applyTo(_previewTts!);
      await _previewTts!.speak('Speed test');
    }
    _previewTts = null;
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
            expandedHeight: 200,
            pinned: true,
            backgroundColor: theme.colorScheme.primary,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withAlpha(200),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // Avatar
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withAlpha(100),
                            width: 3,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            '👤',
                            style: TextStyle(fontSize: 36),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _maskPhone(_phone),
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${widget.userId}',
                        style: TextStyle(
                          fontFamily: 'Be Vietnam Pro',
                          fontSize: 12,
                          color: Colors.white.withAlpha(180),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding:
                const EdgeInsets.fromLTRB(20, 20, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Personal info card
                _buildCard(
                  theme: theme,
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(
                          'Thong tin ca nhan', Icons.badge_outlined,
                          theme),
                      const SizedBox(height: 16),
                      _buildInfoRow('So DT',
                          _maskPhone(_phone), theme),
                      const Divider(height: 20),
                      _buildInfoRow(
                          'User ID',
                          widget.userId.toString(),
                          theme),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(6),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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
            color: theme.colorScheme.primaryContainer.withAlpha(60),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
      String label, String value, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Be Vietnam Pro',
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Be Vietnam Pro',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
