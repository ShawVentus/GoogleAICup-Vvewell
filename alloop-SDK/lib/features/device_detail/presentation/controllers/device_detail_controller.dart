import 'dart:async';
import 'dart:math' as math;

import 'package:alloop_blue_lite/alloop_blue_lite.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

import '../../../../core/database/local_health_database.dart';
import '../../../../core/utils/al_file_utils.dart';
import '../../../../core/utils/csv_file_writer.dart';
import '../../../../foundations/navigation/al_routes.dart';
import '../../../../foundations/ui/al_toast.dart';
import '../../../../widgets/chart/realtime_line_chart.dart';
import '../../../base/controller_base.dart';
import '../../../common/presentation/controllers/device_status_controller.dart';
import '../../data/device_detail_repository.dart';
import '../../domain/alloop_ring_dashboard_models.dart';

/// Owns the complete Alloop Ring single-page lifecycle: connection, live SDK
/// measurement, waveforms, history/temperature sync, trends, export, and local
/// device management.
class DeviceDetailController extends BaseController {
  DeviceDetailController({
    required DeviceDetailDataSource repository,
    this.initialName = '',
    this.initialAutoStart = false,
    this.initialConnectOnOpen = false,
    this.measurementDuration = const Duration(seconds: 30),
  }) : _repository = repository;

  static const double chartWindowSeconds = 8;
  static const double _ppgSampleRateHz = 100;
  static const double _accSampleRateHz = 25;
  static const int _maxVisibleWavePoints = 900;

  final DeviceDetailDataSource _repository;
  final String initialName;
  final bool initialAutoStart;
  final bool initialConnectOnOpen;
  final Duration measurementDuration;

  final RxnDouble latestTemperatureC = RxnDouble();
  final Rxn<DateTime> latestTemperatureAt = Rxn<DateTime>();
  final RxBool isLoadingTemperature = false.obs;

  DeviceStatusController get _deviceStatusController =>
      Get.find<DeviceStatusController>();

  String get deviceId => _repository.deviceId;
  RxBool get isConnected => _deviceStatusController.isConnected;

  final RxBool isConnecting = false.obs;
  final Rxn<LiteDeviceInfo> deviceInfo = Rxn<LiteDeviceInfo>();
  final RxString deviceName = ''.obs;

  final Rx<AlloopMeasurementPhase> measurementPhase =
      AlloopMeasurementPhase.idle.obs;
  final RxDouble measurementProgress = 0.0.obs;
  final RxString measurementStatus = '设备已就绪，可以开始一键检测'.obs;
  final RxnInt displaySpo2 = RxnInt();
  final RxnInt displayHeartRate = RxnInt();
  final RxnDouble displayTemperature = RxnDouble();
  final Rxn<DateTime> latestMeasuredAt = Rxn<DateTime>();
  final RxBool isExporting = false.obs;

  final RxList<DataPoint> ppgLedG = <DataPoint>[].obs;
  final RxList<DataPoint> ppgLedGAmb = <DataPoint>[].obs;
  final RxList<DataPoint> ppgLedRedAmb = <DataPoint>[].obs;
  final RxList<DataPoint> ppgLedIr = <DataPoint>[].obs;
  final RxList<DataPoint> accX = <DataPoint>[].obs;
  final RxList<DataPoint> accY = <DataPoint>[].obs;
  final RxList<DataPoint> accZ = <DataPoint>[].obs;

  final Rx<AlloopTrendRange> trendRange = AlloopTrendRange.day.obs;
  final RxList<AlloopTrendPoint> trendPoints = <AlloopTrendPoint>[].obs;
  final RxBool isLoadingTrends = false.obs;

  StreamSubscription<LiteConnectionState>? _connectionSub;
  StreamSubscription<Spo2Result>? _resultSub;
  StreamSubscription<PpgWave>? _ppgSub;
  StreamSubscription<AccWave>? _accSub;
  Timer? _measurementTimer;
  Timer? _progressTimer;
  Timer? _connectTimeoutTimer;
  Worker? _autoStartWorker;
  DateTime? _measurementStartedAt;
  bool _awaitingConnectResult = false;
  bool _autoStartHandled = false;
  int _ppgReceivedSamples = 0;
  int _accReceivedSamples = 0;

  static const Duration _connectTimeout = Duration(seconds: 25);

