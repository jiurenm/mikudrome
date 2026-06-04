import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const double kMobileBreakpoint = 600;
const double kPhoneMaxShortestSide = 600;

enum SurfaceType { mobilePortrait, mobileLandscape, tablet, desktop }

bool _isNativeMobilePlatform(TargetPlatform platform) {
  return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
}

SurfaceType surfaceTypeForSize(
  Size size, {
  required bool isWeb,
  required TargetPlatform platform,
}) {
  final nativeMobilePlatform = !isWeb && _isNativeMobilePlatform(platform);
  final phoneSized = size.shortestSide < kPhoneMaxShortestSide;
  final landscape = size.width > size.height;

  if (nativeMobilePlatform && phoneSized) {
    return landscape ? SurfaceType.mobileLandscape : SurfaceType.mobilePortrait;
  }

  if (nativeMobilePlatform && size.shortestSide >= kPhoneMaxShortestSide) {
    return SurfaceType.tablet;
  }

  return SurfaceType.desktop;
}

SurfaceType surfaceTypeOf(BuildContext context) {
  return surfaceTypeForSize(
    MediaQuery.sizeOf(context),
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
  );
}

bool isMobilePortraitSurface(BuildContext context) {
  return surfaceTypeOf(context) == SurfaceType.mobilePortrait;
}

bool isNativePhoneLandscapeSurface(BuildContext context) {
  return surfaceTypeOf(context) == SurfaceType.mobileLandscape;
}

bool isMobileSurface(BuildContext context) {
  final surface = surfaceTypeOf(context);
  return surface == SurfaceType.mobilePortrait ||
      surface == SurfaceType.mobileLandscape;
}

bool isMobile(BuildContext context) {
  return MediaQuery.sizeOf(context).width < kMobileBreakpoint;
}
