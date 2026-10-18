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
        _lastError = 'XiaoZhi event channel unavailable: $error';
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
            "Greet the user briefly and warmly in English, ask how they feel, and invite them to chat if needed.",
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
              text: "Welcome the user back briefly and warmly in English. Let them know you can offer health support and companionship when needed.",
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
      _lastError = "XiaoZhi is handling several conversations. Try the reminder again later.";
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
      _lastError = 'Could not start XiaoZhi conversation: $error';
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
          return 'Heart rate ${alert.value.toStringAsFixed(0)} bpm, below the alert threshold';
        case ProactiveVitalAlertType.heartRateHigh:
          return 'Heart rate ${alert.value.toStringAsFixed(0)} bpm, above the alert threshold';
        case ProactiveVitalAlertType.spo2Low:
          return 'Oxygen saturation ${alert.value.toStringAsFixed(0)}%, below the alert threshold';
      }
    }).join('；');
    return 'Gently alert the user now in spoken English. The latest reading is $details。'
        "Ask them to pause activity, rest briefly and check again. Do not diagnose or cause alarm. "
        "Recommend prompt professional medical advice if the user feels unwell or readings remain unusual.";
  }

  String _greetingPrompt(DateTime now) {
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return 'The time is $hour:$minute. Greet the user briefly and warmly in English. '
        "Suggest water, movement or rest as appropriate for this time of day, and invite them to chat.";
  }

  void _trimScheduleSlots(DateTime now) {
    final todayPrefix = '-${now.year}-${now.month}-${now.day}-';
    _completedScheduleSlots.removeWhere((slot) => !slot.contains(todayPrefix));
  }

  void _emitStatus() {
    if (!_statusController.isClosed) _statusController.add(status);
  }
}
