import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/database/local_health_database.dart';
import '../../../foundations/log/al_logger.dart';
import '../data/xiaozhi_ble_repository.dart';
import '../domain/proactive_voice_config.dart';

/// Snapshot exposed to the device page for transparent proactive-voice state.
class ProactiveVoiceStatus {
  const ProactiveVoiceStatus({
    required this.config,
    required this.isXiaoZhiConnected,
    required this.pendingConversationCount,
    this.lastSpeechAt,
    this.lastError,
  });

  final ProactiveVoiceConfig config;
  final bool isXiaoZhiConnected;
  final int pendingConversationCount;
  final DateTime? lastSpeechAt;
  final String? lastError;
}

/// Converts new vital readings and wall-clock moments into XiaoZhi dialogs.
///
/// XiaoZhi remains the BLE peripheral and speaks through its existing
/// `send_text` interaction. This service never opens a second GATT connection:
/// it only writes while the app's existing XiaoZhi connection reports `ready`.
class XiaoZhiProactiveVoiceService {
  XiaoZhiProactiveVoiceService._({
    XiaoZhiBleRepository? repository,
    DateTime Function()? clock,
  })  : _repository = repository ?? XiaoZhiBleRepository(),
        _clock = clock ?? DateTime.now;

  static final XiaoZhiProactiveVoiceService instance =
      XiaoZhiProactiveVoiceService._();

  static const String _logTag = 'XIAOZHI_VOICE';
  static const Duration _schedulerInterval = Duration(seconds: 15);
  static const Duration _pendingTimeout = Duration(minutes: 2);
  static const int _maxOutstandingConversations = 4;

  final XiaoZhiBleRepository _repository;
  final DateTime Function() _clock;
  final StreamController<ProactiveVoiceStatus> _statusController =
      StreamController<ProactiveVoiceStatus>.broadcast();
  final Map<ProactiveVitalAlertType, DateTime> _lastVitalAlertAt = {};
  final Set<String> _pendingRequestIds = <String>{};
  final Set<String> _completedScheduleSlots = <String>{};

  StreamSubscription<VitalReadingSaved>? _vitalSubscription;
  StreamSubscription<Map<String, dynamic>>? _bleEventSubscription;
  Timer? _scheduler;
  ProactiveVoiceConfig _config = const ProactiveVoiceConfig();
  bool _initialized = false;
  bool _isXiaoZhiConnected = false;
  int _requestSequence = 0;
  DateTime? _lastSpeechAt;
  String? _lastError;

  ProactiveVoiceConfig get config => _config;
  ProactiveVoiceStatus get status => ProactiveVoiceStatus(
        config: _config,
        isXiaoZhiConnected: _isXiaoZhiConnected,
        pendingConversationCount: _pendingRequestIds.length,
        lastSpeechAt: _lastSpeechAt,
        lastError: _lastError,
      );
  Stream<ProactiveVoiceStatus> get statusStream => _statusController.stream;

