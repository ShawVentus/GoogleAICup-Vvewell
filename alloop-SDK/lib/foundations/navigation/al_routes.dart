import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../features/algorithm_verify/data/repositories/algorithm_verify_repository.dart';
import '../../features/algorithm_verify/presentation/controllers/algorithm_verify_controller.dart';
import '../../features/algorithm_verify/presentation/pages/algorithm_verify_page.dart';
import '../../features/aizoring/domain/models/smart_ring_device.dart';
import '../../features/aizoring/domain/models/smart_ring_type.dart';
import '../../features/aizoring/data/repositories/aizoring_device_repository.dart';
import '../../features/aizoring/presentation/controllers/aizoring_device_detail_controller.dart';
import '../../features/aizoring/presentation/controllers/aizoring_health_data_controller.dart';
import '../../features/aizoring/presentation/controllers/aizoring_measurement_controller.dart';
import '../../features/aizoring/presentation/controllers/aizoring_sleep_controller.dart';
import '../../features/aizoring/presentation/pages/aizoring_device_detail_page.dart';
import '../../features/aizoring/presentation/pages/aizoring_measurement_page.dart';
import '../../features/aizoring/presentation/pages/aizoring_health_data_page.dart';
import '../../features/aizoring/presentation/pages/aizoring_sleep_page.dart';
import '../../features/common/presentation/controllers/device_status_controller.dart';
import '../../features/device_detail/data/device_detail_repository.dart';
import '../../features/device_detail/presentation/controllers/device_detail_controller.dart';
import '../../features/device_detail/presentation/pages/device_detail_page.dart';
import '../../features/history_sync_debug/presentation/controllers/history_sync_debug_controller.dart';
import '../../features/history_sync_debug/presentation/pages/history_sync_debug_page.dart';
import '../../features/glasses/data/rokid_glasses_repository.dart';
import '../../features/glasses/presentation/controllers/rokid_glasses_controller.dart';
import '../../features/glasses/presentation/pages/rokid_glasses_page.dart';
import '../../features/main/home_page.dart';
import '../../features/main/device_center_page.dart';
import '../../features/main/splash_page.dart';
import '../../features/profile/presentation/pages/benefits_page.dart';
import '../../features/profile/presentation/pages/language_settings_page.dart';
import '../../features/profile/presentation/pages/notification_settings_page.dart';
import '../../features/profile/presentation/pages/orders_page.dart';
import '../../features/scan/data/scan_repository.dart';
import '../../features/scan/presentation/controllers/scan_controller.dart';
import '../../features/scan/presentation/pages/scan_page.dart';
import '../../features/xiaozhi/data/xiaozhi_ble_repository.dart';
import '../../features/xiaozhi/presentation/controllers/xiaozhi_device_controller.dart';
import '../../features/xiaozhi/presentation/pages/xiaozhi_device_detail_page.dart';
import '../../features/radar/data/radar_ble_repository.dart';
import '../../features/radar/presentation/controllers/radar_device_controller.dart';
import '../../features/radar/presentation/pages/radar_device_page.dart';
import '../../features/robot/data/robot_ble_repository.dart';
import '../../features/robot/presentation/controllers/robot_device_controller.dart';
import '../../features/robot/presentation/pages/robot_device_page.dart';
import '../../features/rppg/presentation/pages/rppg_measurement_page.dart';
import '../../features/thermal_camera/data/thermal_camera_repository.dart';
import '../../features/thermal_camera/presentation/controllers/thermal_camera_controller.dart';
import '../../features/thermal_camera/presentation/pages/thermal_camera_page.dart';
import 'route_utils.dart';

/// Application route configuration.
class AlRoutes {
  AlRoutes._();

  static const String splash = '/splash';
  static const String home = '/home';
  static const String scan = '/scan';
  static const String deviceCenter = '/deviceCenter';
  static const String deviceDetail = '/deviceDetail';
  static const String algorithmVerify = '/algorithmVerify';
  static const String historySyncDebug = '/historySyncDebug';
  static const String orders = '/orders';
  static const String benefits = '/benefits';
  static const String notificationSettings = '/notificationSettings';
  static const String languageSettings = '/languageSettings';

  // AIZORING routes
  static const String aizoringDeviceDetail = '/aizoringDeviceDetail';
  static const String aizoringMeasurement = '/aizoringMeasurement';
  static const String aizoringHealthData = '/aizoringHealthData';
  static const String aizoringSleep = '/aizoringSleep';

  // XiaoZhi route
  static const String xiaozhiDeviceDetail = '/xiaozhiDeviceDetail';
  static const String radarDeviceDetail = '/radarDeviceDetail';
  static const String robotDeviceDetail = '/robotDeviceDetail';
  static const String rppgMeasurement = '/rppgMeasurement';
  static const String rokidGlasses = '/rokidGlasses';
  static const String thermalCamera = '/thermalCamera';
}

