import 'package:flutter/foundation.dart';
import 'package:omi/backend/preferences.dart';
import 'package:omi/services/capture/capture_controller.dart';
import 'package:omi/utils/debug_log_manager.dart';
import 'package:omi/utils/enums.dart';

class TriggerRouter {
  TriggerRouter(this._captureController);

  static const _validActions = {'toggle', 'start', 'stop', 'mark'};

  final CaptureController _captureController;

  Future<void> handleTrigger({required String source, required String action}) async {
    // Security gate: an exported Android receiver lets any app (Tasker etc.) send this
    // source, so it's off by default. Single choke point — every trigger routes through here.
    if (source == 'external_intent' && !SharedPreferencesUtil().externalTriggersEnabled) {
      debugPrint('TriggerRouter: ignoring external_intent trigger, externalTriggersEnabled is off');
      return;
    }

    final normalizedAction = action.trim().toLowerCase();
    final resolved = _resolveAction(normalizedAction);

    await DebugLogManager.logEvent('trigger_router', {
      'source': source,
      'action': normalizedAction,
      'resolved': resolved,
    });

    switch (resolved) {
      case 'start':
        await _captureController.streamRecording();
        return;
      case 'stop':
        await _captureController.stopStreamRecording();
        return;
      case 'mark':
        // ponytail: P4 will turn mark into a last-buffer salvage feature.
        return;
      default:
        return;
    }
  }

  String _resolveAction(String action) {
    if (!_validActions.contains(action)) return 'ignored_invalid_action';
    if (action == 'mark') return 'mark';

    final state = _captureController.recordingState;
    if (action == 'toggle') {
      if (state == RecordingState.initialising) return 'ignored_initialising';
      return _isPhoneMicRecordingState(state) ? 'stop' : _resolveStart(state);
    }
    if (action == 'start') return _resolveStart(state);
    if (_isPhoneMicRecordingState(state)) return 'stop';
    return 'ignored_not_recording';
  }

  String _resolveStart(RecordingState state) {
    if (_isPhoneMicRecordingState(state)) return 'ignored_already_recording';
    if (state == RecordingState.stop || state == RecordingState.error) return 'start';
    return 'ignored_non_phone_recording';
  }

  bool _isPhoneMicRecordingState(RecordingState state) {
    return state == RecordingState.record || state == RecordingState.interrupted;
  }
}