  @override
  void onInit() {
    super.onInit();
    if (initialName.isNotEmpty) deviceName.value = initialName;
    _bindConnectionState();
    if (initialAutoStart) {
      _autoStartWorker = ever<bool>(isConnected, (connected) {
        if (connected) _startAutomaticallyOnce();
      });
    }
    unawaited(refreshLatestTemperature());
  }

  @override
  void onReady() {
    super.onReady();
    if (isConnected.value) {
      unawaited(_refreshConnectedData());
      _startAutomaticallyOnce();
    } else if (initialConnectOnOpen) {
      unawaited(connect());
    }
  }

  @override
  void onClose() {
    _cancelConnectTimeoutTimer();
    _measurementTimer?.cancel();
    _progressTimer?.cancel();
    _connectionSub?.cancel();
    _autoStartWorker?.dispose();
    unawaited(_cancelMeasurementSubscriptions());
    super.onClose();
  }

  Future<void> connect() async {
    if (isConnecting.value || isConnected.value) return;
    isConnecting.value = true;
    _awaitingConnectResult = true;
    _startConnectTimeoutTimer();
    try {
      AlToast.showInfo('正在连接 Alloop Ring…');
      await _repository.connect();
    } catch (error) {
      _awaitingConnectResult = false;
      _cancelConnectTimeoutTimer();
      isConnecting.value = false;
      AlToast.showError('连接失败：${_describeError(error)}');
      logError('Failed to connect', error);
    }
  }

  /// Actively disconnect from the device and clean up state.
  Future<void> disconnect() async {
    try {
      await _repository.disconnect();
    } catch (e) {
      AlToast.showError('Failed to disconnect: ${_describeError(e)}');
      logError('Failed to disconnect', e);
    } finally {
      await _deviceStatusController.stopMonitoring();
      _handleDisconnected();
    }
  }

  Future<void> startOneTapMeasurement() async {
    if (!_ensureConnected() || !measurementPhase.value.canStart) return;
    _resetMeasurementData();
    _measurementStartedAt = DateTime.now().toUtc();
    latestMeasuredAt.value = _measurementStartedAt;
    measurementPhase.value = AlloopMeasurementPhase.measuring;
    measurementStatus.value = '正在读取血氧、心率、PPG 与运动波形';
    measurementProgress.value = 0.04;
    _subscribeToMeasurementStreams();

    try {
      await _repository.startAllMeasurements();
      _startMeasurementTimers();
      AlToast.showSuccess('Alloop SDK 一键检测已开始');
    } catch (error) {
      await _cancelMeasurementSubscriptions();
      measurementPhase.value = AlloopMeasurementPhase.error;
      measurementStatus.value = '检测启动失败：${_describeError(error)}';
      AlToast.showError(measurementStatus.value);
      logError('Failed to start Alloop measurement', error);
    }
  }

  Future<void> finishOneTapMeasurement() async {
    if (measurementPhase.value != AlloopMeasurementPhase.measuring) return;
    await _stopLiveMeasurement(sendStopCommand: true);
    await _syncHistoryAndComplete();
  }

  Future<void> syncHistoryNow() async {
    if (!_ensureConnected() || measurementPhase.value.isBusy) return;
    measurementProgress.value = 0.72;
    await _syncHistoryAndComplete(manual: true);
  }

  Future<void> setTrendRange(AlloopTrendRange range) async {
    if (trendRange.value == range && trendPoints.isNotEmpty) return;
    trendRange.value = range;
    await loadTrends();
  }

  Future<void> loadTrends() async {
    isLoadingTrends.value = true;
    final end = DateTime.now().toUtc().add(const Duration(minutes: 1));
    final start = end.subtract(trendRange.value.duration);
    try {
      final results = await Future.wait([
        LocalHealthDatabase.instance.loadVitalReadings(
          source: 'alloop_ring',
          deviceId: deviceId,
          start: start,
          end: end,
          limit: 1600,
        ),
        LocalHealthDatabase.instance.loadRingDailyLogs(
          deviceId: deviceId,
          start: start,
          end: end,
          limit: 1600,
        ),
      ]);
      final points = <AlloopTrendPoint>[];
      for (final row in results[0]) {
        final timestamp = _dateFromDatabase(row['recorded_at']);
        if (timestamp == null) continue;
        points.add(
          AlloopTrendPoint(
            recordedAt: timestamp,
            heartRate: _finiteDouble(row['heart_rate']),
            spo2: _finiteDouble(row['spo2']),
            temperature: _finiteDouble(row['temperature']),
          ),
        );
      }
      for (final row in results[1]) {
        final timestamp = _dateFromDatabase(row['recorded_at']);
        final temperature = _averageTemperatures(
          '${row['temperatures_c'] ?? ''}',
        );
        if (timestamp == null || temperature == null) continue;
        points.add(
          AlloopTrendPoint(recordedAt: timestamp, temperature: temperature),
        );
      }
      points.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
      trendPoints.assignAll(points);
      _restoreLatestValues(points);
    } catch (error) {
      logError('Failed to load Alloop trends', error);
    } finally {
      isLoadingTrends.value = false;
    }
  }

