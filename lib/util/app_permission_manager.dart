import 'package:permission_handler/permission_handler.dart';

typedef PermissionCallback = void Function();

mixin AppPermissionManager {
  static Future<void> requestPermission({
    required Permission permission,
    required PermissionCallback onGranted,
    required PermissionCallback onDenied,
    PermissionCallback? onPermanentlyDenied,
  }) async {
    try {
      final status = await permission.status;

      if (status.isGranted) {
        onGranted();

        return;
      }

      final newStatus = await permission.request();

      if (newStatus.isGranted) {
        onGranted();

        return;
      }

      if (newStatus.isPermanentlyDenied) {
        onPermanentlyDenied?.call();

        return;
      }

      if (newStatus.isDenied) {
        onDenied();

        return;
      }
    } catch (_) {}
  }
}