void registerAlloopDeviceDetailDependencies({
  required SmartRingDevice device,
  required bool autoStart,
  required bool connectOnOpen,
}) {
  GlobalControllersBinding().dependencies();
  if (!Get.isRegistered<DeviceStatusController>()) {
    Get.put<DeviceStatusController>(
      DeviceStatusController(repository: Get.find()),
      permanent: true,
    );
  }
  Get.lazyPut<DeviceDetailDataSource>(
    () => DeviceDetailRepository(deviceId: device.id),
  );
  Get.lazyPut(
    () => DeviceDetailController(
      repository: Get.find<DeviceDetailDataSource>(),
      initialName: device.name,
      initialAutoStart: autoStart,
      initialConnectOnOpen: connectOnOpen,
    ),
  );
}

class AlPages {
  static List<GetPage> get pages => [
    GetPage(
      name: AlRoutes.splash,
      page: () => const SplashPage(),
      transition: Transition.fade,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AlRoutes.home,
      page: () => const HomePage(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AlRoutes.rppgMeasurement,
      page: () => const RppgMeasurementPage(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 250),
    ),
    GetPage(
      name: AlRoutes.orders,
      page: () => const OrdersPage(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AlRoutes.benefits,
      page: () => const BenefitsPage(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AlRoutes.notificationSettings,
      page: () => const NotificationSettingsPage(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AlRoutes.languageSettings,
      page: () => const LanguageSettingsPage(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AlRoutes.scan,
      page: () => const ScanPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => ScanRepository());
        Get.lazyPut(() => ScanController(repository: Get.find()));
      }),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AlRoutes.deviceCenter,
      page: () => const DeviceCenterPage(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 250),
    ),
    GetPage(
      name: AlRoutes.rokidGlasses,
      page: () => const RokidGlassesPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => RokidGlassesRepository());
        Get.lazyPut(() => RokidGlassesController(repository: Get.find()));
      }),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 250),
    ),
    GetPage(
      name: AlRoutes.thermalCamera,
      page: () => const ThermalCameraPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => ThermalCameraRepository());
        Get.lazyPut(() => ThermalCameraController(repository: Get.find()));
      }),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 250),
    ),
    // --- Alloop device detail ---
    GetPage(
      name: AlRoutes.deviceDetail,
      page: () {
        final device = RouteUtils.extractDevice(Get.arguments);
        if (device == null) {
          return const Scaffold(
            body: Center(child: Text('Invalid device parameter')),
          );
        }
        return DeviceDetailPage(device: device);
      },
      binding: BindingsBuilder(() {
        final device = RouteUtils.extractDevice(Get.arguments);
        if (device != null && device.type == SmartRingType.alloop) {
          registerAlloopDeviceDetailDependencies(
            device: device,
            autoStart: RouteUtils.extractAutoStart(Get.arguments),
            connectOnOpen: RouteUtils.extractConnectOnOpen(Get.arguments),
          );
        }
      }),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AlRoutes.algorithmVerify,
      page: () {
        final deviceId = RouteUtils.extractDeviceId(Get.arguments);
        if (deviceId == null) {
          return const Scaffold(body: Center(child: Text('Device ID missing')));
        }
        return const AlgorithmVerifyPage();
      },
      binding: BindingsBuilder(() {
        final deviceId = RouteUtils.extractDeviceId(Get.arguments);
        if (deviceId != null) {
          GlobalControllersBinding().dependencies();
          Get.lazyPut(() => AlgorithmVerifyRepository());
          Get.lazyPut(
            () => AlgorithmVerifyController(
              deviceId: deviceId,
              repository: Get.find(),
            ),
          );
        }
      }),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AlRoutes.historySyncDebug,
      page: () {
        final deviceId = RouteUtils.extractDeviceId(Get.arguments);
        if (deviceId == null) {
          return const Scaffold(body: Center(child: Text('Device ID missing')));
        }
        return HistorySyncDebugPage(deviceId: deviceId);
      },
      binding: BindingsBuilder(() {
        final deviceId = RouteUtils.extractDeviceId(Get.arguments);
        if (deviceId != null) {
          GlobalControllersBinding().dependencies();
          Get.lazyPut(() => HistorySyncDebugController(deviceId: deviceId));
        }
      }),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // --- AIZORING routes ---
    GetPage(
      name: AlRoutes.aizoringDeviceDetail,
      page: () {
        final device = RouteUtils.extractDevice(Get.arguments);
        if (device == null) {
          return const Scaffold(
            body: Center(child: Text('Invalid device parameter')),
          );
        }
        return AizoringDeviceDetailPage(device: device);
      },
      binding: BindingsBuilder(() {
        final device = RouteUtils.extractDevice(Get.arguments);
        if (device != null && device.type == SmartRingType.aizoring) {
          Get.lazyPut(() => AizoringDeviceRepository());
          if (!Get.isRegistered<AizoringDeviceDetailController>()) {
            Get.put(
              AizoringDeviceDetailController(
                device: device,
                repository: Get.find(),
              ),
              permanent: true,
            );
          }
        }
      }),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AlRoutes.aizoringMeasurement,
      page: () {
        final deviceId = RouteUtils.extractDeviceId(Get.arguments);
        if (deviceId == null) {
          return const Scaffold(body: Center(child: Text('Device ID missing')));
        }
        return AizoringMeasurementPage(deviceId: deviceId);
      },
      binding: BindingsBuilder(() {
        final deviceId = RouteUtils.extractDeviceId(Get.arguments);
        if (deviceId != null) {
          Get.lazyPut(() => AizoringMeasurementController(deviceId: deviceId));
        }
      }),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AlRoutes.aizoringHealthData,
      page: () {
        final deviceId = RouteUtils.extractDeviceId(Get.arguments);
        if (deviceId == null) {
          return const Scaffold(body: Center(child: Text('Device ID missing')));
        }
        return AizoringHealthDataPage(deviceId: deviceId);
      },
      binding: BindingsBuilder(() {
        final deviceId = RouteUtils.extractDeviceId(Get.arguments);
        if (deviceId != null) {
          Get.lazyPut(() => AizoringHealthDataController(deviceId: deviceId));
        }
      }),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AlRoutes.aizoringSleep,
      page: () {
        final deviceId = RouteUtils.extractDeviceId(Get.arguments);
        if (deviceId == null) {
          return const Scaffold(body: Center(child: Text('Device ID missing')));
        }
        return AizoringSleepPage(deviceId: deviceId);
      },
      binding: BindingsBuilder(() {
        final deviceId = RouteUtils.extractDeviceId(Get.arguments);
        if (deviceId != null) {
          Get.lazyPut(() => AizoringSleepController(deviceId: deviceId));
        }
      }),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    // --- XiaoZhi device detail ---
    GetPage(
      name: AlRoutes.xiaozhiDeviceDetail,
      page: () {
        final device = RouteUtils.extractDevice(Get.arguments);
        if (device == null || device.type != SmartRingType.xiaozhi) {
          return const Scaffold(
            body: Center(child: Text('Invalid XiaoZhi device parameter')),
          );
        }
        return XiaoZhiDeviceDetailPage(device: device);
      },
      binding: BindingsBuilder(() {
        final device = RouteUtils.extractDevice(Get.arguments);
        if (device != null && device.type == SmartRingType.xiaozhi) {
          if (!Get.isRegistered<XiaoZhiBleRepository>()) {
            Get.put(XiaoZhiBleRepository(), permanent: true);
          }
          if (!Get.isRegistered<XiaoZhiDeviceController>()) {
            Get.put(
              XiaoZhiDeviceController(device: device, repository: Get.find()),
              permanent: true,
            );
          }
        }
      }),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    // --- vvewell Robot detail ---
    GetPage(
      name: AlRoutes.robotDeviceDetail,
      page: () {
        final device = RouteUtils.extractDevice(Get.arguments);
        if (device == null || device.type != SmartRingType.robot) {
          return const Scaffold(
            body: Center(child: Text('Invalid Robot device parameter')),
          );
        }
        return RobotDevicePage(device: device);
      },
      binding: BindingsBuilder(() {
        final device = RouteUtils.extractDevice(Get.arguments);
        if (device != null && device.type == SmartRingType.robot) {
          Get.lazyPut(() => RobotBleRepository());
          Get.lazyPut(
            () => RobotDeviceController(device: device, repository: Get.find()),
          );
        }
      }),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    // --- JDY-23 mmWave radar detail ---
    GetPage(
      name: AlRoutes.radarDeviceDetail,
      page: () {
        final device = RouteUtils.extractDevice(Get.arguments);
        if (device == null || device.type != SmartRingType.radar) {
          return const Scaffold(
            body: Center(child: Text('Invalid radar device parameter')),
          );
        }
        return RadarDevicePage(device: device);
      },
      binding: BindingsBuilder(() {
        final device = RouteUtils.extractDevice(Get.arguments);
        if (device != null && device.type == SmartRingType.radar) {
          if (!Get.isRegistered<RadarBleRepository>()) {
            Get.put(RadarBleRepository(), permanent: true);
          }
          if (!Get.isRegistered<RadarDeviceController>()) {
            Get.put(
              RadarDeviceController(device: device, repository: Get.find()),
              permanent: true,
            );
          }
        }
      }),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
  ];
}
