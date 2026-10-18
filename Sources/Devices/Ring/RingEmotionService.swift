import Foundation
import Combine
import RingSDK

class RingEmotionService {

    // MARK: - Query Status

    func queryStatus() -> Future<BTRTPPIStatus, Never> {
        return Future { promise in
            BTRtPPI.sharedInstance().queryEmotionMeasureStatus { status, _, _ in
                promise(.success(status))
            }
        }
    }

    // MARK: - Start Emotion Measurement

    func startMeasurement(duration: Int = 60, mode: EmotionMeasureMode = .appControl) -> PassthroughSubject<EmotionEvent, Never> {
        let subject = PassthroughSubject<EmotionEvent, Never>()
        subject.send(.started)

        BTRtPPI.sharedInstance().startEmotionMeasurement(
            with: .PPI,
            duration: UInt(duration),
            mode: UInt8(mode.rawValue)
        ) { _, result in
            if result != 0 {
                subject.send(.failed(RingError.emotionStartFailed))
                subject.send(completion: .finished)
            }
        }

        BTRtPPI.sharedInstance().rtPPIDateHandle = { ppiModel in
            let model = ppiModel
            let ppiData = PPIData(
                ppiValues: model.ppiPoints.map { Int($0.ppi) },
                timestamp: Date()
            )
            subject.send(.ppiData(ppiData))
        }

        return subject
    }

    // MARK: - Stop Measurement

    func stopMeasurement() {
        BTRtPPI.sharedInstance().stopRealTimeMeasure(with: .PPI) { _, _ in }
    }
}
