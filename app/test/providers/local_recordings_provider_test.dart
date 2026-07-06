import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omi/backend/preferences.dart';
import 'package:omi/backend/schema/transcript_segment.dart';
import 'package:omi/providers/local_recordings_provider.dart';

TranscriptSegment _segment(String id, String text, double start, double end) {
  return TranscriptSegment(
    id: id,
    text: text,
    speaker: 'SPEAKER_00',
    isUser: false,
    personId: null,
    start: start,
    end: end,
    translations: [],
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('local_recordings_provider_test');
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesUtil.init();
    await SharedPreferencesUtil().saveString('batchAudioDir', tempDir.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') return tempDir.path;
        return null;
      },
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('loads persisted transcript-only sessions as local recordings', () async {
    await LocalRecordingsProvider.persistTranscriptSession(
      sessionStartSeconds: 1234567890,
      segments: [_segment('seg-1', 'hello local transcript', 0.0, 2.4)],
    );

    final provider = LocalRecordingsProvider();
    addTearDown(provider.dispose);
    await provider.refresh();

    expect(provider.recordings, hasLength(1));
    final recording = provider.recordings.single;
    expect(recording.hasAudio, false);
    expect(recording.hasTranscript, true);
    expect(recording.startedAt, DateTime.fromMillisecondsSinceEpoch(1234567890 * 1000));
    expect(recording.seconds, 3);
    expect(recording.transcriptSegments.single.id, 'seg-1');
    expect(recording.transcriptSegments.single.text, 'hello local transcript');
  });
}
