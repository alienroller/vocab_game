import 'package:shared_preferences/shared_preferences.dart';

/// User-facing preferences for the speaking module.
///
/// Backed by `shared_preferences`. Kept intentionally tiny — this is
/// persistent state, not session state.
class SpeakingPreferences {
  static final SpeakingPreferences _instance = SpeakingPreferences._();
  factory SpeakingPreferences() => _instance;
  SpeakingPreferences._();

  static const _kOfflineEngine = 'speaking.offlineEngine';

  /// Whether the user has opted in to the offline Sherpa-ONNX engine.
  /// Default: false (online engine is safer on first run).
  Future<bool> offlineEngineEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOfflineEngine) ?? false;
  }

  Future<void> setOfflineEngineEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOfflineEngine, value);
  }
}