  Future<void> clearLocalData() async {
    if (measurementPhase.value.isBusy) return;
    try {
      final counts = await LocalHealthDatabase.instance.clearAlloopDeviceData(
        deviceId: deviceId,
      );
      _resetMeasurementData();
      trendPoints.clear();
      displayTemperature.value = null;
      latestMeasuredAt.value = null;
      final total = counts.values.fold<int>(0, (sum, value) => sum + value);
      AlToast.showSuccess('已清除 $total 条本机戒指数据');
    } catch (error) {
      AlToast.showError('清除失败：${_describeError(error)}');
    }
  }

  Future<void> unbindRing() async {
    if (measurementPhase.value.isBusy) {
      await _stopLiveMeasurement(sendStopCommand: isConnected.value);
    }
    await disconnect();
    try {
      await LocalHealthDatabase.instance.forgetAlloopDevice(deviceId: deviceId);
      AlToast.showSuccess('已解除 Alloop Ring 的应用内绑定');
      if (Get.key.currentState?.canPop() ?? false) Get.back<void>();
    } catch (error) {
      AlToast.showError('解绑失败：${_describeError(error)}');
    }
  }

  Future<void> exportWaveData() async {
    if (isExporting.value) return;
    if (ppgLedG.isEmpty && accX.isEmpty) {
      AlToast.showInfo('当前没有可导出的波形');
      return;
    }
    isExporting.value = true;
    try {
      final directory = await AlFileUtils.getUserAccessibleDirectory();
      if (directory == null) throw StateError('无法访问导出目录');
      final folder = path.join(directory.path, 'alloop_ring');
      final stamp = DateFormat(
        'yyyy-MM-dd_HH-mm-ss',
      ).format(_measurementStartedAt?.toLocal() ?? DateTime.now());
      var saved = 0;
      if (ppgLedG.isNotEmpty) {
        final writer = CsvFileWriter(
          filePath: path.join(folder, 'alloop_${stamp}_PPG.csv'),
          headers: ['elapsedSeconds', 'ledG', 'ledGAmb', 'ledRedAmb', 'ledIr'],
        );
        await writer.initialize();
        final length = [
          ppgLedG.length,
          ppgLedGAmb.length,
          ppgLedRedAmb.length,
          ppgLedIr.length,
        ].reduce(math.min);
        for (var index = 0; index < length; index++) {
          writer.writeRow([
            ppgLedG[index].x.toStringAsFixed(3),
            ppgLedG[index].y,
            ppgLedGAmb[index].y,
            ppgLedRedAmb[index].y,
            ppgLedIr[index].y,
          ]);
        }
        await writer.close();
        saved++;
      }
      if (accX.isNotEmpty) {
        final writer = CsvFileWriter(
          filePath: path.join(folder, 'alloop_${stamp}_ACC.csv'),
          headers: ['elapsedSeconds', 'x', 'y', 'z'],
        );
        await writer.initialize();
        final length = [accX.length, accY.length, accZ.length].reduce(math.min);
        for (var index = 0; index < length; index++) {
          writer.writeRow([
            accX[index].x.toStringAsFixed(3),
            accX[index].y,
            accY[index].y,
            accZ[index].y,
          ]);
        }
        await writer.close();
        saved++;
      }
      AlToast.showSuccess('已导出 $saved 个波形文件至 $folder');
    } catch (error) {
      AlToast.showError('导出失败：${_describeError(error)}');
    } finally {
      isExporting.value = false;
    }
  }

