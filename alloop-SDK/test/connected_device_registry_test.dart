import 'package:alloop/features/aizoring/domain/models/smart_ring_device.dart';
import 'package:alloop/features/aizoring/domain/models/smart_ring_type.dart';
import 'package:alloop/features/scan/data/connected_device_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final registry = ConnectedDeviceRegistry.instance;

  setUp(registry.resetForTest);
  tearDown(registry.resetForTest);

  test('retains connected devices from independent transports', () {
    registry.markConnected(
      const SmartRingDevice(
        id: 'AA:01',
        name: 'AIZORING',
        rssi: -45,
        type: SmartRingType.aizoring,
      ),
    );
    registry.markConnected(
      const SmartRingDevice(
        id: 'rokid-glasses',
        name: 'Rokid AI 眼镜',
        rssi: 0,
        type: SmartRingType.glasses,
      ),
    );

    expect(registry.devices, hasLength(2));
    expect(
      registry.devices.map((device) => device.type),
      containsAll([SmartRingType.aizoring, SmartRingType.glasses]),
    );
  });

  test('disconnecting one transport does not remove other devices', () {
    registry.markConnected(
      const SmartRingDevice(
        id: 'shared-id',
        name: '小智',
        rssi: -55,
        type: SmartRingType.xiaozhi,
      ),
    );
    registry.markConnected(
      const SmartRingDevice(
        id: 'shared-id',
        name: '毫米波雷达',
        rssi: -60,
        type: SmartRingType.radar,
      ),
    );

    registry.markDisconnected(SmartRingType.xiaozhi, deviceId: 'shared-id');

    expect(registry.devices, hasLength(1));
    expect(registry.devices.single.type, SmartRingType.radar);
  });
}