  /// Starts listening before a XiaoZhi device is connected, so an ensuing
  /// `ready` event is not missed. It is safe to call more than once.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (defaultTargetPlatform != TargetPlatform.android) {
      _emitStatus();
      return;
    }
    _vitalSubscription = LocalHealthDatabase.vitalReadingStream.listen(
      (reading) => unawaited(_handleVitalReading(reading)),
    );
    _bleEventSubscription = _repository.events.listen(
      _handleBleEvent,
      onError: (Object error, StackTrace stackTrace) {
        _lastError = '小智事件通道不可用：$error';
        AlLogger.warning(
          'XiaoZhi event stream failed',
          tag: _logTag,
          error: error,
          stackTrace: stackTrace,
        );
        _emitStatus();
      },
    );
    _scheduler = Timer.periodic(_schedulerInterval, (_) => _runSchedule());
    _emitStatus();
  }

  void updateConfig(ProactiveVoiceConfig config) {
    _config = config;
    _completedScheduleSlots.clear();
    _emitStatus();
  }

  /// Sends an immediate friendly check-in from the UI. It intentionally does
  /// not bypass the connection or outstanding-request safeguards.
  Future<bool> speakNow() => _sendText(
        reason: 'manual',
        text:
            '请现在主动用温暖、简短的中文向用户问候，关心一下他此刻的状态，并邀请他需要时和你聊聊。',
      );

  Future<void> dispose() async {
    _scheduler?.cancel();
    await _vitalSubscription?.cancel();
    await _bleEventSubscription?.cancel();
    await _statusController.close();
  }

  void _handleBleEvent(Map<String, dynamic> event) {
    switch (event['kind']) {
      case 'connection':
        final wasConnected = _isXiaoZhiConnected;
        _isXiaoZhiConnected = event['state'] == 'ready';
        if (!_isXiaoZhiConnected) _pendingRequestIds.clear();
        _emitStatus();
        if (_isXiaoZhiConnected &&
            !wasConnected &&
            _config.enabled &&
            !_config.isQuietAt(_clock())) {
          unawaited(
            _sendText(
              reason: 'connected',
              text: '请主动用温暖、简短的中文欢迎用户回来，并告诉他你会在需要时提供健康关怀和陪伴。',
            ),
          );
        }
      case 'connectionLost':
        _isXiaoZhiConnected = false;
        _pendingRequestIds.clear();
        _emitStatus();
      case 'commandResponse':
        _handleInteractionStatus(event['payload']?.toString());
    }
  }

  void _handleInteractionStatus(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map || decoded['type'] != 'interaction_status') return;
      final requestId = decoded['request_id'];
      final state = decoded['state'];
      if (requestId is! String || state is! String) return;
      if (state == 'completed' || state == 'failed') {
        _pendingRequestIds.remove(requestId);
        _emitStatus();
      }
    } on FormatException {
      // Non-JSON command responses are valid for other XiaoZhi commands.
    }
  }

  Future<void> _handleVitalReading(VitalReadingSaved reading) async {
    if (!_config.enabled ||
        reading.origin != HealthDataOrigin.realDevice ||
        !_isXiaoZhiConnected) {
      return;
    }
    final alerts = detectProactiveVitalAlerts(
      config: _config,
      isValid: reading.isValid,
      heartRate: reading.heartRate,
      spo2: reading.spo2,
    );
    final now = _clock();
    final dueAlerts = alerts.where((alert) {
      final lastSent = _lastVitalAlertAt[alert.type];
      return lastSent == null ||
          now.difference(lastSent) >= _config.healthAlertCooldown;
    }).toList();
    if (dueAlerts.isEmpty) return;

    final didSend = await _sendText(
      reason: 'health',
      text: _healthPrompt(dueAlerts),
    );
    if (didSend) {
      for (final alert in dueAlerts) {
        _lastVitalAlertAt[alert.type] = now;
      }
    }
  }

  void _runSchedule() {
    if (!_config.enabled ||
        !_isXiaoZhiConnected ||
        _config.isQuietAt(_clock())) {
      return;
    }
    final now = _clock();
    final minuteOfDay = now.hour * 60 + now.minute;
    String? slot;
    if (_config.hourlyGreetingEnabled && now.minute == 0) {
      slot = 'hourly-${now.year}-${now.month}-${now.day}-${now.hour}';
    } else if (_config.normalizedScheduledGreetingMinutes.contains(minuteOfDay)) {
      slot = 'custom-${now.year}-${now.month}-${now.day}-$minuteOfDay';
    }
    if (slot == null || _completedScheduleSlots.contains(slot)) return;
    _completedScheduleSlots.add(slot);
    _trimScheduleSlots(now);
    unawaited(
      _sendText(
        reason: 'greeting',
        text: _greetingPrompt(now),
      ),
    );
  }

  Future<bool> _sendText({required String reason, required String text}) async {
    if (!_config.enabled || !_isXiaoZhiConnected) return false;
    if (_pendingRequestIds.length >= _maxOutstandingConversations) {
      _lastError = '小智仍在处理多条对话，稍后再发起新的主动提醒';
      _emitStatus();
      return false;
    }
    final requestId = _newRequestId(reason);
    _pendingRequestIds.add(requestId);
    _lastError = null;
    _emitStatus();
    try {
      await _repository.sendText(requestId: requestId, text: text);
      _lastSpeechAt = _clock();
      AlLogger.info('Proactive XiaoZhi dialog sent: reason=$reason', tag: _logTag);
      Timer(_pendingTimeout, () {
        if (_pendingRequestIds.remove(requestId)) _emitStatus();
      });
      _emitStatus();
      return true;
    } catch (error, stackTrace) {
      _pendingRequestIds.remove(requestId);
      _lastError = '发送小智主动对话失败：$error';
      AlLogger.warning(
        'Failed to send proactive XiaoZhi dialog: reason=$reason',
        tag: _logTag,
        error: error,
        stackTrace: stackTrace,
      );
      _emitStatus();
      return false;
    }
  }

  String _newRequestId(String reason) {
    _requestSequence = (_requestSequence + 1) % 10000;
    return 'proactive-$reason-${_clock().millisecondsSinceEpoch}-$_requestSequence';
  }

  String _healthPrompt(List<ProactiveVitalAlert> alerts) {
    final details = alerts.map((alert) {
      switch (alert.type) {
        case ProactiveVitalAlertType.heartRateLow:
          return '心率 ${alert.value.toStringAsFixed(0)} 次/分钟，低于提醒阈值';
        case ProactiveVitalAlertType.heartRateHigh:
          return '心率 ${alert.value.toStringAsFixed(0)} 次/分钟，高于提醒阈值';
        case ProactiveVitalAlertType.spo2Low:
          return '血氧饱和度 ${alert.value.toStringAsFixed(0)}%，低于提醒阈值';
      }
    }).join('；');
    return '请立刻主动用中文语音温和提醒用户：刚刚测得$details。'
        '提醒其先停下活动、稍作休息后复测；不要作出诊断，也不要制造恐慌。'
        '如果感到明显不适或数值持续异常，建议尽快向专业医疗人员咨询。';
  }

  String _greetingPrompt(DateTime now) {
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '现在是 $hour:$minute。请主动用自然、简短、温暖的中文问候用户，'
        '结合这个时段提醒喝水、活动一下或休息，并邀请用户随时和你聊天。';
  }

  void _trimScheduleSlots(DateTime now) {
    final todayPrefix = '-${now.year}-${now.month}-${now.day}-';
    _completedScheduleSlots.removeWhere((slot) => !slot.contains(todayPrefix));
  }

  void _emitStatus() {
    if (!_statusController.isClosed) _statusController.add(status);
  }
}
