import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omi/backend/schema/bt_device/bt_device.dart';
import 'package:omi/models/custom_stt_config.dart';
import 'package:omi/models/stt_provider.dart';
import 'package:omi/services/sockets/composite_transcription_socket.dart';
import 'package:omi/services/sockets/on_device_moonshine_socket.dart';
import 'package:omi/services/sockets/pure_socket.dart';
import 'package:omi/services/sockets/transcription_service.dart';

class _SocketListener implements IPureSocketListener {
  final messages = <dynamic>[];
  var connected = false;
  var closed = false;
  Object? error;

  @override
  void onClosed([int? closeCode]) {
    closed = true;
  }

  @override
  void onConnected() {
    connected = true;
  }

  @override
  void onError(Object err, StackTrace trace) {
    error = err;
  }

  @override
  void onMessage(dynamic message) {
    messages.add(message);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.omi/moonshine_stt');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final nativeCalls = <MethodCall>[];

  setUp(() {
    nativeCalls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      nativeCalls.add(call);
      return switch (call.method) {
        'initialize' => true,
        'appendPcm16' => null,
        'stop' => null,
        'dispose' => null,
        _ => throw MissingPluginException('Unexpected method ${call.method}'),
      };
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('configures Moonshine as a streaming on-device provider', () {
    final config = SttProviderConfig.get(SttProvider.onDeviceMoonshine);

    expect(config.displayName, 'On-Device Moonshine');
    expect(config.requestType, SttRequestType.streaming);
    expect(config.requiresApiKey, isFalse);
    expect(config.supportedModels, [
      'moonshine-streaming-tiny',
      'moonshine-streaming-small',
      'moonshine-streaming-medium',
    ]);
    expect(config.defaultModel, 'moonshine-streaming-tiny');
  });

  test('connects, appends PCM16, forwards native transcript segments, and stops', () async {
    final socket = OnDeviceMoonshineSocket(
      model: 'moonshine-streaming-small',
      language: 'en',
      sampleRate: 16000,
      sourceCodec: BleAudioCodec.pcm16,
    );
    final listener = _SocketListener();
    socket.setListener(listener);

    expect(await socket.connect(), isTrue);
    expect(socket.status, PureSocketStatus.connected);
    expect(listener.connected, isTrue);
    expect(nativeCalls.single.method, 'initialize');
    expect(nativeCalls.single.arguments, {'model': 'moonshine-streaming-small', 'language': 'en', 'sampleRate': 16000});

    final pcm = Uint8List.fromList([1, 2, 3, 4]);
    socket.send(pcm);
    expect(nativeCalls.last.method, 'appendPcm16');
    expect(nativeCalls.last.arguments, {'pcm16': pcm});

    await _invokeNativeCallback(channel, 'onTranscript', {
      'text': 'hello moonshine',
      'start': 1.25,
      'end': 2.5,
      'isFinal': true,
    });

    expect(listener.messages, hasLength(1));
    final segments = jsonDecode(listener.messages.single as String) as List<dynamic>;
    final segment = Map<String, dynamic>.from(segments.single as Map);
    expect(segment.remove('id'), startsWith('moonshine_'));
    expect(segment, {
      'text': 'hello moonshine',
      'speaker': 'SPEAKER_0',
      'speaker_id': 0,
      'is_user': false,
      'start': 1.25,
      'end': 2.5,
      'person_id': null,
      'stt_provider': 'onDeviceMoonshine',
    });

    await socket.stop();
    expect(socket.status, PureSocketStatus.disconnected);
    expect(listener.closed, isTrue);
    expect(nativeCalls.map((call) => call.method), containsAllInOrder(['initialize', 'appendPcm16', 'stop']));
  });

  test('partials reuse one segment id; a completed line starts a new id', () async {
    final socket = OnDeviceMoonshineSocket(
      model: 'moonshine-streaming-tiny',
      language: 'en',
      sampleRate: 16000,
      sourceCodec: BleAudioCodec.pcm16,
    );
    final listener = _SocketListener();
    socket.setListener(listener);
    expect(await socket.connect(), isTrue);

    Future<void> emit(String text, bool isFinal) =>
        _invokeNativeCallback(channel, 'onTranscript', {'text': text, 'start': 0.0, 'end': 1.0, 'isFinal': isFinal});

    await emit('hello', false);
    await emit('hello world', false);
    await emit('hello world', true);
    await emit('next line', false);

    final ids =
        listener.messages.map((m) => (jsonDecode(m as String) as List<dynamic>).single['id'] as String).toList();
    expect(ids, hasLength(4));
    expect(ids[1], ids[0]); // partial updates the same segment in place
    expect(ids[2], ids[0]); // final sticks with the same segment
    expect(ids[3], isNot(ids[0])); // next line appends as a new segment
  });

  test('factory returns Moonshine socket directly without the cloud composite wrapper', () {
    const config = CustomSttConfig(
      provider: SttProvider.onDeviceMoonshine,
      language: 'en',
      model: 'moonshine-streaming-tiny',
    );

    final service = TranscriptSocketServiceFactory.createFromCustomConfig(16000, BleAudioCodec.pcm16, 'en', config);

    expect(service.socket, isA<OnDeviceMoonshineSocket>());
    expect(service.socket, isNot(isA<CompositeTranscriptionSocket>()));
    expect(service.customSttMode, isTrue);
    expect(service.sttConfigId, startsWith('onDeviceMoonshine:'));
  });
}

Future<void> _invokeNativeCallback(MethodChannel channel, String method, Object? arguments) {
  final completer = Completer<void>();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    channel.name,
    channel.codec.encodeMethodCall(MethodCall(method, arguments)),
    (_) => completer.complete(),
  );
  return completer.future;
}
