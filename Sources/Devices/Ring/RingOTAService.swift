import Foundation
import Combine
import RingSDK

class RingOTAService {

    private var appName: String = "Vvewell"
    private var authID: String = ""
    private var authKey: String = ""
    private var pendingVersion: OTAVersion?

    // MARK: - Configure

    func configure(appName: String, authID: String, authKey: String) {
        self.appName = appName
        self.authID = authID
        self.authKey = authKey
    }

    // MARK: - Check Update

    func checkUpdate() -> PassthroughSubject<OTAEvent, Never> {
        let subject = PassthroughSubject<OTAEvent, Never>()
        subject.send(.checking)

        BTService.shared().baseReq.fetch(.information) { [weak self] model, _ in
            guard let self = self, let aboutModel = model as? BTAboutModel else {
                subject.send(.failed(RingError.otaCheckFailed))
                subject.send(completion: .finished)
                return
            }

            BTService.shared().checkOTAUpdate(
                with: aboutModel,
                appName: self.appName,
                authenticationID: self.authID,
                authenticationKey: self.authKey
            ) { otaVersion, error in
                if let error = error {
                    subject.send(.failed(error))
                    subject.send(completion: .finished)
                    return
                }

                if otaVersion != nil {
                    self.pendingVersion = otaVersion
                    let info = OTAInfo(
                        currentVersion: aboutModel.softwareVersion,
                        latestVersion: "",
                        fileURL: nil
                    )
                    subject.send(.available(info))
                } else {
                    subject.send(.notAvailable)
                }
                subject.send(completion: .finished)
            }
        }
        return subject
    }

    /// Starts the exact vendor update object returned by the preceding check.
    func startPendingUpgrade() -> PassthroughSubject<OTAEvent, Never> {
        guard let version = pendingVersion else {
            let subject = PassthroughSubject<OTAEvent, Never>()
            subject.send(.failed(RingError.otaUpgradeFailed))
            subject.send(completion: .finished)
            return subject
        }
        pendingVersion = nil
        return startUpgrade(version: version)
    }

    // MARK: - Start Upgrade

    func startUpgrade(version: OTAVersion) -> PassthroughSubject<OTAEvent, Never> {
        let subject = PassthroughSubject<OTAEvent, Never>()
        BTService.shared().startUpgrade(with: version) { status, progress, error in
            switch status {
            case .downloading:
                subject.send(.downloading(progress: progress))
            case .started, .progress:
                subject.send(.installing(progress: progress))
            case .success:
                subject.send(.completed)
                subject.send(completion: .finished)
            case .failed, .notConnected, .fileNotValid:
                subject.send(.failed(error ?? RingError.otaUpgradeFailed))
                subject.send(completion: .finished)
            default:
                break
            }
        }
        return subject
    }

    // MARK: - Upgrade from File

    func startUpgradeFromFile(url: URL) -> PassthroughSubject<OTAEvent, Never> {
        let subject = PassthroughSubject<OTAEvent, Never>()
        BTService.shared().startUpgrade(withFileURL: url) { status, progress, error in
            switch status {
            case .downloading:
                subject.send(.downloading(progress: progress))
            case .started, .progress:
                subject.send(.installing(progress: progress))
            case .success:
                subject.send(.completed)
                subject.send(completion: .finished)
            case .failed, .notConnected, .fileNotValid:
                subject.send(.failed(error ?? RingError.otaUpgradeFailed))
                subject.send(completion: .finished)
            default:
                break
            }
        }
        return subject
    }
}
