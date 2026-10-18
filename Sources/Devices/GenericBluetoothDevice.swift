import Combine
import CoreBluetooth
import Foundation

/// CoreBluetooth transport for the documented Android Robot and JDY-23
/// profiles. It deliberately exposes only the operations present in the
/// Android bridge; no vendor-specific health values are fabricated.
final class GenericBluetoothDevice: NSObject, HealthDeviceProtocol, CBCentralManagerDelegate, CBPeripheralDelegate {
    let deviceType: DeviceType
    private let serviceUUID: CBUUID
    private let writeUUID: CBUUID
    private let notifyUUID: CBUUID
    private let nameFilter: (String) -> Bool

    private let stateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    private let infoSubject = CurrentValueSubject<DeviceInfo?, Never>(nil)
    private let batterySubject = CurrentValueSubject<Int?, Never>(nil)
    private let discoveriesSubject = CurrentValueSubject<[DiscoveredDevice], Never>([])
    private var central: CBCentralManager!
    private var scanTimer: Timer?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private weak var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var pendingWrites: [Data] = []
    private var isWritingWithResponse = false
    private var receiveBuffer = Data()

    var connectionState: AnyPublisher<ConnectionState, Never> { stateSubject.eraseToAnyPublisher() }
    var deviceInfo: AnyPublisher<DeviceInfo?, Never> { infoSubject.eraseToAnyPublisher() }
    var batteryLevel: AnyPublisher<Int?, Never> { batterySubject.eraseToAnyPublisher() }