  /// Navigate to the SpO2 verification entry.
  void goToAlgorithmDebug() {
    if (!_ensureConnected()) return;
    logInfo('Navigating to Algorithm Verify page for device: $deviceId');
    Get.toNamed(AlRoutes.algorithmVerify, arguments: {'deviceId': deviceId});
  }

  /// Navigate to the history data sync debug entry.
  Future<void> goToHistorySyncDebug() async {
    if (!_ensureConnected()) return;
    logInfo('Navigating to History Sync Debug page for device: $deviceId');
    await Get.toNamed(
      AlRoutes.historySyncDebug,
      arguments: {'deviceId': deviceId},
    );
    await refreshLatestTemperature();
  }

  /// Refreshes the cached temperature shown on the ring detail page.
  Future<void> refreshLatestTemperature() async {
    if (isLoadingTemperature.value) return;
    isLoadingTemperature.value = true;
    try {
      final reading = await LocalHealthDatabase.instance
          .loadLatestRingTemperature(deviceId: deviceId);
      latestTemperatureC.value = reading?.temperatureC;
      latestTemperatureAt.value = reading?.recordedAt;
    } catch (error) {
      logError('Failed to load latest ring temperature', error);
    } finally {
      isLoadingTemperature.value = false;
    }
  }

  void _startAutomaticallyOnce() {
    if (!initialAutoStart || _autoStartHandled || !isConnected.value) return;
    _autoStartHandled = true;
    unawaited(startOneTapMeasurement());
  }

  void _bindConnectionState() {
    _connectionSub?.cancel();
    _connectionSub = _repository.connectionStateStream.listen((state) {
      // The first connection event received while awaiting a connect()
      // result resolves the "connecting" phase (cancels the fallback timer).
      // This applies whether the event is 'connected' or 'disconnected';
      // 'connecting' itself does not resolve the phase.
      final wasAwaitingConnect = _awaitingConnectResult;
      if (wasAwaitingConnect && state.state != LiteConnectionStateValue.connecting) {
        _awaitingConnectResult = false;
        _cancelConnectTimeoutTimer();
      }

      switch (state.state) {
        case LiteConnectionStateValue.connected:
          _handleConnected();
        case LiteConnectionStateValue.connecting:
          break;
        case LiteConnectionStateValue.disconnected:
          if (wasAwaitingConnect) {
            // Connect attempt failed before ever reaching 'connected':
            // surface a distinct "connect failed" toast (with errorCode when
            // available) instead of the generic "device disconnected" toast.
            isConnecting.value = false;
            deviceInfo.value = null;
            final suffix = state.errorCode != null ? ': ${state.errorCode}' : '';
            AlToast.showError('Connection failed$suffix');
            logError('Connect failed while connecting: $deviceId, errorCode=${state.errorCode}');
          } else {
            _handleDisconnected(showToast: true, errorCode: state.errorCode);
          }
      }
    });
  }

  Future<void> _handleConnected() async {
    logInfo('Device connected: $deviceId');
    isConnecting.value = false;
    // The SDK callback is authoritative. Reflect it immediately so the page
    // cannot remain in the disconnected state while status subscriptions and
    // persisted device metadata are being initialized asynchronously.
    _deviceStatusController.isConnected.value = true;
    await _deviceStatusController.switchToDevice(deviceId);
    await _fetchDeviceInfo(silent: true);
    deviceName.value = deviceName.value.isEmpty ? deviceId : deviceName.value;
  }

  Future<void> _refreshConnectedData() async {
    await _fetchDeviceInfo(silent: true);
    await loadTrends();
    deviceName.value = deviceName.value.isEmpty ? deviceId : deviceName.value;
  }

  void _handleDisconnected({bool showToast = false, String? errorCode}) {
    logInfo('Device disconnected: $deviceId, errorCode=$errorCode');
    isConnecting.value = false;
    _awaitingConnectResult = false;
    _cancelConnectTimeoutTimer();
    deviceInfo.value = null;
    unawaited(
      LocalHealthDatabase.instance.upsertDevice(
        deviceId: deviceId,
        name: initialName.isNotEmpty ? initialName : deviceId,
        type: 'alloop_ring',
        connected: false,
      ),
    );
    if (showToast) {
      final suffix = errorCode != null ? ': $errorCode' : '';
      AlToast.showInfo('Device disconnected$suffix');
    }
  }

