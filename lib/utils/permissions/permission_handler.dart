import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionUtil {
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      if (int.parse(Platform.operatingSystemVersion[0]) >= 13) {
        final status = await Permission.photos.request();
        return status.isGranted;
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted;
    }
    return false;
  }

  static Future<bool> checkStoragePermission() async {
    if (Platform.isAndroid) {
      if (int.parse(Platform.operatingSystemVersion[0]) >= 13) {
        return await Permission.photos.status.isGranted;
      } else {
        return await Permission.storage.status.isGranted;
      }
    } else if (Platform.isIOS) {
      return await Permission.photos.status.isGranted;
    }
    return false;
  }
}