    init(
        type: DeviceType,
        serviceUUID: String,
        writeUUID: String,
        notifyUUID: String,
        nameFilter: @escaping (String) -> Bool
    ) {
        self.deviceType = type
        self.serviceUUID = CBUUID(string: serviceUUID)
        self.writeUUID = CBUUID(string: writeUUID)
        self.notifyUUID = CBUUID(string: notifyUUID)
        self.nameFilter = nameFilter
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func scan() -> AnyPublisher<[DiscoveredDevice], Never> {
        stopScan()
        discoveriesSubject.send([])
        guard central.state == .poweredOn else { return discoveriesSubject.eraseToAnyPublisher() }
        central.scanForPeripherals(withServices: [serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        scanTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in self?.stopScan() }
        return discoveriesSubject.eraseToAnyPublisher()
    }

    func stopScan() {
        scanTimer?.invalidate()
        scanTimer = nil
        central?.stopScan()
    }

    func connect(device: DiscoveredDevice) {
        let restored = UUID(uuidString: device.uuid).flatMap { peripherals[$0] }
        guard let peripheral = (device.rawDevice as? CBPeripheral) ?? restored else {
            stateSubject.send(.authFailed(reason: "The device is no longer in Bluetooth range"))
            return
        }
        stopScan()
        disconnect()
        connectedPeripheral = peripheral
        stateSubject.send(.connecting)
        central.connect(peripheral, options: nil)
    }

    func disconnect() {
        guard let peripheral = connectedPeripheral else {
            stateSubject.send(.disconnected)
            return
        }
        central.cancelPeripheralConnection(peripheral)
        connectedPeripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        pendingWrites.removeAll()
        isWritingWithResponse = false
        receiveBuffer.removeAll(keepingCapacity: true)
        stateSubject.send(.disconnected)
        infoSubject.send(nil)
    }

    func isConnected() -> Bool { stateSubject.value == .connected || stateSubject.value == .authSuccess }
    func isPaired() -> Bool { connectedPeripheral != nil }

    /// Robot commands use UTF-8 JSON lines, matching RobotFlutterBridge.
    func send(payload: String, withoutResponse: Bool = true) {
        let data = Data((payload.hasSuffix("\n") ? payload : payload + "\n").utf8)
        send(data: data, withoutResponse: withoutResponse)
    }

    func sendCommand(_ command: String, values: [String: Any] = [:]) {
        var object: [String: Any] = ["cmd": command]
        values.forEach { object[$0.key] = $0.value }
        guard JSONSerialization.isValidJSONObject(object), let data = try? JSONSerialization.data(withJSONObject: object), let json = String(data: data, encoding: .utf8) else { return }
        send(payload: json)
    }

    // MARK: - Source-owned JDY-23 / VitalBridge protocol

    /// Mirrors Android HifProtocol.wakeup(): 55 FF 55 FF.
    func radarWakeup() { send(data: Data([0x55, 0xff, 0x55, 0xff]), withoutResponse: false, maxChunkBytes: 20) }
    func radarStart() { sendRadarHIF(messageID: 0x07, payload: Data([0x01])) }
    func radarStop() { sendRadarHIF(messageID: 0x07, payload: Data([0x00])) }
    func radarQueryVitalConfig() { sendRadarHIF(messageID: 0x90, payload: Data([0x02])) }
    func radarSelectAutomaticBin() { sendRadarHIF(messageID: 0x90, payload: Data([0x03])) }

    func radarConfigureVital(outputFlags: UInt8, manualBin: Bool, selectedBin: UInt16, minBin: UInt16, maxBin: UInt16) {
        var payload = Data([0x01, outputFlags, manualBin ? 0x01 : 0x00])
        [selectedBin, minBin, maxBin].forEach { value in
            payload.append(UInt8(value & 0xff))
            payload.append(UInt8((value >> 8) & 0xff))
        }
        sendRadarHIF(messageID: 0x90, payload: payload)
    }

    func sendRadarHIF(messageID: UInt8, payload: Data) {
        guard payload.count <= 0x0fff else { return }
        var headerWord: UInt32 = 1
        headerWord |= UInt32(0x05) << 2 // to-device + need-ack + Check32
        headerWord |= UInt32(messageID) << 8
        headerWord |= UInt32(payload.count) << 16
        let header = littleEndianData(headerWord)
        let check8Sum = (0xa5 + header.reduce(0) { $0 + Int($1) }) & 0xff
        let check8 = UInt8((0xff - check8Sum) & 0xff)
        let checksum = ~checksum32(header + payload)
        var packet = Data([0xa5, check8])
        packet.append(header)
        packet.append(payload)
        packet.append(littleEndianData(checksum))
        send(data: packet, withoutResponse: false, maxChunkBytes: 20)
    }

    private func send(data: Data, withoutResponse: Bool, maxChunkBytes: Int? = nil) {
        guard let peripheral = connectedPeripheral, let characteristic = writeCharacteristic else { return }
        let supportsUnacknowledged = withoutResponse && characteristic.properties.contains(.writeWithoutResponse)
        let type: CBCharacteristicWriteType = supportsUnacknowledged ? .withoutResponse : .withResponse
        let systemLimit = peripheral.maximumWriteValueLength(for: type)
        let chunkSize = max(1, min(maxChunkBytes ?? systemLimit, systemLimit))
        let chunks = stride(from: 0, to: data.count, by: chunkSize).map { offset in
            data.subdata(in: offset..<min(offset + chunkSize, data.count))
        }
        if type == .withoutResponse {
            chunks.forEach { peripheral.writeValue($0, for: characteristic, type: type) }
        } else {
            pendingWrites.append(contentsOf: chunks)
            pumpWriteQueue(peripheral: peripheral, characteristic: characteristic)
        }
    }

    private func pumpWriteQueue(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        guard !isWritingWithResponse, !pendingWrites.isEmpty else { return }
        isWritingWithResponse = true
        peripheral.writeValue(pendingWrites.removeFirst(), for: characteristic, type: .withResponse)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            stateSubject.send(.disconnected)
            discoveriesSubject.send([])
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let advertised = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? ""
        guard nameFilter(advertised) else { return }
        peripherals[peripheral.identifier] = peripheral
        discoveriesSubject.send(peripherals.values.compactMap { candidate in
            let name = candidate.identifier == peripheral.identifier ? advertised : (candidate.name ?? advertised)
            guard nameFilter(name) else { return nil }
            return DiscoveredDevice(uuid: candidate.identifier.uuidString, name: name, macAddress: candidate.identifier.uuidString, rssi: candidate.identifier == peripheral.identifier ? RSSI.intValue : -127, deviceType: deviceType, rawDevice: candidate)
        }.sorted { $0.rssi > $1.rssi })
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        stateSubject.send(.authFailed(reason: error?.localizedDescription ?? "Bluetooth connection failed"))
        stateSubject.send(.disconnected)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard connectedPeripheral?.identifier == peripheral.identifier else { return }
        connectedPeripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        pendingWrites.removeAll()
        isWritingWithResponse = false
        stateSubject.send(.disconnected)
        infoSubject.send(nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            stateSubject.send(.authFailed(reason: error?.localizedDescription ?? "BLE service unavailable"))
            disconnect()
            return
        }
        peripheral.discoverCharacteristics([writeUUID, notifyUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else { stateSubject.send(.authFailed(reason: error!.localizedDescription)); disconnect(); return }
        writeCharacteristic = service.characteristics?.first(where: { $0.uuid == writeUUID })
        notifyCharacteristic = service.characteristics?.first(where: { $0.uuid == notifyUUID })
        guard writeCharacteristic != nil else { stateSubject.send(.authFailed(reason: "BLE write characteristic unavailable")); disconnect(); return }
        if let notifyCharacteristic, notifyCharacteristic.properties.contains(.notify) || notifyCharacteristic.properties.contains(.indicate) {
            peripheral.setNotifyValue(true, for: notifyCharacteristic)
        } else {
            markReady(peripheral)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if error == nil { markReady(peripheral) } else { stateSubject.send(.authFailed(reason: error!.localizedDescription)); disconnect() }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        NotificationCenter.default.post(name: .genericBluetoothPayloadReceived, object: self, userInfo: ["data": data])
        if deviceType == .radar { consumeRadarBytes(data) }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        isWritingWithResponse = false
        if let error {
            pendingWrites.removeAll()
            NotificationCenter.default.post(name: .genericBluetoothTransportError, object: self, userInfo: ["message": error.localizedDescription])
            return
        }
        pumpWriteQueue(peripheral: peripheral, characteristic: characteristic)
    }

    private func markReady(_ peripheral: CBPeripheral) {
        stateSubject.send(.authSuccess)
        stateSubject.send(.connected)
        infoSubject.send(DeviceInfo(name: peripheral.name ?? "", macAddress: peripheral.identifier.uuidString, firmwareVersion: "", hardwareVersion: "", serialNumber: ""))
    }

    private func consumeRadarBytes(_ data: Data) {
        receiveBuffer.append(data)
        while receiveBuffer.count >= 10 {
            guard let magicIndex = receiveBuffer.firstIndex(of: 0xa5) else {
                receiveBuffer.removeAll(keepingCapacity: true)
                return
            }
            if magicIndex > receiveBuffer.startIndex { receiveBuffer.removeSubrange(receiveBuffer.startIndex..<magicIndex) }
            guard receiveBuffer.count >= 10 else { return }
            let header = receiveBuffer.subdata(in: 2..<6)
            let check8Sum = (0xa5 + Int(receiveBuffer[1]) + header.reduce(0) { $0 + Int($1) }) & 0xff
            guard check8Sum == 0xff else {
                receiveBuffer.removeFirst()
                continue
            }
            let word = uint32LE(header)
            let payloadLength = Int((word >> 16) & 0x0fff)
            let packetLength = 2 + 4 + payloadLength + 4
            guard receiveBuffer.count >= packetLength else { return }
            let payload = receiveBuffer.subdata(in: 6..<(6 + payloadLength))
            let expectedChecksum = uint32LE(receiveBuffer.subdata(in: (6 + payloadLength)..<packetLength))
            guard checksum32(header + payload) &+ expectedChecksum == UInt32.max else {
                receiveBuffer.removeFirst()
                continue
            }
            let messageID = UInt8((word >> 8) & 0xff)
            NotificationCenter.default.post(name: .radarHIFFrameReceived, object: self, userInfo: [
                "messageID": Int(messageID),
                "payload": payload,
            ])
            receiveBuffer.removeFirst(packetLength)
        }
    }

    private func checksum32(_ data: Data) -> UInt32 {
        var sum: UInt32 = 0
        var offset = 0
        while offset < data.count {
            var word: UInt32 = 0
            for byteOffset in 0..<min(4, data.count - offset) {
                word |= UInt32(data[offset + byteOffset]) << UInt32(byteOffset * 8)
            }
            sum = sum &+ word
            offset += 4
        }
        return sum
    }

    private func littleEndianData(_ value: UInt32) -> Data {
        Data([UInt8(value & 0xff), UInt8((value >> 8) & 0xff), UInt8((value >> 16) & 0xff), UInt8((value >> 24) & 0xff)])
    }

    private func uint32LE(_ data: Data) -> UInt32 {
        guard data.count >= 4 else { return 0 }
        return UInt32(data[0]) | (UInt32(data[1]) << 8) | (UInt32(data[2]) << 16) | (UInt32(data[3]) << 24)
    }
}

extension Notification.Name {
    static let genericBluetoothPayloadReceived = Notification.Name("genericBluetoothPayloadReceived")
    static let genericBluetoothTransportError = Notification.Name("genericBluetoothTransportError")
    static let radarHIFFrameReceived = Notification.Name("radarHIFFrameReceived")
}

enum GenericBluetoothFactory {
    static func robot() -> GenericBluetoothDevice {
        GenericBluetoothDevice(type: .robot, serviceUUID: "D6F00001-9A1A-4F8D-A7FD-2E3B2E819001", writeUUID: "D6F00002-9A1A-4F8D-A7FD-2E3B2E819001", notifyUUID: "D6F00003-9A1A-4F8D-A7FD-2E3B2E819001") { name in
            name.lowercased().hasPrefix("vvewell")
        }
    }

    static func radar() -> GenericBluetoothDevice {
        GenericBluetoothDevice(type: .radar, serviceUUID: "0000FFE0-0000-1000-8000-00805F9B34FB", writeUUID: "0000FFE1-0000-1000-8000-00805F9B34FB", notifyUUID: "0000FFE1-0000-1000-8000-00805F9B34FB") { name in
            name.caseInsensitiveCompare("JDY-23") == .orderedSame
        }
    }
}
