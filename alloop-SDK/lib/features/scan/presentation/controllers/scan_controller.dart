import 'dart:async';

import 'package:alloop/features/aizoring/domain/models/smart_ring_device.dart';
import 'package:alloop/features/aizoring/domain/models/smart_ring_type.dart';
import 'package:alloop/features/base/controller_base.dart';
import 'package:alloop/features/scan/data/scan_repository.dart';
import 'package:alloop/foundations/ui/al_toast.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Scan controller: manages the scan lifecycle for both Alloop and AIZORING
/// devices, filtering, dedup/sort, and isolation of already-connected devices.
class ScanController extends BaseController {
  static const List<String> defaultFilters = [
    'ring',
    'alloop',
    'aizo',
    'morooy',
    'xiaozhi',
    'jdy-23',
    'vvewell',
  ];

  final ScanRepository _repository;

  final RxBool isScanning = false.obs;
  final RxList<SmartRingDevice> devices = <SmartRingDevice>[].obs;
  final RxList<SmartRingDevice> connectedDevices = <SmartRingDevice>[].obs;
  final RxList<String> filterTexts = <String>[
    'ring',
    'alloop',
    'aizo',
    'morooy',
    'xiaozhi',
    'jdy-23',
    'vvewell',
  ].obs;
  final TextEditingController filterController = TextEditingController(
    text: 'ring alloop aizo morooy xiaozhi jdy-23 vvewell',
  );

  StreamSubscription<SmartRingDevice>? _discoverySubscription;
  StreamSubscription<List<SmartRingDevice>>? _connectedDevicesSubscription;
  StreamSubscription<bool>? _scanningStateSubscription;

  ScanController({required ScanRepository repository})
    : _repository = repository;

  @override
  void onInit() {
    super.onInit();
    _bindConnectedDevices();
    _bindScanningState();
  }

  @override
  void onReady() {
    super.onReady();
    startScan();
  }

  @override
  void onClose() {
    _disposeSubscriptions();
    filterController.dispose();
    super.onClose();
  }

  void updateFilter(String value) {
    final filters = value
        .split(RegExp(r'[,，\s]+'))
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toList();
    filterTexts.value = filters.isEmpty ? [] : filters;
  }

  Future<void> startScan() async {
    await stopScan();
    devices.clear();
    _listenToDiscoveryStream();

    try {
      await _repository.startScan(filters: filterTexts);
      isScanning.value = true;
      logInfo('Scan started with filters: ${filterTexts.join(", ")}');
    } catch (e) {
      isScanning.value = false;
      AlToast.showError('Scan failed: $e');
      logError('Failed to start scan', e);
      await _cancelDiscoverySubscription();
    }
  }

  Future<void> stopScan() async {
    await _cancelDiscoverySubscription();
    try {
      await _repository.stopScan();
    } catch (e) {
      logError('Failed to stop scan', e);
    }
    isScanning.value = _repository.isScanning;
  }

  bool _matchesFilter(SmartRingDevice device) {
    if (filterTexts.isEmpty) return true;
    final deviceName = device.name.toLowerCase();
    return filterTexts.any(
      (filter) => deviceName.contains(filter.toLowerCase()),
    );
  }

  bool _isConnected(SmartRingDevice device) {
    return connectedDevices.any((item) => item.id == device.id);
  }

  /// Whether a device name looks like it belongs to an AIZORING ring.
  static const _aizoringNameHints = ['aizo', 'morooy', 'tm2', 'eiot'];
  static const _alloopNameHints = ['alloop', 'aloop'];

  SmartRingType _guessDeviceType(String name) {
    final lower = name.toLowerCase();
    if (lower.startsWith('xiaozhi')) return SmartRingType.xiaozhi;
    if (lower == 'jdy-23') return SmartRingType.radar;
    if (lower.startsWith('vvewell')) return SmartRingType.robot;
    for (final hint in _aizoringNameHints) {
      if (lower.contains(hint)) return SmartRingType.aizoring;
    }
    for (final hint in _alloopNameHints) {
      if (lower.contains(hint)) return SmartRingType.alloop;
    }
    return SmartRingType.aizoring; // default unknown devices to AIZORING
  }

  void _onDeviceDiscovered(SmartRingDevice device) {
    if (_isConnected(device)) return;
    if (!_matchesFilter(device)) return;

    // The ring SDKs use unfiltered scans and can discover XiaoZhi first.
    // Route every XIAOZHI-* advertisement through the dedicated XiaoZhi
    // Android bridge, no matter which scanner delivered the result.
    final guessed = _guessDeviceType(device.name);
    if (guessed == SmartRingType.xiaozhi ||
        guessed == SmartRingType.radar ||
        guessed == SmartRingType.robot ||
        (device.type == SmartRingType.alloop &&
            guessed == SmartRingType.aizoring)) {
      device = SmartRingDevice(
        id: device.id,
        name: device.name,
        rssi: device.rssi,
        type: guessed,
      );
    }

    // Deduplicate by MAC address. Prefer AIZORING type when both SDKs
    // discover the same device.
    final existingIdx = devices.indexWhere((item) => item.id == device.id);
    if (existingIdx >= 0) {
      devices[existingIdx] = device;
    } else {
      devices.add(device);
    }
    devices.sort((a, b) => b.rssi.compareTo(a.rssi));
  }

  void _listenToDiscoveryStream() {
    _discoverySubscription?.cancel();
    _discoverySubscription = _repository.discoveryStream.listen(
      _onDeviceDiscovered,
    );
  }

  void _bindConnectedDevices() {
    _connectedDevicesSubscription?.cancel();
    _connectedDevicesSubscription = _repository.connectedDevicesStream.listen((
      items,
    ) {
      connectedDevices
        ..clear()
        ..addAll(items);
      _removeConnectedFromDiscovery();
    });
  }

  void _bindScanningState() {
    _scanningStateSubscription?.cancel();
    isScanning.value = _repository.isScanning;
    _scanningStateSubscription = _repository.scanningStateStream.listen((
      value,
    ) {
      isScanning.value = value;
    });
  }

  void _removeConnectedFromDiscovery() {
    if (connectedDevices.isEmpty || devices.isEmpty) return;
    final connectedIds = connectedDevices
        .map((d) => '${d.type.name}:${d.id}')
        .toSet();
    devices.removeWhere(
      (device) => connectedIds.contains('${device.type.name}:${device.id}'),
    );
  }

  Future<void> _cancelDiscoverySubscription() async {
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;
  }

  void _disposeSubscriptions() {
    _discoverySubscription?.cancel();
    _connectedDevicesSubscription?.cancel();
    _scanningStateSubscription?.cancel();
  }
}
