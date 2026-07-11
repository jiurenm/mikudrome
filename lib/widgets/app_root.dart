import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config_controller.dart';
import '../screens/library_home_screen.dart';
import '../screens/server_setup_screen.dart';
import '../services/mobile_audio_playback.dart';
import '../services/playback_storage.dart';
import '../utils/responsive.dart';

typedef AppHomeBuilder = Widget Function(BuildContext context);

class AppRoot extends StatefulWidget {
  const AppRoot({
    super.key,
    required this.controller,
    this.requiresServerSetup = !kIsWeb,
    this.homeBuilder,
    this.mobileAudioPlaybackService,
  });

  final AppConfigController controller;
  final bool requiresServerSetup;
  final AppHomeBuilder? homeBuilder;
  final MobileAudioPlaybackService? mobileAudioPlaybackService;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late MobileAudioPlaybackService _mobileAudioPlaybackService;
  late bool _ownsMobileAudioPlaybackService;
  late bool _hasConfiguredSession;
  bool _configuredEditInFlight = false;
  int _homeGeneration = 0;

  @override
  void initState() {
    super.initState();
    _setMobileAudioPlaybackService(widget.mobileAudioPlaybackService);
    _hasConfiguredSession =
        widget.controller.state.status == AppConfigStatus.configured;
    widget.controller.addListener(_onConfigChanged);
  }

  @override
  void didUpdateWidget(AppRoot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onConfigChanged);
      widget.controller.addListener(_onConfigChanged);
      _hasConfiguredSession =
          widget.controller.state.status == AppConfigStatus.configured;
      _configuredEditInFlight = false;
      _homeGeneration += 1;
    }
    if (!identical(
      oldWidget.mobileAudioPlaybackService,
      widget.mobileAudioPlaybackService,
    )) {
      final previousService = _mobileAudioPlaybackService;
      final ownedPreviousService = _ownsMobileAudioPlaybackService;
      _setMobileAudioPlaybackService(widget.mobileAudioPlaybackService);
      _homeGeneration += 1;
      if (ownedPreviousService) {
        unawaited(previousService.dispose());
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onConfigChanged);
    if (_ownsMobileAudioPlaybackService) {
      unawaited(_mobileAudioPlaybackService.dispose());
    }
    super.dispose();
  }

  void _setMobileAudioPlaybackService(
    MobileAudioPlaybackService? injectedService,
  ) {
    _ownsMobileAudioPlaybackService = injectedService == null;
    _mobileAudioPlaybackService =
        injectedService ?? createMobileAudioPlaybackService();
  }

  void _onConfigChanged() {
    final status = widget.controller.state.status;
    if (status == AppConfigStatus.loading && _hasConfiguredSession) {
      _configuredEditInFlight = true;
    } else if (status == AppConfigStatus.configured) {
      final completedConfiguredEdit = _configuredEditInFlight;
      _hasConfiguredSession = true;
      _configuredEditInFlight = false;
      if (completedConfiguredEdit) {
        PlaybackStorage.clear();
        try {
          unawaited(
            _mobileAudioPlaybackService.clearCache().catchError((Object _) {}),
          );
        } catch (_) {}
        _homeGeneration += 1;
      }
    } else if (status == AppConfigStatus.error) {
      _configuredEditInFlight = false;
    } else if (status == AppConfigStatus.unconfigured) {
      _hasConfiguredSession = false;
      _configuredEditInFlight = false;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _NativePhoneLandscapeSystemUi(child: _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    final state = widget.controller.state;

    switch (state.status) {
      case AppConfigStatus.configured:
        return _buildHome(context);
      case AppConfigStatus.loading:
        if (_hasConfiguredSession) return _buildHome(context);
        if (state.serverUrl != null) {
          return ServerSetupScreen(controller: widget.controller);
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AppConfigStatus.unconfigured:
      case AppConfigStatus.error:
        if (_hasConfiguredSession) return _buildHome(context);
        if (widget.requiresServerSetup) {
          return ServerSetupScreen(controller: widget.controller);
        }
        return _buildHome(context);
    }
  }

  Widget _buildHome(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey<int>(_homeGeneration),
      child:
          widget.homeBuilder?.call(context) ??
          LibraryHomeScreen(
            appConfigController: widget.controller,
            mobileAudioPlaybackService: _mobileAudioPlaybackService,
          ),
    );
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
