import 'dart:async';

import 'package:alloop/features/aizoring/domain/models/smart_ring_device.dart';
import 'package:alloop/features/aizoring/domain/models/smart_ring_type.dart';
import 'package:alloop/features/common/data/repositories/common_repository.dart';
import 'package:alloop/features/scan/data/connected_device_registry.dart';
import 'package:alloop/features/common/presentation/controllers/device_status_controller.dart';
import 'package:alloop/features/device_detail/data/device_detail_repository.dart';
import 'package:alloop/features/device_detail/domain/alloop_ring_dashboard_models.dart';
import 'package:alloop/features/device_detail/presentation/controllers/device_detail_controller.dart';
import 'package:alloop/features/device_detail/presentation/pages/device_detail_page.dart';
import 'package:alloop/features/main/device_center_page.dart';
import 'package:alloop/foundations/navigation/al_routes.dart';
import 'package:alloop/foundations/ui/vvewell_theme.dart';
import 'package:alloop_blue_lite/alloop_blue_lite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const databaseChannel = MethodChannel('alloop/local_health_database');
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  setUp(ConnectedDeviceRegistry.instance.resetForTest);
  tearDown(ConnectedDeviceRegistry.instance.resetForTest);

  testWidgets('device center keeps add-device options after Alloop connects', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: vvewellTheme(),
        home: DeviceCenterPage(
          connectedDevicesStream: Stream.value([
            const LiteDevice(
              id: 'AA:BB:CC:DD:EE:01',
              name: 'Alloop Ring 01',
              rssi: -48,
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('connected-alloop-ring-card')), findsOneWidget);
    expect(
      find.byKey(const Key('device-center-one-tap-measurement')),
      findsOneWidget,
    );
    expect(find.text('连接其他设备'), findsOneWidget);
    expect(find.text('扫描并添加设备'), findsOneWidget);
    expect(find.text('JDY-23 毫米波雷达'), findsOneWidget);
    expect(find.text('Device filter'), findsNothing);
  });

  testWidgets('hardware shop includes the infrared device and cart actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: vvewellTheme(),
        home: DeviceCenterPage(
          connectedDevicesStream: Stream.value(const <LiteDevice>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('硬件购买'));
    await tester.pump();

    expect(find.text('红外健康检测仪'), findsOneWidget);
    expect(find.text('健康小助手'), findsOneWidget);
    expect(find.byTooltip('加入购物车'), findsNWidgets(4));
    await tester.tap(find.byTooltip('加入购物车').first);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  test('connected hardware registry keeps independent device transports', () {
    final registry = ConnectedDeviceRegistry.instance;
    const ring = SmartRingDevice(
      id: 'AA:BB:CC:DD:EE:01',
      name: 'Alloop Ring 01',
      rssi: -48,
      type: SmartRingType.alloop,
    );
    const radar = SmartRingDevice(
      id: 'AA:BB:CC:DD:EE:02',
      name: 'JDY-23',
      rssi: -55,
      type: SmartRingType.radar,
    );

    registry.markConnected(ring);
    registry.markConnected(radar);
    expect(registry.devices, containsAll(<SmartRingDevice>[ring, radar]));

    registry.markDisconnected(SmartRingType.radar, deviceId: radar.id);
    expect(registry.devices, contains(ring));
    expect(registry.devices, isNot(contains(radar)));
  });

  test('Alloop detail binding registers its data source interface', () {
    Get.testMode = true;
    addTearDown(Get.reset);

    registerAlloopDeviceDetailDependencies(
      device: const SmartRingDevice(
        id: 'AA:BB:CC:DD:EE:01',
        name: 'Alloop Ring 01',
        rssi: -48,
        type: SmartRingType.alloop,
      ),
      autoStart: false,
      connectOnOpen: true,
    );

    expect(Get.find<DeviceDetailDataSource>(), isA<DeviceDetailRepository>());
    expect(Get.isRegistered<DeviceDetailController>(), isTrue);
  });

  group('connected Alloop Ring dashboard', () {
    late _FakeDeviceDetailDataSource repository;
    late DeviceStatusController statusController;
    late DeviceDetailController controller;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(databaseChannel, (call) async {
            return switch (call.method) {
              'saveVitalReading' ||
              'saveRingMeasurementResult' ||
              'saveRingDailyLog' => 1,
              'loadVitalReadings' || 'loadRingDailyLogs' => <Object?>[],
              _ => null,
            };
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(toastChannel, (_) async => true);
      Get.testMode = true;
      repository = _FakeDeviceDetailDataSource();
      statusController = DeviceStatusController(repository: CommonRepository())
        ..isConnected.value = true
        ..currentStatus.value = const LiteDeviceStatus(
          batteryPercent: 82,
          deviceState: 1,
          hasMeasurementHistory: true,
          hasActivityHistory: true,
          hasSportHistory: true,
        );
      Get.put<DeviceStatusController>(statusController);
      controller = DeviceDetailController(
        repository: repository,
        initialName: 'Alloop Ring 01',
        measurementDuration: const Duration(minutes: 1),
      );
      Get.put<DeviceDetailController>(controller);
    });

    tearDown(() async {
      await repository.dispose();
      Get.reset();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(databaseChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(toastChannel, null);
    });

    Widget app() => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, child) => GetMaterialApp(
        theme: vvewellTheme(),
        home: const DeviceDetailPage(
          device: SmartRingDevice(
            id: 'AA:BB:CC:DD:EE:01',
            name: 'Alloop Ring 01',
            rssi: -48,
            type: SmartRingType.alloop,
          ),
        ),
      ),
    );

    test('one tap reads metrics, waves, and history temperature', () async {
      await controller.startOneTapMeasurement();
      expect(repository.startCalls, 1);
      expect(
        controller.measurementPhase.value,
        AlloopMeasurementPhase.measuring,
      );

      repository.spo2Events.add(
        const Spo2Result(spo2: 98, hr: 72, success: true, isVerified: false),
      );
      repository.ppgEvents.add(
        const PpgWave(
          packCount: 1,
          captureTime: 2,
          samples: [
            PpgSample(ledG: 110, ledGAmb: 10, ledRedAmb: 12, ledIr: 95),
            PpgSample(ledG: 112, ledGAmb: 11, ledRedAmb: 13, ledIr: 97),
          ],
        ),
      );
      repository.accEvents.add(
        const AccWave(
          packCount: 1,
          captureTime: 1,
          samples: [AccSample3(x: 2, y: -1, z: 8)],
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.displaySpo2.value, 98);
      expect(controller.displayHeartRate.value, 72);
      expect(controller.ppgLedG, isNotEmpty);
      expect(controller.accX, isNotEmpty);

      await controller.finishOneTapMeasurement();
      expect(repository.stopCalls, 1);
      expect(repository.syncCalls, 1);
      expect(controller.displayTemperature.value, closeTo(36.5, .01));
      expect(
        controller.measurementPhase.value,
        AlloopMeasurementPhase.completed,
      );
      expect(controller.measurementProgress.value, 1);
    });

    testWidgets('connect flow reaches connected state after the SDK callback', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pump();
      statusController.isConnected.value = false;

      await controller.connect();
      expect(repository.connectCalls, 1);
      expect(controller.isConnecting.value, isTrue);

      repository.connectionEvents.add(
        const LiteConnectionState(state: LiteConnectionStateValue.connected),
      );
      await tester.pump();

      expect(statusController.isConnected.value, isTrue);
      expect(controller.isConnecting.value, isFalse);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('320px dashboard reaches lifecycle actions without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app());
      await tester.pump();

      await tester.scrollUntilVisible(
        find.byKey(const Key('clear-alloop-ring-data')),
        360,
        scrollable: find.descendant(
          of: find.byKey(const Key('alloop-ring-dashboard-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('clear-alloop-ring-data')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Clear local data?'), findsOneWidget);
      expect(find.textContaining('无法撤销'), findsOneWidget);
    });
  });
}

class _FakeDeviceDetailDataSource implements DeviceDetailDataSource {
  final connectionEvents = StreamController<LiteConnectionState>.broadcast();
  final spo2Events = StreamController<Spo2Result>.broadcast();
  final ppgEvents = StreamController<PpgWave>.broadcast();
  final accEvents = StreamController<AccWave>.broadcast();

  int startCalls = 0;
  int stopCalls = 0;
  int syncCalls = 0;
  int connectCalls = 0;

  @override
  String get deviceId => 'AA:BB:CC:DD:EE:01';

  @override
  Future<void> connect() async => connectCalls++;

  @override
  Future<void> disconnect() async {}

  @override
  Stream<LiteConnectionState> get connectionStateStream =>
      connectionEvents.stream;

  @override
  Future<LiteDeviceInfo> getDeviceInfo() async => const LiteDeviceInfo(
    firmwareVersion: '1.4.2',
    batteryPercent: 82,
    deviceState: 1,
  );

  @override
  Future<void> startAllMeasurements() async => startCalls++;

  @override
  Future<void> stopMeasurement() async => stopCalls++;

  @override
  Stream<Spo2Result> get spo2ResultStream => spo2Events.stream;

  @override
  Stream<PpgWave> get ppgWaveStream => ppgEvents.stream;

  @override
  Stream<AccWave> get accWaveStream => accEvents.stream;

  @override
  Stream<HistorySyncEvent> syncHistory() {
    syncCalls++;
    return Stream.fromIterable([
      HistoryRecordReceived(
        type: 'activity',
        index: 0,
        total: 1,
        record: ActivityRecord(
          unixSec: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
          batteryPercent: 82,
          steps: 5600,
          activeSeconds: 2400,
          temperaturesC: const [36.4, 36.6],
        ),
      ),
      const HistoryAllCompleted(
        counts: {'measurement': 0, 'activity': 1, 'sport': 0},
      ),
    ]);
  }

  Future<void> dispose() async {
    await connectionEvents.close();
    await spo2Events.close();
    await ppgEvents.close();
    await accEvents.close();
  }
}
