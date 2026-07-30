import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../core/services/supabase_service.dart';

class DeviceBindingService {
  static final DeviceBindingService _instance =
      DeviceBindingService._internal();
  factory DeviceBindingService() => _instance;
  DeviceBindingService._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<Map<String, String>> getDeviceInfo() async {
    String deviceId = 'unknown_hardware_id';
    String model = 'Unknown Model';
    String osVersion = 'Unknown OS';

    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        deviceId = webInfo.userAgent ?? 'web_browser_${DateTime.now().millisecondsSinceEpoch}';
        model = webInfo.browserName.name;
        osVersion = webInfo.platform ?? 'Web';
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        model = '${androidInfo.manufacturer} ${androidInfo.model}';
        osVersion = 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'ios_device';
        model = iosInfo.name;
        osVersion = 'iOS ${iosInfo.systemVersion}';
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        deviceId = windowsInfo.deviceId;
        model = windowsInfo.computerName;
        osVersion = 'Windows ${windowsInfo.majorVersion}.${windowsInfo.minorVersion}';
      }
    } catch (e) {
      debugPrint('DeviceBindingService getDeviceInfo note: $e');
    }

    return {
      'deviceId': deviceId,
      'model': model,
      'osVersion': osVersion,
    };
  }

  Future<bool> registerDeviceBinding(String userId) async {
    try {
      final info = await getDeviceInfo();
      return await SupabaseService().bindDevice(
        userId: userId,
        deviceHardwareId: info['deviceId']!,
        deviceModel: info['model'],
        osVersion: info['osVersion'],
      );
    } catch (e) {
      debugPrint('registerDeviceBinding error: $e');
      return false;
    }
  }
}
