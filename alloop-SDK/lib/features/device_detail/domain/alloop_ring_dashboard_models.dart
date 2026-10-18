enum AlloopMeasurementPhase {
  idle,
  measuring,
  stopping,
  syncingHistory,
  completed,
  error,
}

extension AlloopMeasurementPhaseX on AlloopMeasurementPhase {
  bool get isBusy =>
      this == AlloopMeasurementPhase.measuring ||
      this == AlloopMeasurementPhase.stopping ||
      this == AlloopMeasurementPhase.syncingHistory;

  bool get canStart => !isBusy;
}

enum AlloopTrendRange {
  day("Day", Duration(days: 1)),
  week("Week", Duration(days: 7)),
  month("Month", Duration(days: 30));

  const AlloopTrendRange(this.label, this.duration);

  final String label;
  final Duration duration;
}

class AlloopTrendPoint {
  const AlloopTrendPoint({
    required this.recordedAt,
    this.heartRate,
    this.spo2,
    this.temperature,
  });

  final DateTime recordedAt;
  final double? heartRate;
  final double? spo2;
  final double? temperature;
}
