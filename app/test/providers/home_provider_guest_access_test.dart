import 'package:flutter_test/flutter_test.dart';
import 'package:omi/providers/home_provider.dart';

void main() {
  group('HomeProvider guest cloud tab access', () {
    test('keeps normal tabs available for guests', () {
      expect(HomeProvider.clampGuestSelectedIndex(0), 0);
      expect(HomeProvider.clampGuestSelectedIndex(1), 1);
      expect(HomeProvider.clampGuestSelectedIndex(2), 2);
      expect(HomeProvider.clampGuestSelectedIndex(3), 3);
    });

    test('moves cloud-only tabs to conversations for guests', () {
      expect(HomeProvider.clampGuestSelectedIndex(HomeProvider.memoriesTabIndex), HomeProvider.conversationsTabIndex);
      expect(HomeProvider.clampGuestSelectedIndex(HomeProvider.chatTabIndex), HomeProvider.conversationsTabIndex);
    });

    test('identifies cloud-only routes', () {
      expect(HomeProvider.isGuestCloudOnlyRoute('chat'), isTrue);
      expect(HomeProvider.isGuestCloudOnlyRoute('memories'), isTrue);
      expect(HomeProvider.isGuestCloudOnlyRoute('facts'), isTrue);
      expect(HomeProvider.isGuestCloudOnlyRoute('conversation'), isFalse);
      expect(HomeProvider.isGuestCloudOnlyRoute('action-items'), isFalse);
    });
  });
}
