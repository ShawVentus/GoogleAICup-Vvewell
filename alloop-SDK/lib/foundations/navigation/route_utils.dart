import 'package:alloop_blue_lite/alloop_blue_lite.dart';
import 'package:get/get.dart';

import '../../features/aizoring/domain/models/smart_ring_device.dart';
import '../../features/common/data/repositories/common_repository.dart';
import '../../features/common/presentation/controllers/device_status_controller.dart';

/// Utility class for parsing route arguments.
class RouteUtils {
  RouteUtils._();

  /// Extracts the deviceId from [arguments].
  static String? extractDeviceId(dynamic arguments) {
    if (arguments is String) {
      return arguments;
    } else if (arguments is Map<String, dynamic>) {
      return arguments['deviceId'] as String?;
    } else if (arguments is LiteDevice) {
      return arguments.id;
    } else if (arguments is SmartRingDevice) {
      return arguments.id;
    }
    return null;
  }

  /// Extracts a SmartRingDevice from [arguments].
  static SmartRingDevice? extractDevice(dynamic arguments) {
    if (arguments is SmartRingDevice) return arguments;
    if (arguments is Map) return arguments['device'] as SmartRingDevice?;
    return null;
  }

  static bool extractAutoStart(dynamic arguments) =>
      arguments is Map && arguments['autoStart'] == true;

  static bool extractConnectOnOpen(dynamic arguments) =>
      arguments is Map && arguments['connectOnOpen'] == true;
}

/// Binding for global controllers.
class GlobalControllersBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<CommonRepository>()) {
      Get.lazyPut(() => CommonRepository());
    }
  }
}

/// Base binding class for device-related pages.
abstract class DevicePageBinding extends Bindings {
  String? extractDeviceId() {
    return RouteUtils.extractDeviceId(Get.arguments);
  }

  void registerCommonControllers(String deviceId) {
    GlobalControllersBinding().dependencies();

    if (!Get.isRegistered<DeviceStatusController>()) {
      Get.put<DeviceStatusController>(
        DeviceStatusController(repository: Get.find()),
        permanent: true,
      );
    }
  }
}