  void _subscribeToMeasurementStreams() {
    _resultSub = _repository.spo2ResultStream.listen(
      _handleResult,
      onError: (Object error) => logError('SpO2 stream error', error),
    );
    _ppgSub = _repository.ppgWaveStream.listen(
      _handlePpgWave,
      onError: (Object error) => logError('PPG stream error', error),
    );
    _accSub = _repository.accWaveStream.listen(
      _handleAccWave,
      onError: (Object error) => logError('ACC stream error', error),
    );
  }

  void _handleResult(Spo2Result result) {
    final spo2 = result.spo2;
    final heartRate = result.hr;
    if (spo2 != null && spo2 >= 70 && spo2 <= 100) {
      displaySpo2.value = spo2;
    }
    if (heartRate != null && heartRate >= 30 && heartRate <= 220) {
      displayHeartRate.value = heartRate;
    }
    final timestamp = result.measuredAt?.toUtc() ?? DateTime.now().toUtc();
    latestMeasuredAt.value = timestamp;
    unawaited(_persistMeasurementResult(result, timestamp));
  }

  void _handlePpgWave(PpgWave wave) {
    if (wave.samples.isEmpty) return;
    final green = <DataPoint>[];
    final ambient = <DataPoint>[];
    final red = <DataPoint>[];
    final infrared = <DataPoint>[];
    for (var index = 0; index < wave.samples.length; index++) {
      final x = (_ppgReceivedSamples + index) / _ppgSampleRateHz;
      final sample = wave.samples[index];
      green.add(DataPoint(x, sample.ledG.toDouble()));
      ambient.add(DataPoint(x, sample.ledGAmb.toDouble()));
      red.add(DataPoint(x, sample.ledRedAmb.toDouble()));
      infrared.add(DataPoint(x, sample.ledIr.toDouble()));
    }
    _ppgReceivedSamples += wave.samples.length;
    _appendWavePoints(ppgLedG, green);
    _appendWavePoints(ppgLedGAmb, ambient);
    _appendWavePoints(ppgLedRedAmb, red);
    _appendWavePoints(ppgLedIr, infrared);
  }

  void _handleAccWave(AccWave wave) {
    if (wave.samples.isEmpty) return;
    final xPoints = <DataPoint>[];
    final yPoints = <DataPoint>[];
    final zPoints = <DataPoint>[];
    for (var index = 0; index < wave.samples.length; index++) {
      final elapsed = (_accReceivedSamples + index) / _accSampleRateHz;
      final sample = wave.samples[index];
      xPoints.add(DataPoint(elapsed, sample.x.toDouble()));
      yPoints.add(DataPoint(elapsed, sample.y.toDouble()));
      zPoints.add(DataPoint(elapsed, sample.z.toDouble()));
    }
    _accReceivedSamples += wave.samples.length;
    _appendWavePoints(accX, xPoints);
    _appendWavePoints(accY, yPoints);
    _appendWavePoints(accZ, zPoints);
  }

  void _appendWavePoints(RxList<DataPoint> target, List<DataPoint> additions) {
    target.addAll(additions);
    if (target.length > _maxVisibleWavePoints) {
      target.removeRange(0, target.length - _maxVisibleWavePoints);
    }
  }

