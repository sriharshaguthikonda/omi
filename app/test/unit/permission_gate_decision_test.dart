import 'package:flutter_test/flutter_test.dart';
import 'package:omi/mobile/mobile_app.dart';

void main() {
  group('shouldShowPermissionGate', () {
    test('skips after permissions were reviewed when only non-critical permissions are missing', () {
      expect(
        shouldShowPermissionGate(
          permissionsCompleted: true,
          allRelevantPermissionsGranted: false,
          criticalPermissionsGranted: true,
        ),
        isFalse,
      );
    });

    test('skips when all relevant permissions are already granted', () {
      expect(
        shouldShowPermissionGate(
          permissionsCompleted: false,
          allRelevantPermissionsGranted: true,
          criticalPermissionsGranted: true,
        ),
        isFalse,
      );
    });

    test('shows when critical permissions are missing even after review', () {
      expect(
        shouldShowPermissionGate(
          permissionsCompleted: true,
          allRelevantPermissionsGranted: false,
          criticalPermissionsGranted: false,
        ),
        isTrue,
      );
    });

    test('shows on a fresh install when relevant permissions are missing', () {
      expect(
        shouldShowPermissionGate(
          permissionsCompleted: false,
          allRelevantPermissionsGranted: false,
          criticalPermissionsGranted: true,
        ),
        isTrue,
      );
    });
  });
}
