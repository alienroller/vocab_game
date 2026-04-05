import 'package:shared_preferences/shared_preferences.dart';

/// AppPreferences — type-safe wrapper for SharedPreferences.
class AppPreferences {
  AppPreferences._(this._prefs);

  final SharedPreferences _prefs;

  /// Initialize SharedPreferences once
  static Future<AppPreferences> init() async {
    final prefs = await SharedPreferences.getInstance();
    return AppPreferences._(prefs);
  }

  // ----------------------------
  // 📝 String
  // ----------------------------
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  String getString(String key, {String defaultValue = ''}) => _prefs.getString(key) ?? defaultValue;

  // ----------------------------
  // 🔢 Int
  // ----------------------------
  Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  int getInt(String key, {int defaultValue = 0}) => _prefs.getInt(key) ?? defaultValue;

  // ----------------------------
  // 🔘 Bool
  // ----------------------------
  Future<void> setBool(String key, value) async => await _prefs.setBool(key, value);

  bool getBool(String key, {bool defaultValue = false}) => _prefs.getBool(key) ?? defaultValue;

  // ----------------------------
  // 💲 Double
  // ----------------------------
  Future<void> setDouble(String key, double value) async {
    await _prefs.setDouble(key, value);
  }

  double getDouble(String key, {double defaultValue = 0.0}) =>
      _prefs.getDouble(key) ?? defaultValue;

  // ----------------------------
  // 📜 List<String>
  // ----------------------------
  Future<void> setStringList(String key, List<String> value) async {
    await _prefs.setStringList(key, value);
  }

  List<String> getStringList(String key, {List<String> defaultValue = const []}) =>
      _prefs.getStringList(key) ?? defaultValue;

  // ----------------------------
  // ❌ Remove key
  // ----------------------------
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  // ----------------------------
  // 🧹 Clear all
  // ----------------------------
  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
