import Foundation
import Combine
import RingSDK

class RingHealthService {

    private let _measureResult = PassthroughSubject<MeasureResult, Never>()
    var measureResults: AnyPublisher<MeasureResult, Never> {
        _measureResult.eraseToAnyPublisher()
    }

    /// Per-measurement timeout in seconds, varies by type.
    private static func timeout(for type: MeasureType) -> TimeInterval {
        switch type {
        case .uv:               return 120  // UV sensor needs longer warm-up
        case .bodyComposition:  return 120  // BC requires steady contact, needs more time
        case .heartRate, .spo2: return 30
        case .temperature:      return 45
        case .stress:           return 30
        case .bloodPressure:    return 30
        }
    }

    // MARK: - Start Measurement

    func startMeasurement(type: MeasureType) -> Future<MeasureResult, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RingError.notConnected))
                return
            }

            // Guard against double-fulfillment (timeout vs callback race).
            var fulfilled = false
            let fulfill: (Result<MeasureResult, Error>) -> Void = { result in
                guard !fulfilled else { return }
                fulfilled = true
                promise(result)
            }

            // Timeout — fire if SDK never calls back.
            let timeoutItem = DispatchWorkItem {
                print("[RingHealth] ⏰ TIMEOUT for \(type.rawValue) after \(Self.timeout(for: type))s")
                self.stopMeasurement(type: type)
                fulfill(.failure(RingError.timeout))
            }
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Self.timeout(for: type),
                execute: timeoutItem
            )

            let sdkType = self.mapToSDKType(type)

            print("[RingHealth] Starting measurement type=\(type.rawValue) sdkType=\(sdkType.rawValue) timeout=\(Self.timeout(for: type))s")

            // Use the new measurement API (v2.0.32+), compatible with all types including bodyComp
            BTService.shared().measureReq.start(with: sdkType, acked: { success in
                print("[RingHealth] ACK for \(type.rawValue): \(success ? "✅" : "❌")")
                if !success {
                    timeoutItem.cancel()
                    fulfill(.failure(RingError.measurementStartFailed))
                }
            }, resultReceived: { result in
                timeoutItem.cancel()
                print("[RingHealth] Result for \(type.rawValue): value=\(result?.measurementResult ?? -999), isNil=\(result == nil)")
                guard let result = result,
                      result.measurementResult != 0,
                      result.measurementResult != -1 else {
                    fulfill(.failure(RingError.measurementStartFailed))
                    return
                }
                let measureResult: MeasureResult
                if type == .bodyComposition {
                    let bc = result.packet
                    if bc.isValidData() {
                        let bcData = BodyCompositionData(
                            bmi: bc.bmi,
                            bodyFatRate: bc.bodyFatRate,
                            muscleMass: bc.muscleMass,
                            hydration: bc.hydration,
                            boneMass: bc.boneSaltMass,
                            bmr: bc.basalMetabolicRate,
                            visceralFat: 0,
                            subcutaneousFat: 0,
                            proteinRate: bc.proteinMassPercentage,
                            bodyAge: 0,
                            weight: bc.standardWeight
                        )
                        measureResult = MeasureResult(type: type, value: result.measurementResult, bodyComposition: bcData)
                    } else {
                        measureResult = MeasureResult(type: type, value: result.measurementResult)
                    }
                } else {
                    measureResult = MeasureResult(type: type, value: result.measurementResult)
                }
                fulfill(.success(measureResult))
                self._measureResult.send(measureResult)
            })
        }
    }

    // MARK: - Stop Measurement

    func stopMeasurement(type: MeasureType) {
        let sdkType = mapToSDKType(type)
        BTService.shared().measureReq.stopMeasurement(with: sdkType) { _ in }
    }

    // MARK: - Fetch Historical Health Data

    func fetchHealthData(date: DateComponents) -> Future<[HealthData], Error> {
        return Future { promise in
            BTService.shared().healthReq.fetchData(with: date) { models in
                guard !models.isEmpty else {
                    promise(.failure(RingError.dataFetchFailed))
                    return
                }
                let dataList = models.map { model in
                    HealthData(
                        heartRates: [Int(model.dailyHeartRate)],
                        hrv: Int(model.hrv),
                        spo2Values: [Int(model.spo2)],
                        stressValues: [Int(model.stress)],
                        steps: Int(model.steps),
                        distance: Int(model.distance),
                        calories: Int(model.calories),
                        temperatures: [model.bodyTemperature],
                        date: Date()
                    )
                }
                promise(.success(dataList))
            }
        }
    }

    // MARK: - Type Mapping

    private func mapToSDKType(_ type: MeasureType) -> BTMeasureType {
        switch type {
        case .heartRate:        return .hr
        case .spo2:             return .spo2
        case .bloodPressure:    return .bp
        case .temperature:      return .temp
        case .stress:           return .stress
        case .bodyComposition:  return .bodyComp
        case .uv:               return BTMeasureType(rawValue: 0x0A)!
        }
    }
}
