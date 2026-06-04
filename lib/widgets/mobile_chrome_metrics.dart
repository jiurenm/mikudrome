import '../utils/responsive.dart';

const double kPortraitBottomNavigationHeight = 56;
const double kLandscapeRailWidth = 64;

class MobileChromeMetrics {
  const MobileChromeMetrics({
    required this.navigationInset,
    required this.playerInset,
    required this.railWidth,
    required this.hasBottomNavigation,
  });

  final double navigationInset;
  final double playerInset;
  final double railWidth;
  final bool hasBottomNavigation;

  static MobileChromeMetrics forSurface(
    SurfaceType surface, {
    required double safeAreaBottom,
  }) {
    if (surface == SurfaceType.mobileLandscape) {
      return MobileChromeMetrics(
        navigationInset: kLandscapeRailWidth,
        playerInset: safeAreaBottom,
        railWidth: kLandscapeRailWidth,
        hasBottomNavigation: false,
      );
    }

    return MobileChromeMetrics(
      navigationInset: kPortraitBottomNavigationHeight + safeAreaBottom,
      playerInset: kPortraitBottomNavigationHeight + safeAreaBottom,
      railWidth: 0,
      hasBottomNavigation: true,
    );
  }
}
