import 'package:flutter/widgets.dart';

const double kMobileBreakpoint = 600;

bool isMobile(BuildContext context) {
  return MediaQuery.sizeOf(context).width < kMobileBreakpoint;
}
