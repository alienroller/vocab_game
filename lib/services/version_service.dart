import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AppVersionInfo {
  static final AppVersionInfo instance = _AppVersionInfoImpl._();

  String get version;
  String get buildNumber;

  Future<void> init();
  Future<bool> checkForUpdate();
}

class _AppVersionInfoImpl implements AppVersionInfo {
  _AppVersionInfoImpl._();

  String _version = '';
  String _buildNumber = '';

  @override
  String get version => _version;

  @override
  String get buildNumber => _buildNumber;

  @override
  Future<bool> checkForUpdate() async {
    final supabase = Supabase.instance.client;
    final platform =
        Platform.isAndroid
            ? 'android'
            : Platform.isIOS
            ? 'ios'
            : 'web';

    final res = await supabase.functions.invoke(
      'getconfig',
      body: {'platform': platform},
    );

    final minBuildNumber = res.data['min_build_number'] as int;
    
    final currentBuildNumber = int.tryParse(_buildNumber) ?? 0;

    if (currentBuildNumber < minBuildNumber) return true;

    return false;
  }

  @override
  Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    _version = info.version; // masalan: 1.0.0
    _buildNumber = info.buildNumber; // masalan: 1
  }
}
