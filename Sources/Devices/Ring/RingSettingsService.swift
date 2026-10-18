import Foundation
import Combine
import RingSDK

class RingSettingsService {

    // MARK: - Device Features

    func fetchFeatures() -> Future<BTFeatureModel, Error> {
        return Future { promise in
            BTService.shared().baseReq.fetch(.features) { model, _ in
                guard let featureModel = model as? BTFeatureModel else {
                    promise(.failure(RingError.dataFetchFailed))
                    return
                }
                promise(.success(featureModel))
            }
        }
    }

    // MARK: - User Preferences

    func sendUserPrefs(height: UInt8, weight: UInt8, gender: UInt8, age: UInt8) -> Future<Bool, Never> {
        return Future { promise in
            let prefs = BTUserPrefs()
            prefs.height = height
            prefs.weight = weight
            prefs.gender = gender
            prefs.age = age
            BTService.shared().baseReq.sendSettings(prefs) { success in
                promise(.success(success))
            }
        }
    }

    // MARK: - Device Name

    func setDeviceName(_ name: String) -> Future<Bool, Never> {
        return Future { promise in
            var bytes = Array(name.utf8)
            BTService.shared().baseReq.setDeviceName(&bytes) { success in
                promise(.success(success))
            }
        }
    }

    // MARK: - Measurement Interval

    func queryMeasurementInterval() -> Future<BTIntervalModel, Error> {
        return Future { promise in
            BTService.shared().baseReq.queryMeasurementInterval { success, model in
                if success, let model = model {
                    promise(.success(model))
                } else {
                    promise(.failure(RingError.dataFetchFailed))
                }
            }
        }
    }

    func setMeasurementInterval(_ interval: Int) -> Future<Bool, Never> {
        return Future { promise in
            BTService.shared().baseReq.setDeviceMeasureTime(interval) { success in
                promise(.success(success))
            }
        }
    }

    // MARK: - Alarms

    func fetchAlarms(timestamp: Data) -> Future<[BTAlarm], Error> {
        return Future { promise in
            BTService.shared().vibrationReq.fetchAlarms(withTimestamp: timestamp) { alarms, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(alarms ?? []))
                }
            }
        }
    }

    func setAlarm(_ alarm: BTAlarm, timestamp: Data) -> Future<Bool, Never> {
        return Future { promise in
            BTService.shared().vibrationReq.setAlarm(alarm, timestamp: timestamp) { success, _ in
                promise(.success(success))
            }
        }
    }

    // MARK: - Vibration

    func sendVibration(type: BTVibrationType) -> Future<Bool, Never> {
        return Future { promise in
            BTService.shared().vibrationReq.send(with: type) { success in
                promise(.success(success))
            }
        }
    }

    func sendVibrationSwitchSettings(_ switches: [BTVibrationSwitch]) -> Future<Bool, Never> {
        return Future { promise in
            BTService.shared().vibrationReq.sendSwitchSettings(switches) { success in
                promise(.success(success))
            }
        }
    }

    func queryVibrationSwitchSettings(type: BTVibrationType, isAll: Bool) -> Future<[BTVibrationSwitch], Never> {
        return Future { promise in
            BTService.shared().vibrationReq.queryVibrationSwitchSettings(type, isAll: isAll) { switches in
                promise(.success(switches ?? []))
            }
        }
    }

    func setVibrationMode(_ config: BTVibrationConfigModel) -> Future<Bool, Never> {
        return Future { promise in
            BTService.shared().vibrationConfigReq.setVibrationModeConfiguration(config) { success in
                promise(.success(success))
            }
        }
    }

    // MARK: - Touch

    func fetchTouchState() -> Future<BTTouchModel?, Never> {
        return Future { promise in
            BTService.shared().touchReq.fetchState { model in
                promise(.success(model))
            }
        }
    }

    func updateTouchState(_ state: BTTouchModel) -> Future<Bool, Never> {
        return Future { promise in
            BTService.shared().touchReq.updateState(state) { success in
                promise(.success(success))
            }
        }
    }

    // MARK: - SOS

    func fetchSOSState() -> Future<BTSOSStateModel?, Never> {
        return Future { promise in
            BTService.shared().sosReq.fetchState { model in
                promise(.success(model))
            }
        }
    }

    func updateSOSState(_ state: BTSOSStateModel) -> Future<Bool, Never> {
        return Future { promise in
            BTService.shared().sosReq.updateState(state) { success in
                promise(.success(success))
            }
        }
    }

    // MARK: - Device Operations

    func resetDevice() -> Future<Void, Never> {
        return Future { promise in
            BTService.shared().baseReq.execute(.reset) {
                promise(.success(()))
            }
        }
    }

    func restartDevice() -> Future<Void, Never> {
        return Future { promise in
            BTService.shared().baseReq.execute(.restart) {
                promise(.success(()))
            }
        }
    }
}
