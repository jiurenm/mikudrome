import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/screens/player_screen.dart';

void main() {
  group('isMediaSessionBindingCurrent', () {
    test('returns true when bind version matches current version', () {
      expect(
        isMediaSessionBindingCurrent(bindVersion: 4, currentVersion: 4),
        isTrue,
      );
    });

    test('returns false when bind version is stale', () {
      expect(
        isMediaSessionBindingCurrent(bindVersion: 4, currentVersion: 5),
        isFalse,
      );
    });
  });
}
