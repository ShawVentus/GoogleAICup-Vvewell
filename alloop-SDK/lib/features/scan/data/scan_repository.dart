import 'dart:async';

import 'package:alloop_blue_lite/alloop_blue_lite.dart';
import 'package:aizoring_blue_lite/aizoring_blue_lite.dart';
import 'package:flutter/foundation.dart';

import '../../../features/aizoring/domain/models/smart_ring_device.dart';
import '../../../features/aizoring/domain/models/smart_ring_type.dart';
import '../../glasses/data/rokid_glasses_repository.dart';
import '../../xiaozhi/data/xiaozhi_ble_repository.dart';
import '../../robot/data/robot_ble_repository.dart';
import 'connected_device_registry.dart';

/// Scan data repository: wraps both Alloop and AIZORING BLE SDKs.
///
/// Merges scan results from both SDKs into a unified [SmartRingDevice] stream.
class ScanRepository {
  final AlloopBlueLite _alloop = AlloopBlueLite.instance;
  final AizoringBlueLite _aizoring = AizoringBlueLite.instance;
  final XiaoZhiBleRepository _xiaozhi = XiaoZhiBleRepository();
  final RobotBleRepository _robot = RobotBleRepository();
  final RokidGlassesRepository _glasses = RokidGlassesRepository();
  final StreamController<SmartRingDevice> _xiaozhiDiscoveryController =
      StreamController<SmartRingDevice>.broadcast();
  final StreamController<SmartRingDevice> _robotDiscoveryController =
      StreamController<SmartRingDevice>.broadcast();
  StreamSubscription<Map<String, dynamic>>? _robotScanSubscription;

  // -- Merged streams --

  /// All discovered devices from both SDKs.
  Stream<SmartRingDevice> get discoveryStream {
    final alloopStream = _alloop.deviceDiscoveredStream.map(
      SmartRingDevice.fromAlloop,
    );
    final aizoringStream = _aizoring.deviceDiscoveredStream.map(
      SmartRingDevice.fromAizoring,
    );
    return _mergeStreams([
      alloopStream,
      aizoringStream,
      _xiaozhiDiscoveryController.stream,
      _robotDiscoveryController.stream,
    ]);
  }

  /// Connected devices from every Bluetooth/CXRLink transport.
  Stream<List<SmartRingDevice>> get connectedDevicesStream {
    final alloop = _alloop.connectedDevicesStream.map(
      (list) => list.map(SmartRingDevice.fromAlloop).toList(),
    );
    return _combineDeviceLists(alloop, ConnectedDeviceRegistry.instance.stream);
  }

  /// Whether either SDK is scanning.
  Stream<bool> get scanningStateStream {
    return _mergeStreams<bool>([
      _alloop.isScanningStream,
      _aizoring.scanStateStream.map((_) => _aizoring.isScanning),
    ]);
  }

  /// Current scanning state.
  bool get isScanning => _alloop.isScanning || _aizoring.isScanning;

  /// Start scanning on both SDKs.
  Future<void> startScan({
    required List<String> filters,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await _robotScanSubscription?.cancel();
    _robotScanSubscription = _robot.events.listen((event) {
      if (event['kind'] != 'discovery') return;
      final name = event['name']?.toString() ?? '';
      final address = event['address']?.toString();
      if (address == null || address.isEmpty) return;
      _robotDiscoveryController.add(
        SmartRingDevice(
          id: address,
          name: name,
          rssi: (event['rssi'] as num?)?.toInt() ?? -127,
          type: SmartRingType.robot,
        ),
      );
    }, onError: (Object error) {
      debugPrint('[ScanRepo] Robot discovery failed: $error');
    });
    // Start the generic robot scan first. Its GATT advertising is independent
    // from the vendor ring SDKs and must not wait for either SDK to initialise.
    _robot.scan().then((devices) {
      for (final device in devices) {
        _robotDiscoveryController.add(device);
      }
    }).catchError((e) {
      debugPrint('[ScanRepo] Robot scan failed: $e');
    });
    final normalizedFilters = filters
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toList();

    final alloopFilter = normalizedFilters.length == 1
        ? normalizedFilters.first
        : null;

    // Start Alloop scan (must not fail)
    await _alloop.startScan(timeout: timeout, nameFilter: alloopFilter);

    // Start AIZORING scan independently — failure must not block the other
    _aizoring.startScan(timeout: timeout).catchError((e) {
      // AIZORING scan may fail if BLE adapter isn't ready; log and continue
      debugPrint('[ScanRepo] AIZORING scan failed: $e');
    });

    // XiaoZhi uses its own Android SDK and only accepts XIAOZHI-* devices.
    // Its scan is independent so a ring SDK failure cannot hide it.
    _xiaozhi
        .scan()
        .then((devices) {
          for (final device in devices) {
            _xiaozhiDiscoveryController.add(device);
          }
        })
        .catchError((e) {
          debugPrint('[ScanRepo] XiaoZhi scan failed: $e');
        });

    // Rokid glasses are connected by the companion application rather than a
    // BLE scan. Refreshing their status makes them appear in the same
    // connected-device section without advertising them as a scan result.
    _glasses.refreshStatus().catchError((e) {
      debugPrint('[ScanRepo] Rokid glasses status failed: $e');
      return <String, dynamic>{};
    });
  }

  /// Stop scanning on both SDKs.
  Future<void> stopScan() async {
    final futures = <Future<void>>[];
    if (_alloop.isScanning) futures.add(_alloop.stopScan());
    if (_aizoring.isScanning) futures.add(_aizoring.stopScan());
    futures.add(_xiaozhi.stopScan());
    futures.add(_robot.stopScan());
    final robotSubscription = _robotScanSubscription;
    _robotScanSubscription = null;
    if (robotSubscription != null) futures.add(robotSubscription.cancel());
    await Future.wait(futures);
  }

  /// Merges multiple streams into one.
  static Stream<T> _mergeStreams<T>(List<Stream<T>> streams) {
    late StreamController<T> controller;
    List<StreamSubscription<T>>? subscriptions;

    controller = StreamController<T>(
      onListen: () {
        subscriptions = streams
            .map((s) => s.listen(controller.add, onError: controller.addError))
            .toList();
      },
      onCancel: () {
        for (final sub in subscriptions ?? []) {
          sub.cancel();
        }
        subscriptions = null;
      },
    );

    return controller.stream;
  }

  static Stream<List<SmartRingDevice>> _combineDeviceLists(
    Stream<List<SmartRingDevice>> first,
    Stream<List<SmartRingDevice>> second,
  ) {
    late StreamController<List<SmartRingDevice>> controller;
    StreamSubscription<List<SmartRingDevice>>? firstSubscription;
    StreamSubscription<List<SmartRingDevice>>? secondSubscription;
    List<SmartRingDevice>? firstValue;
    List<SmartRingDevice>? secondValue;

    void emit() {
      if (firstValue == null || secondValue == null) return;
      final merged = <String, SmartRingDevice>{};
      for (final device in [...firstValue!, ...secondValue!]) {
        merged['${device.type.name}:${device.id}'] = device;
      }
      controller.add(merged.values.toList());
    }

    controller = StreamController<List<SmartRingDevice>>(
      onListen: () {
        firstSubscription = first.listen((value) {
          firstValue = value;
          emit();
        }, onError: controller.addError);
        secondSubscription = second.listen((value) {
          secondValue = value;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await firstSubscription?.cancel();
        await secondSubscription?.cancel();
      },
    );
    return controller.stream;
  }
}
