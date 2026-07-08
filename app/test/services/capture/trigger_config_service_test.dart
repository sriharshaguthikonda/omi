import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omi/services/capture/trigger_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.friend.ios/trigger_config');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('lists devices and mappings from native maps', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'listDevices':
          return [
            {
              'mac': 'AA:BB',
              'name': 'Headset',
              'kind': 'HEADSET',
              'lastSeenMs': 123,
              'enabled': true,
            }
          ];
        case 'listMappings':
          return [
            {
              'id': 7,
              'deviceMac': 'AA:BB',
              'eventKey': 'KEYCODE_MEDIA_PLAY_PAUSE',
              'action': 'toggle',
              'attribution': 'CONFIRMED',
              'createdMs': 456,
            }
          ];
      }
      fail('Unexpected method ${call.method}');
    });

    final service = TriggerConfigService();

    final devices = await service.listDevices();
    final mappings = await service.listMappings();

    expect(devices.single.mac, 'AA:BB');
    expect(devices.single.name, 'Headset');
    expect(devices.single.enabled, isTrue);
    expect(mappings.single.id, 7);
    expect(mappings.single.eventKey, 'KEYCODE_MEDIA_PLAY_PAUSE');
    expect(mappings.single.action, 'toggle');
  });

  test('upserts and deletes mappings with native channel args', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'upsertMapping') return 42;
      if (call.method == 'deleteMapping') return true;
      fail('Unexpected method ${call.method}');
    });

    final service = TriggerConfigService();
    final id = await service.upsertMapping(
      const ButtonMapping(
        id: 5,
        deviceMac: 'AA:BB',
        eventKey: 'KEYCODE_HEADSETHOOK',
        action: 'start',
        attribution: 'INFERRED',
        createdMs: 99,
      ),
    );
    await service.deleteMapping(42);

    expect(id, 42);
    expect(calls.first.method, 'upsertMapping');
    expect(calls.first.arguments, {
      'id': 5,
      'deviceMac': 'AA:BB',
      'eventKey': 'KEYCODE_HEADSETHOOK',
      'action': 'start',
      'attribution': 'INFERRED',
      'createdMs': 99,
    });
    expect(calls.last.method, 'deleteMapping');
    expect(calls.last.arguments, {'id': 42});
  });

  test('emits learn events from native callback stream', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => true);
    final service = TriggerConfigService();

    final nextEvent = expectLater(
      service.learnEvents,
      emits(
        isA<BtLearnEvent>()
            .having((event) => event.eventKey, 'eventKey', 'KEYCODE_MEDIA_NEXT')
            .having((event) => event.deviceMac, 'deviceMac', 'AA:BB')
            .having((event) => event.attribution, 'attribution', 'AMBIGUOUS'),
      ),
    );

    await _invokeNativeCallback(channel, 'onLearnEvent', {
      'eventKey': 'KEYCODE_MEDIA_NEXT',
      'deviceMac': 'AA:BB',
      'attribution': 'AMBIGUOUS',
    });

    await nextEvent;
    service.dispose();
  });
}

Future<void> _invokeNativeCallback(MethodChannel channel, String method, Object? arguments) {
  final codec = channel.codec;
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    channel.name,
    codec.encodeMethodCall(MethodCall(method, arguments)),
    (_) {},
  );
}
