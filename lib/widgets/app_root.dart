import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config_controller.dart';
import '../screens/library_home_screen.dart';
import '../screens/server_setup_screen.dart';
import '../utils/responsive.dart';

typedef AppHomeBuilder = Widget Function(BuildContext context);

class AppRoot extends StatefulWidget {
  const AppRoot({
    super.key,
    required this.controller,
    this.requiresServerSetup = !kIsWeb,
    this.homeBuilder,
  });

  final AppConfigController controller;
  final bool requiresServerSetup;
  final AppHomeBuilder? homeBuilder;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onConfigChanged);
  }

  @override
  void didUpdateWidget(AppRoot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onConfigChanged);
    widget.controller.addListener(_onConfigChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onConfigChanged);
    super.dispose();
  }

  void _onConfigChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return _NativePhoneLandscapeSystemUi(child: _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    final state = widget.controller.state;

    switch (state.status) {
      case AppConfigStatus.configured:
        return widget.homeBuilder?.call(context) ??
            LibraryHomeScreen(appConfigController: widget.controller);
      case AppConfigStatus.loading:
        if (state.serverUrl != null) {
          return ServerSetupScreen(controller: widget.controller);
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AppConfigStatus.unconfigured:
      case AppConfigStatus.error:
        if (state.serverUrl != null) {
          return widget.homeBuilder?.call(context) ??
              LibraryHomeScreen(appConfigController: widget.controller);
        }
        if (widget.requiresServerSetup) {
          return ServerSetupScreen(controller: widget.controller);
        }
        return widget.homeBuilder?.call(context) ??
            LibraryHomeScreen(appConfigController: widget.controller);
    }
  }
}

class _NativePhoneLandscapeSystemUi extends StatefulWidget {
  const _NativePhoneLandscapeSystemUi({required this.child});

  final Widget child;

  @override
  State<_NativePhoneLandscapeSystemUi> createState() =>
      _NativePhoneLandscapeSystemUiState();
}

class _NativePhoneLandscapeSystemUiState
    extends State<_NativePhoneLandscapeSystemUi> {
  bool? _statusOverlayHidden;

  bool get _canManageSystemUi {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSystemUiForSurface();
  }

  @override
  void dispose() {
    if (_statusOverlayHidden == true) {
      _setSystemUiOverlays(SystemUiOverlay.values);
    }
    super.dispose();
  }

  void _syncSystemUiForSurface() {
    if (!_canManageSystemUi) return;

    final hideStatusOverlay = isNativePhoneLandscapeSurface(context);
    if (_statusOverlayHidden == hideStatusOverlay) return;

    _statusOverlayHidden = hideStatusOverlay;
    _setSystemUiOverlays(
      hideStatusOverlay
          ? const <SystemUiOverlay>[SystemUiOverlay.bottom]
          : SystemUiOverlay.values,
    );
  }

  void _setSystemUiOverlays(List<SystemUiOverlay> overlays) {
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: overlays,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
