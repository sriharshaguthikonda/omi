import 'package:flutter_test/flutter_test.dart';

import 'package:omi/utils/settings_search_match.dart';

void main() {
  group('matchesSettingsQuery', () {
    test('exact match', () {
      expect(matchesSettingsQuery('Notifications', 'Notifications'), isTrue);
    });

    test('case-insensitive substring match', () {
      expect(matchesSettingsQuery('notif', 'Notifications'), isTrue);
    });

    test('typo tolerance (transposed/missing letters)', () {
      expect(matchesSettingsQuery('transciption', 'Transcription'), isTrue);
      expect(matchesSettingsQuery('permisions', 'Permissions'), isTrue);
    });

    test('multi-word query requires every word to match somewhere in the title', () {
      expect(matchesSettingsQuery('perm rev', 'Permission Review'), isTrue);
      expect(matchesSettingsQuery('perm rev', 'Permissions'), isFalse);
    });

    test('subsequence match', () {
      expect(matchesSettingsQuery('ntfy', 'Notify'), isTrue);
    });

    test('short words require exact match, not fuzzy', () {
      expect(matchesSettingsQuery('cd', 'Bluetooth'), isFalse);
    });

    test('unrelated query does not match', () {
      expect(matchesSettingsQuery('xyzzy', 'Permissions'), isFalse);
    });
  });
}
