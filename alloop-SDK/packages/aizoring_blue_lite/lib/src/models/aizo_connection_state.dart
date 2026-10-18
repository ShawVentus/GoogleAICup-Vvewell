/// Connection state values for AIZORING devices.
enum AizoConnectionStateValue {
  connecting,
  connected,
  disconnected,
}

/// Connection state event from the AIZORING SDK.
class AizoConnectionState {
  final AizoConnectionStateValue state;
  final String? errorCode;
  final int? errorState;

  const AizoConnectionState({
    required this.state,
    this.errorCode,
    this.errorState,
  });

  factory AizoConnectionState.fromMap(Map<dynamic, dynamic> map) {
    final stateStr = map['state'] as String? ?? 'disconnected';
    AizoConnectionStateValue state;
    switch (stateStr) {
      case 'connecting':
        state = AizoConnectionStateValue.connecting;
        break;
      case 'connected':
        state = AizoConnectionStateValue.connected;
        break;
      default:
        state = AizoConnectionStateValue.disconnected;
    }
    return AizoConnectionState(
      state: state,
      errorCode: map['errorCode'] as String?,
      errorState: map['errorState'] as int?,
    );
  }

  @override
  String toString() =>
      'AizoConnectionState(state: $state, errorCode: $errorCode)';
}
