import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'package:omi/backend/schema/bt_device/bt_device.dart';
import 'package:omi/services/sockets/pure_socket.dart';
import 'package:omi/utils/audio/audio_transcoder.dart';
import 'package:omi/utils/debug_log_manager.dart';
import 'package:omi/utils/logger.dart';

class OnDeviceMoonshineSocket implements IPureSocket {
  static const MethodChannel _channel = MethodChannel('com.omi/moonshine_stt');

  final String model;
  final String language;
  final int sampleRate;
  final int revisionWindowMs;
  final IAudioTranscoder transcoder;

  PureSocketStatus _status = PureSocketStatus.notConnected;
  IPureSocketListener? _listener;

  // Stable per-line segment ids: partial hypotheses for the current line reuse
  // the same id (so they update one segment in place), and a completed line
  // bumps the index so the next line appends as a new segment. The nonce keeps
  // ids from colliding across socket instances within one conversation.
  final String _idNonce = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  int _lineIndex = 0;

  OnDeviceMoonshineSocket({
    required this.model,
    required this.language,
    required this.sampleRate,
    this.revisionWindowMs = 0,
    required BleAudioCodec sourceCodec,
  }) : transcoder = AudioTranscoderFactory.createToRawPcm(sourceCodec: sourceCodec, sampleRate: sampleRate) {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  @override
  PureSocketStatus get status => _status;

  @override
  void setListener(IPureSocketListener listener) {
    _listener = listener;
  }

  @override
  Future<bool> connect() async {
    if (_status == PureSocketStatus.connecting || _status == PureSocketStatus.connected) {
      return false;
    }

    _status = PureSocketStatus.connecting;
    try {
      final args = <String, dynamic>{
        'model': model,
        'language': language,
        'sampleRate': sampleRate,
        if (revisionWindowMs > 0) 'revisionWindowMs': revisionWindowMs,
      };
      final initialized = await _channel.invokeMethod<bool>('initialize', args);
      if (initialized != true) {
        _status = PureSocketStatus.notConnected;
        return false;
      }
      _status = PureSocketStatus.connected;
      onConnected();
      return true;
    } catch (e, trace) {
      _status = PureSocketStatus.notConnected;
      Logger.handle(e, trace, message: 'Moonshine socket initialize failed');
      await DebugLogManager.logError(e, trace, 'moonshine_socket_initialize_failed');
      onError(e, trace);
      return false;
    }
  }

  @override
  void send(dynamic message) {
    if (_status != PureSocketStatus.connected) {
      return;
    }

    Uint8List audioData;
    if (message is Uint8List) {
      audioData = message;
    } else if (message is List<int>) {
      audioData = Uint8List.fromList(message);
    } else {
      Logger.warning('[MoonshineSocket] Unsupported message type: ${message.runtimeType}');
      return;
    }

    final pcm16 = transcoder.transcodeFrames([audioData]);
    _channel.invokeMethod<void>('appendPcm16', {'pcm16': pcm16});
  }

  @override
  Future disconnect() async {
    if (_status == PureSocketStatus.connected || _status == PureSocketStatus.connecting) {
      await _channel.invokeMethod<void>('stop');
    }
    _status = PureSocketStatus.disconnected;
    onClosed();
  }

  @override
  Future stop() async {
    await disconnect();
  }

  @override
  void onMessage(dynamic message) {
    _listener?.onMessage(message);
  }

  @override
  void onConnected() {
    _listener?.onConnected();
  }

  @override
  void onClosed([int? closeCode]) {
    _listener?.onClosed(closeCode);
  }

  @override
  void onError(Object err, StackTrace trace) {
    _listener?.onError(err, trace);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onTranscript':
        _handleTranscript(call.arguments);
        return null;
      case 'onError':
        final error = Exception(call.arguments?.toString() ?? 'Moonshine native error');
        onError(error, StackTrace.current);
        return null;
      case 'onClosed':
        _status = PureSocketStatus.disconnected;
        onClosed();
        return null;
      default:
        Logger.warning('[MoonshineSocket] Unknown native callback: ${call.method}');
        return null;
    }
  }

  void _handleTranscript(dynamic arguments) {
    if (_status != PureSocketStatus.connected || arguments is! Map) {
      return;
    }

    final text = arguments['text']?.toString().trim();
    if (text == null || text.isEmpty) {
      return;
    }

    final isFinal = arguments['isFinal'] == true;
    final segment = {
      'id': 'moonshine_${_idNonce}_$_lineIndex',
      'text': text,
      'speaker': 'SPEAKER_0',
      'speaker_id': 0,
      'is_user': false,
      'start': _asDouble(arguments['start']),
      'end': _asDouble(arguments['end']),
      'person_id': null,
      'stt_provider': 'onDeviceMoonshine',
    };
    if (isFinal) {
      _lineIndex++;
    }
    onMessage(jsonEncode([segment]));
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
