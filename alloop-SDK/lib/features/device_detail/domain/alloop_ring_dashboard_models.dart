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
  day('日', Duration(days: 1)),
  week('周', Duration(days: 7)),
  month('月', Duration(days: 30));

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
