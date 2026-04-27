import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../services/offline_model_manager.dart';
import '../services/speaking_preferences.dart';
import '../services/speech_service.dart';

/// Settings surface for the speaking module.
///
/// The only knob today is the offline engine: toggle it on, download the
/// model (one time, ~30 MB), and speech recognition runs fully on-device.
class SpeakingSettingsScreen extends StatefulWidget {
  const SpeakingSettingsScreen({super.key});

  @override
  State<SpeakingSettingsScreen> createState() => _SpeakingSettingsScreenState();
}

class _SpeakingSettingsScreenState extends State<SpeakingSettingsScreen> {
  static const _spec = OfflineModelManager.defaultEnglishAsr;

  bool _loading = true;
  bool _offlineEnabled = false;
  bool _installed = false;
  bool _hasPartial = false;
  int _diskBytes = 0;

  bool _downloading = false;
  double _downloadFraction = 0.0;
  String _downloadPhase = '';
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final prefs = SpeakingPreferences();
    final mgr = OfflineModelManager();
    final enabled = await prefs.offlineEngineEnabled();
    final installed = await mgr.isInstalled(_spec);
    final partial = !installed && await mgr.hasPartialInstall(_spec);
    final bytes = (installed || partial) ? await mgr.diskUsage(_spec) : 0;
    if (!mounted) return;
    setState(() {
      _offlineEnabled = enabled;
      _installed = installed;
      _hasPartial = partial;
      _diskBytes = bytes;
      _loading = false;
    });
  }

  Future<void> _toggleOffline(bool value) async {
    final prefs = SpeakingPreferences();
    if (value && !_installed) {
      // Require the model before enabling — otherwise we'd silently fall back.
      await _download();
      if (!await OfflineModelManager().isInstalled(_spec)) return;
    }
    await prefs.setOfflineEngineEnabled(value);
    await SpeechService().reconfigure();
    if (!mounted) return;
    setState(() => _offlineEnabled = value);
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _downloadFraction = 0.0;
      _downloadPhase = 'Starting';
      _downloadError = null;
    });
    try {
      await OfflineModelManager().install(
        _spec,
        onProgress: (fraction, phase) {
          if (!mounted) return;
          setState(() {
            _downloadFraction = fraction;
            _downloadPhase = phase;
          });
        },
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloadError = _friendlyError(e));
      await _refresh();
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _uninstall() async {
    await OfflineModelManager().uninstall(_spec);
    final prefs = SpeakingPreferences();
    if (_offlineEnabled) {
      await prefs.setOfflineEngineEnabled(false);
      await SpeechService().reconfigure();
    }
    if (!mounted) return;
    setState(() => _downloadError = null);
    await _refresh();
  }

  /// Settings-screen-friendly message. Strips presigned URL query strings
  /// from ClientException so the user sees one line, not a wall of hex.
  String _friendlyError(Object e) {
    final raw = e.toString();
    if (raw.contains('Connection closed while receiving data') ||
        raw.contains('SocketException') ||
        raw.contains('HandshakeException')) {
      return 'Connection dropped during download. Check your internet and try again.';
    }
    if (raw.contains('Incomplete download') ||
        raw.contains('Suspiciously small')) {
      return 'The download was cut short. Try again — a stable Wi-Fi helps.';
    }
    if (raw.contains('Extraction finished but')) {
      return 'The archive was incomplete. Tap "Clean up" then try downloading again.';
    }
    // Drop everything after the first newline and any ?query=… noise.
    final firstLine = raw.split('\n').first;
    final uriIdx = firstLine.indexOf(', uri=');
    return uriIdx >= 0 ? firstLine.substring(0, uriIdx) : firstLine;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Speech Engine')),
      body: Container(
        decoration: BoxDecoration(
          gradient:
              isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _header(isDark),
                    const SizedBox(height: 16),
                    _toggleCard(isDark),
                    const SizedBox(height: 16),
                    _modelCard(isDark),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _header(bool isDark) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: AppTheme.borderRadiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'On-device recognition',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Runs Sherpa-ONNX Zipformer locally. No audio leaves your device, '
            'and no network round-trip means faster feedback.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: _cardDeco(isDark),
      child: SwitchListTile.adaptive(
        title: const Text(
          'Use offline engine',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          _offlineEnabled
              ? 'Active — speech runs on-device.'
              : 'Off — using the system/online recognizer.',
        ),
        value: _offlineEnabled,
        onChanged: _downloading ? null : _toggleOffline,
      ),
    );
  }

  Widget _modelCard(bool isDark) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _spec.displayName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _spec.description,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 14),
          if (_installed) ...[
            _stat('On disk', _formatBytes(_diskBytes)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _downloading ? null : _uninstall,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Remove'),
                  ),
                ),
              ],
            ),
          ] else ...[
            if (_hasPartial) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.amberDark.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppTheme.amberDark.withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 18, color: AppTheme.amberDark),
                        SizedBox(width: 6),
                        Text(
                          'Previous install incomplete',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'A partial model is on disk (${_formatBytes(_diskBytes)}). '
                      'Clean it up before retrying.',
                      style: const TextStyle(fontSize: 12.5, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _downloading ? null : _uninstall,
                      icon: const Icon(Icons.cleaning_services_rounded),
                      label: const Text('Clean up'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _stat('Download size', '~${_spec.approxDownloadMB} MB'),
            const SizedBox(height: 12),
            if (_downloading) ...[
              LinearProgressIndicator(value: _downloadFraction),
              const SizedBox(height: 6),
              Text(
                '$_downloadPhase — ${(_downloadFraction * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12),
              ),
            ] else
              FilledButton.icon(
                onPressed: _hasPartial ? null : _download,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download model'),
              ),
            if (_downloadError != null) ...[
              const SizedBox(height: 10),
              Text(
                _downloadError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
          ],
        ],
      ),
    );
  }

  BoxDecoration _cardDeco(bool isDark) => BoxDecoration(
        gradient:
            isDark ? AppTheme.darkGlassGradient : AppTheme.lightGlassGradient,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
      );

  Widget _stat(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
        Text(value, style: const TextStyle(fontSize: 12.5)),
      ],
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    var value = bytes.toDouble();
    while (value >= 1024 && i < units.length - 1) {
      value /= 1024;
      i++;
    }
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[i]}';
  }
}
