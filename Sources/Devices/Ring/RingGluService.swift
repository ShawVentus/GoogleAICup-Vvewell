import Foundation
import Combine
import RingSDK
import EiotGluSdk

class RingGluService {

    private var collectedPackets: [BTGluPacket] = []

    // MARK: - Initialize Glu SDK

    func initialize(appID: String, region: String = "2") {
        SNNetModel.sharedInstance(withIdentifier: appID, region: region)
    }

    // MARK: - Glucose Measurement

    func startMeasurement() -> PassthroughSubject<GluEvent, Never> {
        let subject = PassthroughSubject<GluEvent, Never>()
        collectedPackets = []
        subject.send(.measuring(progress: 0))

        BTService.shared().measureReq.startGluMeasure(ack: { success in
            if !success {
                subject.send(.failed(RingError.gluMeasurementFailed))
                subject.send(completion: .finished)
            }
        }, pkt: { [weak self] pkt in
            guard let self = self else { return }
            self.collectedPackets.append(pkt)
            let progress = min(Float(self.collectedPackets.count) / 10.0, 1.0)
            subject.send(.measuring(progress: progress))
        }, allPkts: { [weak self] allPackets in
            guard let self = self else { return }
            var ppgHexStrings: [String] = []
            for packet in self.collectedPackets {
                let values = packet.gluData as [BTGluValue]
                for value in values {
                    let hex = value.hexString
                    if !hex.isEmpty {
                        ppgHexStrings.append(hex)
                    }
                }
            }

            let ppgString = ppgHexStrings.joined()
            if ppgString.isEmpty {
                subject.send(.failed(RingError.gluUploadFailed))
                subject.send(completion: .finished)
                return
            }

            subject.send(.uploading)

            let params: [AnyHashable: Any] = ["ppgData": ppgString]
            SNNetModel.postppi("", parameters: params, success: { response in
                if let response = response as? [String: Any],
                   let glucoseValue = response["glucose"] as? Float {
                    let report = GluReport(
                        glucoseValue: glucoseValue,
                        riskLevel: (response["riskLevel"] as? Int) ?? 0,
                        timestamp: Date(),
                        rawData: response
                    )
                    subject.send(.report(report))
                } else {
                    subject.send(.failed(RingError.gluAnalysisFailed))
                }
                subject.send(completion: .finished)
            }, failure: { _ in
                subject.send(.failed(RingError.gluAnalysisFailed))
                subject.send(completion: .finished)
            })
        })

        return subject
    }
}
