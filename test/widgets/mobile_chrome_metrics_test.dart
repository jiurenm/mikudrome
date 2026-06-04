import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/utils/responsive.dart';
import 'package:mikudrome/widgets/mobile_chrome_metrics.dart';

void main() {
  test('portrait metrics reserve bottom navigation and safe area', () {
    final metrics = MobileChromeMetrics.forSurface(
      SurfaceType.mobilePortrait,
      safeAreaBottom: 12,
    );

    expect(metrics.hasBottomNavigation, isTrue);
    expect(metrics.navigationInset, 68);
    expect(metrics.playerInset, 68);
    expect(metrics.railWidth, 0);
  });

  test('landscape metrics expose rail width without bottom navigation', () {
    final metrics = MobileChromeMetrics.forSurface(
      SurfaceType.mobileLandscape,
      safeAreaBottom: 8,
    );

    expect(metrics.hasBottomNavigation, isFalse);
    expect(metrics.navigationInset, kLandscapeRailWidth);
    expect(metrics.playerInset, 8);
    expect(metrics.railWidth, kLandscapeRailWidth);
  });
}
