import Foundation
import Combine
import RingSDK

class RingECGService {

    private var collectedPackets: [BTECGPacket] = []

    // MARK: - ECG Measurement

    func startECG(handPreference: UInt8 = 0) -> PassthroughSubject<ECGEvent, Never> {
        let subject = PassthroughSubject<ECGEvent, Never>()
        collectedPackets = []

        BTService.shared().measureReq.sendECGLatencyMode(withStatus: true) { [weak self] success in
            guard let self = self else { return }
            if !success {
                subject.send(.failed(RingError.ecgNotSupported))
                subject.send(completion: .finished)
                return
            }

            BTService.shared().measureReq.startECG(withHandPreference: handPreference, completion: { success in
                if success {
                    subject.send(.started)
                } else {
                    subject.send(.failed(RingError.ecgNotSupported))
                    subject.send(completion: .finished)
                }
            }, data: { pkts in
                for packet in pkts {
                    self.collectedPackets.append(packet)
                    let values = (packet.ecgData as [BTECGValue]).map { $0.value }
                    let packetData = ECGPacketData(
                        values: values,
                        sampleRate: Int(packet.sampleRate),
                        packetNumber: Int(packet.currentPktNum),
                        timestamp: Date()
                    )
                    subject.send(.packet(packetData))
                }
            }, dataEnd: { allPkts, diagnosisResult in
                let report = self.buildReport(from: self.collectedPackets, diagnosis: diagnosisResult)
                subject.send(.diagnosis(report))
                subject.send(.completed)
                subject.send(completion: .finished)
                BTService.shared().measureReq.sendECGLatencyMode(withStatus: false) { _ in }
            })
        }

        return subject
    }

    // MARK: - Report Building

    private func buildReport(from packets: [BTECGPacket], diagnosis: [AnyHashable: Any]?) -> ECGReport {
        var allValues: [Float] = []
        var sampleRate = 512

        for packet in packets {
            let values = packet.ecgData as [BTECGValue]
            allValues.append(contentsOf: values.map { $0.value })
            if let first = values.first {
                sampleRate = Int(first.sampleRate)
            }
        }

        let minHR = (diagnosis?["minHeartRate"] as? Int) ?? 0
        let avgHR = (diagnosis?["avgHeartRate"] as? Int) ?? 0
        let maxHR = (diagnosis?["maxHeartRate"] as? Int) ?? 0
        let rhythmType = (diagnosis?["rhythmType"] as? Int) ?? 0
        let confidence = (diagnosis?["confidence"] as? Int) ?? 0
        let duration = packets.isEmpty ? 0 : Double(allValues.count) / Double(sampleRate)

        return ECGReport(
            waveform: allValues,
            sampleRate: sampleRate,
            minHeartRate: minHR,
            avgHeartRate: avgHR,
            maxHeartRate: maxHR,
            rhythmType: rhythmType,
            confidence: confidence,
            duration: duration
        )
    }
}
