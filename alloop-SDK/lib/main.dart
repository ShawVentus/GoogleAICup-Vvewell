import 'dart:async';

import 'package:alloop_blue_lite/alloop_blue_lite.dart';
import 'package:aizoring_blue_lite/aizoring_blue_lite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'foundations/error/al_error_handler.dart';
import 'foundations/log/al_logger.dart';
import 'core/database/local_health_database.dart';
import 'features/cloud_sync/data/cloud_measurement_sync_service.dart';
import 'features/health_analysis/data/phone_analysis_coordinator.dart';
import 'foundations/localization/app_localization.dart';
// Import route configuration
import 'foundations/navigation/al_routes.dart';
import 'foundations/ui/vvewell_theme.dart';
import 'features/xiaozhi/services/xiaozhi_proactive_voice_service.dart';

void main() async {
  // Use a Zone to capture all asynchronous errors
  runZonedGuarded(() async {
    // Ensure Flutter bindings are initialized (must be inside the Zone)
    WidgetsFlutterBinding.ensureInitialized();
    Get.put(AppLanguageController(), permanent: true);

    // Initialize the logging system
    await AlLogger.initialize();

    // Initialize the global error handler
    AlErrorHandler.initialize();

    try {
      // DIRTY_DEMO_EMBEDDED_CREDENTIALS_REMOVE_BEFORE_RELEASE
      await CloudMeasurementSyncService.instance.initializeForEmbeddedDemo();
      AlLogger.info(
        CloudMeasurementSyncService.instance.isConfigured
            ? 'Cloud measurement sync configured'
            : 'Cloud measurement sync is not configured',
        tag: 'INIT',
      );
    } catch (e, stackTrace) {
      AlLogger.error(
        'Failed to initialize cloud measurement sync: $e',
        tag: 'INIT',
        error: e,
        stackTrace: stackTrace,
      );
    }

    try {
      await LocalHealthDatabase.instance.initialize();
      AlLogger.info(
        'Local health database initialized successfully',
        tag: 'INIT',
      );
      await LocalHealthDatabase.instance.getDebugStatus();
      PhoneAnalysisCoordinator.instance.install(
        memberIdProvider: () =>
            CloudMeasurementSyncService.instance.configuredMemberId ??
            LocalHealthDatabase.defaultUserId,
      );
      final existingRecommendation = await LocalHealthDatabase.instance
          .loadLatestRecommendation();
      if (existingRecommendation.isEmpty) {
        unawaited(PhoneAnalysisCoordinator.instance.schedule());
      }
    } catch (e, stackTrace) {
      AlLogger.error(
        'Failed to initialize local health database: $e',
        tag: 'INIT',
        error: e,
        stackTrace: stackTrace,
      );
    }

    // Start before any XiaoZhi connection is opened so health readings and
    // scheduled greetings can use the existing BLE session as soon as it is ready.
    await XiaoZhiProactiveVoiceService.instance.initialize();

    // Initialize the Alloop Blue Lite SDK
    try {
      await AlloopBlueLite.instance.initialize();
      AlLogger.info('AlloopBlueLite initialized successfully', tag: 'INIT');
    } catch (e) {
      AlLogger.error('Failed to initialize AlloopBlueLite: $e', tag: 'INIT');
    }

    // Initialize the AIZORING Blue Lite SDK
    try {
      await AizoringBlueLite.instance.initialize();
      AlLogger.info('AizoringBlueLite initialized successfully', tag: 'INIT');
    } catch (e) {
      AlLogger.error('Failed to initialize AizoringBlueLite: $e', tag: 'INIT');
    }

    // Enable screen wakelock to keep screen on while app is running
    await WakelockPlus.enable();
    AlLogger.info('Screen wakelock enabled', tag: 'INIT');

    runApp(AlloopApp());
  }, AlErrorHandler.onZoneError);
}

/// Root widget of the application.
class AlloopApp extends StatefulWidget {
  const AlloopApp({super.key});

  @override
  State<StatefulWidget> createState() => _AlloopAppState();
}

class _AlloopAppState extends State<AlloopApp> {
  late String _initialRoute;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize routing
    _initializeRoute();
  }

  Future<void> _initializeRoute() async {
    // Only resolve the route on the first initialization
    if (!_initialized) {
      _initialRoute = await _getInitialRoute();
      _initialized = true;
      // Rebuild after initialization
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<String> _getInitialRoute() async {
    try {
      // Initialize the core logging system (required at app startup)
      await AlLogger.initialize();
      AlLogger.info('SDK initialization completed', tag: 'INIT');
    } catch (e, stackTrace) {
      AlLogger.error(
        'Error during initialization',
        tag: 'INIT',
        error: e,
        stackTrace: stackTrace,
      );
    }
    return AlRoutes.splash;
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading screen until initialization completes
    if (!_initialized) {
      return MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // Use ScreenUtil for screen adaptation
    return ScreenUtilInit(
      designSize: const Size(
        390,
        844,
      ), // iPhone 14 Pro size as the design baseline
      minTextAdapt: true, // Adaptive font sizing
      splitScreenMode: true, // Support split-screen mode
      builder: (context, child) {
        return Obx(
          () => GetMaterialApp(
            // Basic app information
            title: 'vvewell',
            debugShowCheckedModeBanner: false,
            translations: VvewellTranslations(),
            locale: Get.find<AppLanguageController>().currentLocale.value,
            fallbackLocale: const Locale('zh', 'CN'),

            // Theme configuration
            theme: vvewellTheme(),

            // Route configuration - determined dynamically based on user state
            initialRoute: _initialRoute,
            getPages: AlPages.pages,

            // Default transition animation
            defaultTransition: Transition.rightToLeft,
            transitionDuration: const Duration(milliseconds: 300),

            // Enable logging (debug mode only)
            enableLog: true,
            logWriterCallback: (String text, {bool isError = false}) {
              if (isError) {
                debugPrint('GetX Error: $text');
              } else {
                debugPrint('GetX: $text');
              }
            },

            // Error handling
            unknownRoute: GetPage(
              name: '/unknown',
              page: () => const Scaffold(
                body: Center(
                  child: Text('Page Not Found', style: TextStyle(fontSize: 24)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
