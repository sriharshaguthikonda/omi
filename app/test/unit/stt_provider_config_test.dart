import 'package:flutter_test/flutter_test.dart';
import 'package:omi/models/custom_stt_config.dart';
import 'package:omi/models/stt_provider.dart';

void main() {
  group('SttProviderConfig Groq presets', () {
    test('exposes Groq Whisper presets in visible providers', () {
      final providers = SttProviderConfig.allProviders.map((config) => config.provider);

      expect(providers, contains(SttProvider.groqWhisperLargeV3));
      expect(providers, contains(SttProvider.groqWhisperLargeV3Turbo));
    });

    test('builds OpenAI-compatible Groq Whisper Large v3 request config', () {
      final config = CustomSttConfig(provider: SttProvider.groqWhisperLargeV3, apiKey: 'gsk_test').requestConfig;

      expect(config['url'], 'https://api.groq.com/openai/v1/audio/transcriptions');
      expect(config['request_type'], SttRequestType.multipartForm);
      expect(config['audio_field_name'], 'file');
      expect(config['headers'], {'Authorization': 'Bearer gsk_test'});
      expect(config['params'], {
        'model': 'whisper-large-v3',
        'language': 'en',
        'response_format': 'verbose_json',
        'timestamp_granularities[]': 'segment',
      });
    });

    test('builds OpenAI-compatible Groq Whisper Large v3 Turbo request config', () {
      final config = CustomSttConfig(provider: SttProvider.groqWhisperLargeV3Turbo, apiKey: 'gsk_test').requestConfig;

      expect(config['url'], 'https://api.groq.com/openai/v1/audio/transcriptions');
      expect(config['request_type'], SttRequestType.multipartForm);
      expect(config['audio_field_name'], 'file');
      expect(config['headers'], {'Authorization': 'Bearer gsk_test'});
      expect(config['params'], {
        'model': 'whisper-large-v3-turbo',
        'language': 'en',
        'response_format': 'verbose_json',
        'timestamp_granularities[]': 'segment',
      });
    });
  });
}
