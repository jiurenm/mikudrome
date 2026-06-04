import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/utils/responsive.dart';

void main() {
  group('surfaceTypeForSize', () {
    test('native phone portrait is mobilePortrait', () {
      expect(
        surfaceTypeForSize(
          const Size(390, 844),
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        SurfaceType.mobilePortrait,
      );
    });

    test('native phone landscape is mobileLandscape', () {
      expect(
        surfaceTypeForSize(
          const Size(844, 390),
          isWeb: false,
          platform: TargetPlatform.iOS,
        ),
        SurfaceType.mobileLandscape,
      );
    });

    test('native tablet landscape is tablet', () {
      expect(
        surfaceTypeForSize(
          const Size(1133, 744),
          isWeb: false,
          platform: TargetPlatform.iOS,
        ),
        SurfaceType.tablet,
      );
    });

    test('desktop platform does not enter phone landscape', () {
      expect(
        surfaceTypeForSize(
          const Size(844, 390),
          isWeb: false,
          platform: TargetPlatform.linux,
        ),
        SurfaceType.desktop,
      );
    });

    test('desktop platform with large window is desktop', () {
      expect(
        surfaceTypeForSize(
          const Size(1440, 900),
          isWeb: false,
          platform: TargetPlatform.linux,
        ),
        SurfaceType.desktop,
      );
    });

    test('web landscape window does not enter native phone landscape', () {
      expect(
        surfaceTypeForSize(
          const Size(844, 390),
          isWeb: true,
          platform: TargetPlatform.android,
        ),
        SurfaceType.desktop,
      );
    });
  });
}
