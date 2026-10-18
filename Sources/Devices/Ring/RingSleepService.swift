import Foundation
import Combine
import RingSDK

class RingSleepService {

    // MARK: - Fetch Sleep Data

    func fetchSleepData(date: DateComponents) -> Future<SleepData, Error> {
        return Future { promise in
            BTService.shared().sleepReq.handleData { summaryModel, details in
                guard let details = details, !details.isEmpty else {
                    promise(.failure(RingError.dataFetchFailed))
                    return
                }

                let summary: SleepSummary
                if let s = summaryModel {
                    summary = SleepSummary(
                        totalSleep: Int(s.totalSleepDuration),
                        deepSleep: Int(s.deepSleepDuration),
                        lightSleep: Int(s.lightSleepDuration),
                        remSleep: Int(s.remSleepDuration),
                        awakeDuration: Int(s.awakeDuration),
                        awakeCount: Int(s.awakeCount),
                        startTimestamp: TimeInterval(s.startTimestamp),
                        endTimestamp: TimeInterval(s.endTimestamp)
                    )
                } else {
                    var deep = 0, light = 0, rem = 0, awake = 0, awakeCount = 0
                    for detail in details {
                        let mins = Int(detail.timestamp - detail.startTimestamp) / 60
                        switch detail.sleepMode {
                        case .deep: deep += mins
                        case .light: light += mins
                        case .REM: rem += mins
                        case .awake: awake += mins; awakeCount += 1
                        default: break
                        }
                    }
                    summary = SleepSummary(
                        totalSleep: deep + light + rem,
                        deepSleep: deep, lightSleep: light, remSleep: rem,
                        awakeDuration: awake, awakeCount: awakeCount,
                        startTimestamp: TimeInterval(details.first?.startTimestamp ?? 0),
                        endTimestamp: TimeInterval(details.last?.timestamp ?? 0)
                    )
                }

                let sleepDetails: [SleepDetail] = details.map { detail in
                    SleepDetail(
                        mode: SleepMode(rawValue: Int(detail.sleepMode.rawValue)) ?? .light,
                        startTimestamp: TimeInterval(detail.startTimestamp),
                        duration: Int(detail.timestamp - detail.startTimestamp) / 60
                    )
                }

                promise(.success(SleepData(summary: summary, details: sleepDetails)))
            }

            BTService.shared().sleepReq.fetch(with: date)
        }
    }
}
