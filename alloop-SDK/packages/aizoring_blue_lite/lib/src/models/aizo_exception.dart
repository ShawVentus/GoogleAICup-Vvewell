/// Exception thrown by the AIZORING Blue Lite plugin.
class AizoringBlueLiteException implements Exception {
  /// Machine-readable error code.
  final String code;

  /// Human-readable error message.
  final String? message;

  const AizoringBlueLiteException(this.code, [this.message]);

  @override
  String toString() => 'AizoringBlueLiteException($code): $message';
}
