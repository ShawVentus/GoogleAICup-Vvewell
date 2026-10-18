import Foundation
import Combine
import RingSDK

class RingSportService {

    // MARK: - Query Ongoing Sport

    func queryOngoingSport() -> Future<BTSportStatus?, Never> {
        return Future { promise in
            BTService.shared().sportReq.queryOngoingSport(completion: { status in
                promise(.success(status))
            })
        }
    }

    // MARK: - Sport Operations

    func startSport(type: SportType) -> Future<SportEvent, Never> {
        return Future { promise in
            let sdkType = BTSportType(rawValue: UInt8(type.rawValue)) ?? .indoorWalk
            let sportID = BTSport.generateId()
            BTService.shared().sportReq.execute(.start, sportWith: sdkType, sportID: sportID) { status in
                if status != nil {
                    promise(.success(.started))
                } else {
                    promise(.success(.failed(RingError.sportOperationFailed)))
                }
            }
        }
    }

    func pauseSport(sportID: Data) {
        BTService.shared().sportReq.execute(.pause, sportWith: .indoorWalk, sportID: sportID) { _ in }
    }

    func resumeSport(sportID: Data) {
        BTService.shared().sportReq.execute(.resume, sportWith: .indoorWalk, sportID: sportID) { _ in }
    }

    func stopSport(sportID: Data) {
        BTService.shared().sportReq.execute(.stop, sportWith: .indoorWalk, sportID: sportID) { _ in }
    }

    func abandonSport(sportID: Data) {
        BTService.shared().sportReq.abandonSport(withSportID: sportID) { _, _ in }
    }

    // MARK: - Real-Time Data

    func requestRealTimeData(sportID: Data) -> Future<SportRealTimeData?, Never> {
        return Future { promise in
            BTService.shared().sportReq.requestRealTimeData(forSport: sportID) { model in
                guard let model = model else {
                    promise(.success(nil))
                    return
                }
                let data = SportRealTimeData(
                    heartRate: Int(model.heartRate),
                    calories: Int(model.calories),
                    steps: Int(model.steps),
                    distance: Int(model.distance),
                    pace: Int(model.pace),
                    cadence: Int(model.cadence),
                    temperature: model.temperature
                )
                promise(.success(data))
            }
        }
    }

    // MARK: - Summary and Detail

    func fetchSummary(sportID: Data) -> Future<SportSummary, Error> {
        return Future { promise in
            BTService.shared().sportReq.requestSummary(sportID) { model in
                guard let model = model else {
                    promise(.failure(RingError.dataFetchFailed))
                    return
                }
                let summary = SportSummary(
                    sportType: SportType(rawValue: Int(model.sportType)) ?? .indoorWalk,
                    duration: Int(model.duration),
                    calories: Int(model.calories),
                    steps: Int(model.steps),
                    distance: Int(model.distance),
                    avgHeartRate: Int(model.avgHr),
                    avgPace: Int(model.avgPace)
                )
                promise(.success(summary))
            }
        }
    }

    func fetchDetail(sportID: Data) -> Future<[SportDetail], Error> {
        return Future { promise in
            BTService.shared().sportReq.requestDetail(sportID) { models in
                guard let models = models else {
                    promise(.failure(RingError.dataFetchFailed))
                    return
                }
                let details: [SportDetail] = models.map { m in
                    SportDetail(
                        sportType: SportType(rawValue: Int(m.sportType)) ?? .indoorWalk,
                        calories: Int(m.calories),
                        steps: Int(m.steps),
                        distance: Int(m.distance),
                        heartRate: Int(m.heartRate),
                        temperature: m.temperature,
                        pace: Int(m.pace),
                        speed: Int(m.speed),
                        cadence: Int(m.cadence)
                    )
                }
                promise(.success(details))
            }
        }
    }
}
