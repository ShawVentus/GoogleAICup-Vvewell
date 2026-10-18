/// A single PPI (pulse-to-pulse interval) data point from continuous measurement.
class PpiSample {
  /// Unix timestamp in milliseconds.
  final int time;

  /// Pulse-to-pulse interval value.
  final int ppi;

  const PpiSample({required this.time, required this.ppi});

  factory PpiSample.fromMap(Map<dynamic, dynamic> map) {
    return PpiSample(
      time: map['time'] as int? ?? 0,
      ppi: map['ppi'] as int? ?? 0,
    );
  }
}

/// A single Loving (HR+temp+accel) data point from continuous measurement.
class LovingSample {
  /// Unix timestamp in milliseconds.
  final int time;

  /// Heart rate in bpm.
  final int hr;

  /// Skin temperature.
  final double temp;

  /// Accelerometer X axis.
  final double axisX;

  /// Accelerometer Y axis.
  final double axisY;

  /// Accelerometer Z axis.
  final double axisZ;

  const LovingSample({
    required this.time,
    required this.hr,
    required this.temp,
    required this.axisX,
    required this.axisY,
    required this.axisZ,
  });

  factory LovingSample.fromMap(Map<dynamic, dynamic> map) {
    return LovingSample(
      time: map['time'] as int? ?? 0,
      hr: map['hr'] as int? ?? 0,
      temp: (map['temp'] as num?)?.toDouble() ?? 0,
      axisX: (map['axisX'] as num?)?.toDouble() ?? 0,
      axisY: (map['axisY'] as num?)?.toDouble() ?? 0,
      axisZ: (map['axisZ'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Union type for continuous measurement data.
///
/// Use [isPpi], [isLoving], [ppiSamples], [lovingSamples] to inspect.
/// Construct via [AizoContinuousData.fromMap].
abstract class AizoContinuousData {
  const AizoContinuousData();

  /// Parse from a native event map, dispatching on the `kind` key.
  factory AizoContinuousData.fromMap(Map<dynamic, dynamic> map) {
    final kind = map['kind'] as String?;
    if (kind == 'ppi') {
      final rawList = map['samples'] as List<dynamic>? ?? [];
      return _PpiData(
        samples: rawList
            .map((e) => PpiSample.fromMap(e as Map<dynamic, dynamic>))
            .toList(),
      );
    }
    final rawList = map['samples'] as List<dynamic>? ?? [];
    return _LovingData(
      startTime: map['startTime'] as int? ?? 0,
      frequency: (map['frequency'] as num?)?.toDouble() ?? 0,
      samples: rawList
          .map((e) => LovingSample.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
    );
  }

  /// Whether this is PPI data.
  bool get isPpi => this is _PpiData;

  /// Whether this is Loving (HR+temp+accel) data.
  bool get isLoving => this is _LovingData;

  /// All PPI samples, or empty if this is Loving data.
  List<PpiSample> get ppiSamples {
    final self = this;
    return self is _PpiData ? self.samples : const [];
  }

  /// All Loving samples, or empty if this is PPI data.
  List<LovingSample> get lovingSamples {
    final self = this;
    return self is _LovingData ? self.samples : const [];
  }

  /// Start time of Loving data batch, or null for PPI data.
  int? get startTime {
    final self = this;
    return self is _LovingData ? self.startTime : null;
  }

  /// Sampling frequency in Hz, or null for PPI data.
  double? get frequency {
    final self = this;
    return self is _LovingData ? self.frequency : null;
  }
}

class _PpiData extends AizoContinuousData {
  final List<PpiSample> samples;
  const _PpiData({required this.samples});
}

class _LovingData extends AizoContinuousData {
  @override
  final int startTime;

  @override
  final double frequency;
  final List<LovingSample> samples;
  const _LovingData({
    required this.startTime,
    required this.frequency,
    required this.samples,
  });
}