  void _startMeasurementTimers() {
    _measurementTimer?.cancel();
    _progressTimer?.cancel();
    _measurementTimer = Timer(measurementDuration, () {
      unawaited(finishOneTapMeasurement());
    });
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final started = _measurementStartedAt;
      if (started == null ||
          measurementPhase.value != AlloopMeasurementPhase.measuring) {
        return;
      }
      final elapsed = DateTime.now().toUtc().difference(started).inMilliseconds;
      final fraction = elapsed / measurementDuration.inMilliseconds;
      measurementProgress.value = (0.04 + fraction * 0.64).clamp(0.04, 0.68);
    });
  }

  Future<void> _stopLiveMeasurement({required bool sendStopCommand}) async {
    _measurementTimer?.cancel();
    _progressTimer?.cancel();
    measurementPhase.value = AlloopMeasurementPhase.stopping;
    measurementStatus.value = '正在结束实时检测';
    measurementProgress.value = 0.7;
    if (sendStopCommand) {
      try {
        await _repository.stopMeasurement();
      } catch (error) {
        logError('Failed to stop measurement', error);
      }
    }
    await _cancelMeasurementSubscriptions();
  }

  Future<void> _syncHistoryAndComplete({bool manual = false}) async {
    measurementPhase.value = AlloopMeasurementPhase.syncingHistory;
    measurementStatus.value = '正在同步历史数据并更新体温与趋势';
    measurementProgress.value = 0.74;
    var historyWarning = '';
    try {
      await for (final event in _repository.syncHistory().timeout(
        const Duration(seconds: 40),
      )) {
        switch (event) {
          case HistoryRecordReceived():
            await _persistHistoryRecord(event.record);
            final total = event.total;
            if (total != null && total > 0) {
              measurementProgress.value =
                  (0.74 + (event.index + 1) / total * 0.2).clamp(0.74, 0.94);
            }
          case HistoryAllCompleted():
            _deviceStatusController.clearHistoryFlags(
              measurement: (event.counts['measurement'] ?? 0) > 0,
              activity: (event.counts['activity'] ?? 0) > 0,
              sport: (event.counts['sport'] ?? 0) > 0,
            );
          case HistorySyncError():
            throw AlloopBlueLiteException(event.code, event.message);
          case HistoryTypeStarted() || HistoryTypeCompleted():
            break;
        }
      }
    } catch (error) {
      historyWarning = '；历史同步暂未完成：${_describeError(error)}';
      logWarning('History sync after measurement did not complete: $error');
    }
    await LocalHealthDatabase.notifyMeasurementBlockCompleted();
    await LocalHealthDatabase.instance.upsertDevice(
      deviceId: deviceId,
      name: deviceName.value.isEmpty ? deviceId : deviceName.value,
      type: 'alloop_ring',
      firmwareVersion: deviceInfo.value?.firmwareVersion,
      batteryPercent: deviceInfo.value?.batteryPercent,
      connected: isConnected.value,
      lastSyncAt: DateTime.now().toUtc(),
    );
    await loadTrends();
    measurementPhase.value = AlloopMeasurementPhase.completed;
    measurementProgress.value = 1;
    measurementStatus.value = manual
        ? '历史数据已更新$historyWarning'
        : '一键检测完成，结果与趋势已更新$historyWarning';
    AlToast.showSuccess(manual ? '历史同步流程已结束' : '一键检测完成');
  }

  Future<void> _persistMeasurementResult(
    Spo2Result result,
    DateTime timestamp,
  ) async {
    final rawData = <String, dynamic>{
      'recordKind': 'alloop_one_tap_measurement',
      'isVerified': result.isVerified,
      'success': result.success,
    };
    try {
      await LocalHealthDatabase.instance.saveVitalReading(
        source: 'alloop_ring',
        deviceId: deviceId,
        recordedAt: timestamp,
        heartRate: result.hr?.toDouble(),
        spo2: result.spo2?.toDouble(),
        isValid: result.success ?? true,
        rawData: rawData,
      );
      await LocalHealthDatabase.instance.saveRingMeasurementResult(
        deviceId: deviceId,
        recordedAt: timestamp,
        sdkHeartRate: result.isVerified ? null : result.hr,
        sdkSpo2: result.isVerified ? null : result.spo2,
        algorithmSpo2: result.isVerified ? result.spo2?.toDouble() : null,
        signalQuality: null,
        valid: result.success ?? true,
        rawData: rawData,
      );
    } catch (error) {
      logError('Failed to persist one-tap result', error);
    }
  }

  Future<void> _persistHistoryRecord(Object record) async {
    switch (record) {
      case MeasurementRecord record:
        final recordedAt = LocalHealthDatabase.fromUnixSeconds(record.unixSec);
        await LocalHealthDatabase.instance.saveVitalReading(
          source: 'alloop_ring',
          deviceId: deviceId,
          recordedAt: recordedAt,
          heartRate: record.hr.toDouble(),
          hrv: record.hrv.toDouble(),
          spo2: record.spo2.toDouble(),
          respiratoryRate: record.respiratoryRateBreathsPerMinute,
          isValid: record.hrSuccess || record.spo2Success,
          rawData: const {'recordKind': 'ring_history_measurement'},
        );
      case SportRecord record:
        await LocalHealthDatabase.instance.saveRingDailyLog(
          deviceId: deviceId,
          recordedAt: LocalHealthDatabase.fromUnixSeconds(record.unixSec),
          logType: 'sport',
          heartRate: record.hr,
          steps: record.steps,
          activityCount: record.activityCount,
          rawData: const {'recordKind': 'ring_history_sport'},
        );
      case ActivityRecord record:
        final recordedAt = LocalHealthDatabase.fromUnixSeconds(record.unixSec);
        final temperature = _averageValidTemperatures(record.temperaturesC);
        if (temperature != null) displayTemperature.value = temperature;
        await LocalHealthDatabase.instance.saveRingDailyLog(
          deviceId: deviceId,
          recordedAt: recordedAt,
          logType: 'activity',
          steps: record.steps,
          batteryPercent: record.batteryPercent,
          activeSeconds: record.activeSeconds,
          temperaturesC: record.temperaturesC,
          rawData: const {'recordKind': 'ring_history_activity'},
        );
        if (temperature != null) {
          await LocalHealthDatabase.instance.saveVitalReading(
            source: 'alloop_ring',
            deviceId: deviceId,
            recordedAt: recordedAt,
            temperature: temperature,
            rawData: const {'recordKind': 'ring_history_temperature'},
          );
        }
    }
  }

  Future<void> _cancelMeasurementSubscriptions() async {
    await _resultSub?.cancel();
    await _ppgSub?.cancel();
    await _accSub?.cancel();
    _resultSub = null;
    _ppgSub = null;
    _accSub = null;
  }

  void _resetMeasurementData() {
    displaySpo2.value = null;
    displayHeartRate.value = null;
    ppgLedG.clear();
    ppgLedGAmb.clear();
    ppgLedRedAmb.clear();
    ppgLedIr.clear();
    accX.clear();
    accY.clear();
    accZ.clear();
    _ppgReceivedSamples = 0;
    _accReceivedSamples = 0;
    measurementProgress.value = 0;
  }

  void _restoreLatestValues(List<AlloopTrendPoint> points) {
    for (final point in points.reversed) {
      displayHeartRate.value ??= point.heartRate?.round();
      displaySpo2.value ??= point.spo2?.round();
      displayTemperature.value ??= point.temperature;
      if (displayHeartRate.value != null &&
          displaySpo2.value != null &&
          displayTemperature.value != null) {
        break;
      }
    }
  }

  Future<void> _fetchDeviceInfo({bool silent = false}) async {
    if (!isConnected.value) return;
    try {
      final info = await _repository.getDeviceInfo();
      deviceInfo.value = info;
      await LocalHealthDatabase.instance.upsertDevice(
        deviceId: deviceId,
        name: initialName.isEmpty ? deviceId : initialName,
        type: 'alloop_ring',
        firmwareVersion: info.firmwareVersion,
        batteryPercent: info.batteryPercent,
        connected: true,
      );
    } catch (error) {
      if (!silent) AlToast.showError('设备信息读取失败：${_describeError(error)}');
      logError('Failed to fetch device info', error);
    }
  }

  void _startConnectTimeoutTimer() {
    _cancelConnectTimeoutTimer();
    _connectTimeoutTimer = Timer(_connectTimeout, () {
      if (!_awaitingConnectResult) return;
      _awaitingConnectResult = false;
      isConnecting.value = false;
      AlToast.showError('连接超时，请重试');
    });
  }

  void _cancelConnectTimeoutTimer() {
    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = null;
  }

  bool _ensureConnected() {
    if (isConnected.value) return true;
    AlToast.showError('请先连接 Alloop Ring');
    return false;
  }

  DateTime? _dateFromDatabase(Object? value) {
    final milliseconds = (value as num?)?.toInt();
    if (milliseconds == null || milliseconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }

  double? _finiteDouble(Object? value) {
    final result = (value as num?)?.toDouble();
    return result != null && result.isFinite ? result : null;
  }

  double? _averageTemperatures(String encoded) {
    final values = encoded
        .split(';')
        .map(double.tryParse)
        .whereType<double>()
        .toList(growable: false);
    return _averageValidTemperatures(values);
  }

  double? _averageValidTemperatures(Iterable<double> values) {
    final valid = values
        .where((value) => value.isFinite && value >= 20 && value <= 45)
        .toList(growable: false);
    if (valid.isEmpty) return null;
    return valid.reduce((a, b) => a + b) / valid.length;
  }

  String _describeError(Object error) {
    if (error is AlloopBlueLiteException) {
      return '${error.code}${error.message?.isEmpty ?? true ? '' : '：${error.message}'}';
    }
    return error.toString();
  }
}
