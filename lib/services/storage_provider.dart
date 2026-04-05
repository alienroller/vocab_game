import 'package:vocab_game/services/app_preferences.dart';

class LocalStorageProvider {
  LocalStorageProvider._internal();

  static final LocalStorageProvider _instance = LocalStorageProvider._internal();

  static LocalStorageProvider get instance => _instance;

  late final AppPreferences _preferences;

  static AppPreferences get cache => _instance._preferences;

  /// 🔹 Initialize once
  static Future<void> init() async {
    await _instance._initialize();
  }

  Future<void> _initialize() async {
    _preferences = await AppPreferences.init();
  }
}
