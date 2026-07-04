import 'package:omi/backend/preferences.dart';

class AuthErrorLog {
  static const _maxErrorLength = 800;

  static String? get last {
    final value = SharedPreferencesUtil().lastAuthError;
    return value.isEmpty ? null : value;
  }

  static void record(String stage, Object error) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final message = _clip(error.toString().replaceAll(RegExp(r'\s+'), ' ').trim());
    SharedPreferencesUtil().lastAuthError = '$timestamp [$stage] $message';
  }

  static String _clip(String value) {
    if (value.length <= _maxErrorLength) return value;
    return '${value.substring(0, _maxErrorLength)}...';
  }
}
