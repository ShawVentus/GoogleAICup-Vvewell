import 'package:alloop/features/aizoring/domain/models/smart_ring_type.dart';
import 'package:alloop/features/robot/data/robot_ble_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('alloop/robot_ble');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('keeps devices identified by the native robot scanner', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'scan');
          return [
            {
              'address': 'AA:BB:CC:DD:EE:FF',
              // The K3 service UUID, not its local name, is the native
              // scanner's authoritative robot identifier.
              'name': 'ESP32',
              'rssi': -55,
            },
          ];
        });

    final devices = await RobotBleRepository().scan();

    expect(devices, hasLength(1));
    expect(devices.single.name, 'ESP32');
    expect(devices.single.type, SmartRingType.robot);
  });
}
