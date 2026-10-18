/// ECG measurement result summary from the AIZORING ring.
class AizoEcgResult {
  /// Device MAC address.
  final String address;

  /// Unique ECG record ID.
  final String ecgId;

  /// Unix timestamp when measurement started.
  final int startTime;

  /// Measurement duration in seconds.
  final int duration;

  /// Sampling frequency in Hz.
  final int frequency;

  /// ECG lead type.
  final int leads;

  /// ECG analysis result:
  /// -1=uncertain, 0=normal, 1=atrial flutter, 2=atrial fibrillation,
  /// 3=ventricular fib/flutter, 4=other arrhythmia, 5=noise,
  /// 6=supraventricular premature, 7=ventricular premature.
  final int ecgResult;

  /// Average heart rate during measurement in bpm.
  final int avgHr;

  const AizoEcgResult({
    this.address = '',
    this.ecgId = '',
    this.startTime = 0,
    this.duration = 0,
    this.frequency = 0,
    this.leads = 0,
    this.ecgResult = -1,
    this.avgHr = 0,
  });

  factory AizoEcgResult.fromMap(Map<dynamic, dynamic> map) {
    return AizoEcgResult(
      address: map['address'] as String? ?? '',
      ecgId: map['ecgId'] as String? ?? '',
      startTime: map['startTime'] as int? ?? 0,
      duration: map['duration'] as int? ?? 0,
      frequency: map['frequency'] as int? ?? 0,
      leads: map['leads'] as int? ?? 0,
      ecgResult: map['ecgResult'] as int? ?? -1,
      avgHr: map['avgHr'] as int? ?? 0,
    );
  }

  /// Human-readable label for the ECG analysis result.
  String get resultLabel {
    switch (ecgResult) {
      case -1:
        return 'Uncertain';
      case 0:
        return 'Normal';
      case 1:
        return 'Atrial Flutter';
      case 2:
        return 'Atrial Fibrillation';
      case 3:
        return 'Ventricular Fib/Flutter';
      case 4:
        return 'Other Arrhythmia';
      case 5:
        return 'Noise';
      case 6:
        return 'Supraventricular Premature';
      case 7:
        return 'Ventricular Premature';
      default:
        return 'Unknown';
    }
  }

  @override
  String toString() =>
      'AizoEcgResult(avgHr: $avgHr, result: $resultLabel, duration: ${duration}s)';
}

/// A single batch of raw ECG waveform samples.
class AizoEcgSamples {
  /// The raw sample values (in microvolts or normalized units).
  final List<double> samples;

  /// Metadata value from the SDK (varies by SDK version).
  final int metadata;

  const AizoEcgSamples({required this.samples, this.metadata = 0});

  factory AizoEcgSamples.fromMap(Map<dynamic, dynamic> map) {
    final rawList = map['samples'] as List<dynamic>? ?? [];
    return AizoEcgSamples(
      samples: rawList.map((e) => (e as num).toDouble()).toList(),
      metadata: map['metadata'] as int? ?? 0,
    );
  }
}
