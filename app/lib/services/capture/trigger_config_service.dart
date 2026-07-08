import 'dart:async';

import 'package:flutter/services.dart';

class BtDevice {
  const BtDevice({
    required this.mac,
    required this.name,
    required this.kind,
    required this.lastSeenMs,
    required this.enabled,
  });

  final String mac;
  final String name;
  final String kind;
  final int lastSeenMs;
  final bool enabled;

  factory BtDevice.fromMap(Map<dynamic, dynamic> map) {
    return BtDevice(
      mac: map['mac']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      kind: map['kind']?.toString() ?? '',
      lastSeenMs: _asInt(map['lastSeenMs']),
      enabled: map['enabled'] == true,
    );
  }
}

class ButtonMapping {
  const ButtonMapping({
    this.id,
    this.deviceMac,
    required this.eventKey,
    required this.action,
    this.attribution,
    this.createdMs,
  });

  final int? id;
  final String? deviceMac;
  final String eventKey;
  final String action;
  final String? attribution;
  final int? createdMs;

  factory ButtonMapping.fromMap(Map<dynamic, dynamic> map) {
    return ButtonMapping(
      id: _nullableInt(map['id']),
      deviceMac: map['deviceMac']?.toString(),
      eventKey: map['eventKey']?.toString() ?? '',
      action: map['action']?.toString() ?? '',
      attribution: map['attribution']?.toString(),
      createdMs: _nullableInt(map['createdMs']),
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      if (deviceMac != null) 'deviceMac': deviceMac,
      'eventKey': eventKey,
      'action': action,
      if (attribution != null) 'attribution': attribution,
      if (createdMs != null) 'createdMs': createdMs,
    };
  }
}

class BtLearnEvent {
  const BtLearnEvent({
    required this.eventKey,
    this.deviceMac,
    required this.attribution,
  });

  final String eventKey;
  final String? deviceMac;
  final String attribution;

  factory BtLearnEvent.fromMap(Map<dynamic, dynamic> map) {
    return BtLearnEvent(
      eventKey: map['eventKey']?.toString() ?? '',
      deviceMac: map['deviceMac']?.toString(),
      attribution: map['attribution']?.toString() ?? 'AMBIGUOUS',
    );
  }
}

class TriggerConfigService {
  TriggerConfigService({MethodChannel? channel}) : _channel = channel ?? const MethodChannel(_channelName) {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const _channelName = 'com.friend.ios/trigger_config';

  final MethodChannel _channel;
  final StreamController<BtLearnEvent> _learnEvents = StreamController<BtLearnEvent>.broadcast();

  Stream<BtLearnEvent> get learnEvents => _learnEvents.stream;

  Future<List<BtDevice>> listDevices() async {
    final rawDevices = await _channel.invokeListMethod<dynamic>('listDevices') ?? const [];
    return rawDevices.whereType<Map<dynamic, dynamic>>().map(BtDevice.fromMap).toList();
  }

  Future<void> setDeviceEnabled(String mac, bool enabled) async {
    await _channel.invokeMethod<bool>('setDeviceEnabled', {'mac': mac, 'enabled': enabled});
  }

  Future<List<ButtonMapping>> listMappings() async {
    final rawMappings = await _channel.invokeListMethod<dynamic>('listMappings') ?? const [];
    return rawMappings.whereType<Map<dynamic, dynamic>>().map(ButtonMapping.fromMap).toList();
  }

  Future<int> upsertMapping(ButtonMapping mapping) async {
    final id = await _channel.invokeMethod<dynamic>('upsertMapping', mapping.toMap());
    return _asInt(id);
  }

  Future<void> deleteMapping(int id) async {
    await _channel.invokeMethod<bool>('deleteMapping', {'id': id});
  }

  Future<void> startLearnMode() async {
    await _channel.invokeMethod<bool>('startLearnMode');
  }

  Future<void> stopLearnMode() async {
    await _channel.invokeMethod<bool>('stopLearnMode');
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'onLearnEvent') return;
    final args = call.arguments;
    if (args is Map<dynamic, dynamic>) {
      _learnEvents.add(BtLearnEvent.fromMap(args));
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _learnEvents.close();
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  return _asInt(value);
}
