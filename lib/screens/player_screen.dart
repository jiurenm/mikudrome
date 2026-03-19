import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../api/api.dart';
import '../models/timed_lyric_line.dart';
import '../models/track.dart';
import '../services/lrc_parser.dart';
import '../theme/app_theme.dart';
import '../widgets/player_screen_parts.dart';
import 'library_home_screen.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.track,
    required this.queue,
    required this.currentIndex,
    required this.contextLabel,
    required this.playbackMode,
    required this.onSelectTrack,
    required this.onPrevious,
    required this.onNext,
    required this.onClose,
    required this.onSwitchPlaybackMode,
    required this.onPlaybackStateChanged,
    this.baseUrl = '',
  });

  final Track track;
  final List<Track> queue;
  final int currentIndex;
  final String contextLabel;
  final PlaybackMode playbackMode;
  final ValueChanged<int> onSelectTrack;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onClose;
  final ValueChanged<PlaybackMode> onSwitchPlaybackMode;
  final void Function({
    required bool isPlaying,
    required double progress,
    required String elapsedLabel,
    required String durationLabel,
  }) onPlaybackStateChanged;
  final String baseUrl;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  VoidCallback? _controllerListener;
  bool _isInitializing = true;
  String? _error;
  late bool _showQueue;
  bool _isFullscreen = false;
  bool _showFullscreenChrome = true;
  bool _showLyrics = true;
  List<TimedLyricLine> _timedLyrics = const [];
  int _activeLyricIndex = -1;
  Timer? _fullscreenChromeTimer;

  ApiClient get _api => ApiClient(baseUrl: widget.baseUrl);
  Track get _track => widget.track;
  bool get _hasPrevious => widget.currentIndex > 0;
  bool get _hasNext => widget.currentIndex < widget.queue.length - 1;
  bool get _isVideoMode => widget.playbackMode == PlaybackMode.video;
  bool get _canUseVideoMode => _track.hasVideo;
  String get _mediaUrl => _isVideoMode
      ? _api.streamVideoUrl(_track.id)
      : _api.streamAudioUrl(_track.id);
  String get _albumCoverUrl => _coverUrlForTrack(_track);

  String _coverUrlForTrack(Track track) =>
      track.albumId > 0 ? _api.albumCoverUrl(track.albumId.toString()) : '';
  Duration get _position => _controller?.value.position ?? Duration.zero;
  Duration get _duration => _controller?.value.duration ?? Duration.zero;
  bool get _isPlaying => _controller?.value.isPlaying ?? false;
  bool get _hasTimedLyrics => _timedLyrics.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _showQueue = !_track.hasVideo;
    _syncLyricsForTrack();
    _initializeController();
  }

  @override
  void didUpdateWidget(covariant PlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id ||
        oldWidget.track.lyrics != widget.track.lyrics) {
      _syncLyricsForTrack();
    }
    if (oldWidget.track.id != widget.track.id ||
        oldWidget.playbackMode != widget.playbackMode ||
        oldWidget.baseUrl != widget.baseUrl) {
      _initializeController();
    }
  }

  void _syncLyricsForTrack() {
    _timedLyrics = parseLrcLyrics(_track.lyrics);
    _activeLyricIndex = -1;
  }

  Future<void> _initializeController() async {
    final previous = _controller;
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _error = null;
      });
    }

    _detachControllerListener(previous);

    final controller = VideoPlayerController.networkUrl(Uri.parse(_mediaUrl));
    _controller = controller;

    try {
      await controller.initialize();
      controller.setLooping(false);
      _attachControllerListener(controller);
      await controller.play();
      if (!mounted || _controller != controller) {
        await controller.dispose();
        return;
      }
      setState(() {
        _isInitializing = false;
      });
      _emitPlaybackState();
    } catch (e) {
      if (!mounted || _controller != controller) {
        await controller.dispose();
        return;
      }
      setState(() {
        _isInitializing = false;
        _error = e.toString();
      });
    } finally {
      await previous?.dispose();
    }
  }

  void _attachControllerListener(VideoPlayerController controller) {
    _controllerListener = () {
      if (!mounted || _controller != controller) return;
      final value = controller.value;
      if (!value.isInitialized) return;
      if (value.position >= value.duration &&
          !value.isPlaying &&
          value.duration > Duration.zero &&
          _hasNext) {
        widget.onNext();
        return;
      }
      final nextActiveIndex = findActiveLyricIndex(_timedLyrics, value.position);
      _emitPlaybackState();
      if (nextActiveIndex == _activeLyricIndex) {
        return;
      }
      setState(() {
        _activeLyricIndex = nextActiveIndex;
      });
    };
    controller.addListener(_controllerListener!);
  }

  void _detachControllerListener(VideoPlayerController? controller) {
    if (controller != null && _controllerListener != null) {
      controller.removeListener(_controllerListener!);
    }
    _controllerListener = null;
  }

  @override
  void dispose() {
    _fullscreenChromeTimer?.cancel();
    _detachControllerListener(_controller);
    widget.onPlaybackStateChanged(
      isPlaying: false,
      progress: 0,
      elapsedLabel: '--:--',
      durationLabel: '--:--',
    );
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    _emitPlaybackState();
    if (mounted) setState(() {});
  }

  Future<void> _seekTo(double value) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final target = _duration * value;
    await controller.seekTo(target);
    _emitPlaybackState();
  }

  void _emitPlaybackState() {
    final duration = _duration;
    final position = _position > duration ? duration : _position;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : position.inMilliseconds / duration.inMilliseconds;
    widget.onPlaybackStateChanged(
      isPlaying: _isPlaying,
      progress: progress.clamp(0.0, 1.0),
      elapsedLabel: _formatDuration(position),
      durationLabel: _formatDuration(duration),
    );
  }

  void _showFullscreenOverlayTemporarily() {
    _fullscreenChromeTimer?.cancel();
    if (!_isFullscreen) return;
    setState(() {
      _showFullscreenChrome = true;
    });
    _fullscreenChromeTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || !_isFullscreen) return;
      setState(() {
        _showFullscreenChrome = false;
      });
    });
  }

  void _resumeAfterFullscreenToggle(bool shouldResume) {
    if (!shouldResume) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = _controller;
      if (!mounted || controller == null) return;
      await controller.play();
      if (!mounted) return;
      Future<void>.delayed(const Duration(milliseconds: 120), () async {
        final latestController = _controller;
        if (!mounted || latestController == null) return;
        if (!latestController.value.isPlaying) {
          await latestController.play();
        }
      });
    });
  }

  void _enterFullscreen() {
    if (!_isVideoMode) return;
    final shouldResume = _controller?.value.isPlaying ?? false;
    setState(() {
      _isFullscreen = true;
      _showFullscreenChrome = true;
    });
    _showFullscreenOverlayTemporarily();
    _resumeAfterFullscreenToggle(shouldResume);
  }

  void _exitFullscreen() {
    final shouldResume = _controller?.value.isPlaying ?? false;
    _fullscreenChromeTimer?.cancel();
    setState(() {
      _isFullscreen = false;
      _showFullscreenChrome = true;
    });
    _resumeAfterFullscreenToggle(shouldResume);
  }

  void _toggleQueue() {
    setState(() {
      _showQueue = !_showQueue;
    });
  }

  String get _queueSubtitle {
    final baseCredits = <String>[
      ..._track.composers,
      ..._track.lyricists,
    ];
    final uniqueCredits = <String>[];
    final seenCredits = <String>{};
    for (final credit in baseCredits) {
      if (seenCredits.add(credit)) {
        uniqueCredits.add(credit);
      }
    }

    final parts = <String>[];
    if (uniqueCredits.isNotEmpty) {
      parts.add(uniqueCredits.join(', '));
    }
    if (_track.vocalists.isNotEmpty) {
      parts.add('feat. ${_track.vocalists.join(', ')}');
    }

    return parts.isNotEmpty ? parts.join(' ') : 'Unknown credits';
  }

  String _formatDuration(Duration value) {
    final totalSeconds = value.inSeconds;
    if (totalSeconds <= 0) return '--:--';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final queueVisible = _showQueue && width >= (_isVideoMode ? 1280 : 1440);
    final queuePanelWidth = _isVideoMode ? 320.0 : 280.0;

    if (_isFullscreen && _isVideoMode) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: MouseRegion(
          onHover: (_) => _showFullscreenOverlayTemporarily(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showFullscreenOverlayTemporarily,
            onDoubleTap: _exitFullscreen,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Center(child: _buildVideoArea(isFullscreen: true)),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 180),
                  top: _showFullscreenChrome ? 12 : -72,
                  left: 12,
                  right: 12,
                  child: _buildFullscreenTopBar(context),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 180),
                  left: 0,
                  right: 0,
                  bottom: _showFullscreenChrome ? 0 : -180,
                  child: _buildFullscreenControls(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Column(
        children: [
          PlayerHeader(
            contextLabel: widget.contextLabel,
            playbackMode: widget.playbackMode,
            canUseVideoMode: _canUseVideoMode,
            onClose: widget.onClose,
            onChangedMode: widget.onSwitchPlaybackMode,
            onEnterFullscreen: _isVideoMode ? _enterFullscreen : null,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.only(right: queueVisible ? 14 : 0),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      scale: queueVisible ? 0.992 : 1,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppTheme.mikuGreen.withValues(alpha: 0.1),
                              const Color(0xFF1A1A1A),
                            ],
                          ),
                        ),
                        child: _isVideoMode
                            ? Column(
                                children: [
                                  Expanded(
                                    flex: 8,
                                    child: Center(
                                      child: _buildMediaArea(context),
                                    ),
                                  ),
                                  VideoModeDetails(
                                    title: _track.title,
                                    subtitle: _queueSubtitle,
                                    showSideInfo: queueVisible,
                                  ),
                                  _buildControls(context),
                                ],
                              )
                            : Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 8),
                                    child: Column(
                                      children: [
                                        Text(
                                          _track.title,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineMedium
                                              ?.copyWith(
                                                color: AppTheme.textPrimary,
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(28, 8, 28, 12),
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final lyricsPanelWidth =
                                              (constraints.maxWidth * 0.58)
                                                  .clamp(320.0, 860.0);

                                          return Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Expanded(
                                                child: AnimatedSlide(
                                                  duration: const Duration(
                                                      milliseconds: 260),
                                                  curve: Curves.easeOutCubic,
                                                  offset: _showLyrics
                                                      ? const Offset(-0.04, 0)
                                                      : Offset.zero,
                                                  child: AnimatedAlign(
                                                    duration: const Duration(
                                                        milliseconds: 260),
                                                    curve: Curves.easeOutCubic,
                                                    alignment: _showLyrics
                                                        ? Alignment.topCenter
                                                        : Alignment.center,
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        _buildMediaArea(context),
                                                        TrackInfoSection(
                                                          track: _track,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 260),
                                                curve: Curves.easeOutCubic,
                                                width: _showLyrics ? 24 : 0,
                                              ),
                                              TweenAnimationBuilder<double>(
                                                duration: const Duration(
                                                    milliseconds: 260),
                                                curve: Curves.easeOutCubic,
                                                tween: Tween<double>(
                                                  begin: _showLyrics ? 0 : 1,
                                                  end: _showLyrics ? 1 : 0,
                                                ),
                                                builder:
                                                    (context, widthFactor, child) {
                                                  return SizedBox(
                                                    width: lyricsPanelWidth * widthFactor,
                                                    child: ClipRect(
                                                      child: Align(
                                                        alignment:
                                                            Alignment.centerRight,
                                                        child: child,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: IgnorePointer(
                                                  ignoring: !_showLyrics,
                                                  child: AnimatedSlide(
                                                    duration: const Duration(
                                                        milliseconds: 260),
                                                    curve: Curves.easeOutCubic,
                                                    offset: _showLyrics
                                                        ? Offset.zero
                                                        : const Offset(0.12, 0),
                                                    child: SizedBox(
                                                      width: lyricsPanelWidth,
                                                      child: LyricsSection(
                                                        lyrics: _track.lyrics,
                                                        timedLyrics: _timedLyrics,
                                                        activeIndex: _showLyrics &&
                                                                _hasTimedLyrics
                                                            ? _activeLyricIndex
                                                            : -1,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  _buildControls(context),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  width: queueVisible ? queuePanelWidth : 0,
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerRight,
                      widthFactor: queueVisible ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !queueVisible,
                        child: queueVisible
                            ? QueuePanel(
                                contextLabel: widget.contextLabel,
                                queue: widget.queue,
                                currentIndex: widget.currentIndex,
                                isVideoMode: _isVideoMode,
                                coverUrlForTrack: _coverUrlForTrack,
                                onSelectTrack: widget.onSelectTrack,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildMediaArea(BuildContext context) {
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.mikuGreen),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_isVideoMode) {
      return _buildVideoArea();
    }

    return _buildAudioArea(context);
  }

  Widget _buildVideoArea({bool isFullscreen = false}) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final borderRadius = isFullscreen ? 0.0 : 16.0;
    final padding = isFullscreen
        ? EdgeInsets.zero
        : const EdgeInsets.fromLTRB(8, 4, 8, 8);
    return Padding(
      padding: padding,
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio == 0
            ? 16 / 9
            : controller.value.aspectRatio,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: isFullscreen
                ? null
                : [
                    BoxShadow(
                      color: AppTheme.mikuGreen.withValues(alpha: 0.18),
                      blurRadius: 40,
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioArea(BuildContext context) {
    return AudioArtworkCard(
      albumCoverUrl: _albumCoverUrl,
      placeholder: _audioPlaceholder(),
    );
  }

  Widget _audioPlaceholder() => Container(
        height: 320,
        width: 320,
        color: AppTheme.cardBg,
        alignment: Alignment.center,
        child: const Icon(
          Icons.music_note,
          color: AppTheme.textMuted,
          size: 64,
        ),
      );


  Widget _buildControls(BuildContext context) {
    final duration = _duration;
    final position = _position > duration ? duration : _position;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : position.inMilliseconds / duration.inMilliseconds;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _isVideoMode ? 18 : 32,
        0,
        _isVideoMode ? 18 : 32,
        _isVideoMode ? 12 : 20,
      ),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.mikuGreen,
              inactiveTrackColor: Colors.grey.shade800,
              thumbColor: AppTheme.mikuGreen,
              overlayColor: AppTheme.mikuGreen.withValues(alpha: 0.15),
              trackHeight: 4,
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: duration == Duration.zero ? null : _seekTo,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              Text(
                _formatDuration(duration),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
            ],
          ),
          SizedBox(height: _isVideoMode ? 6 : 12),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _canUseVideoMode
                      ? TextButton.icon(
                          onPressed: () => widget.onSwitchPlaybackMode(
                            _isVideoMode
                                ? PlaybackMode.audio
                                : PlaybackMode.video,
                          ),
                          icon: Icon(
                            _isVideoMode ? Icons.music_note : Icons.movie,
                            color: AppTheme.mikuGreen,
                          ),
                          label: Text(
                            _isVideoMode ? 'Switch to Audio' : 'Switch to MV',
                            style: const TextStyle(color: AppTheme.mikuGreen),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous, size: 30),
                    onPressed: _hasPrevious ? widget.onPrevious : null,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(52, 52),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      size: 48,
                      color: AppTheme.mikuGreen,
                    ),
                    onPressed: _togglePlayback,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(64, 64),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, size: 30),
                    onPressed: _hasNext ? widget.onNext : null,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(52, 52),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_isVideoMode)
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showLyrics = !_showLyrics;
                            });
                          },
                          icon: Icon(
                            _showLyrics ? Icons.visibility : Icons.visibility_off,
                            size: 26,
                            color: _showLyrics
                                ? AppTheme.mikuGreen
                                : AppTheme.textMuted,
                          ),
                          tooltip: 'Lyrics',
                          style: IconButton.styleFrom(
                            minimumSize: const Size(50, 50),
                          ),
                        ),
                      IconButton(
                        onPressed: _toggleQueue,
                        icon: Icon(
                          _showQueue ? Icons.queue_music : Icons.queue_music_outlined,
                          size: 26,
                          color: _showQueue
                              ? AppTheme.mikuGreen
                              : AppTheme.textMuted,
                        ),
                        tooltip: 'Queue',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(50, 50),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFullscreenTopBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _track.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: _exitFullscreen,
          icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
          tooltip: 'Exit fullscreen',
        ),
      ],
    );
  }

  Widget _buildFullscreenControls(BuildContext context) {
    final duration = _duration;
    final position = _position > duration ? duration : _position;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : position.inMilliseconds / duration.inMilliseconds;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.mikuGreen,
              inactiveTrackColor: Colors.white24,
              thumbColor: AppTheme.mikuGreen,
              overlayColor: AppTheme.mikuGreen.withValues(alpha: 0.15),
              trackHeight: 4,
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: duration == Duration.zero ? null : _seekTo,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                _formatDuration(duration),
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _hasPrevious ? widget.onPrevious : null,
                icon: const Icon(Icons.skip_previous, color: Colors.white),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _togglePlayback,
                icon: Icon(
                  _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: AppTheme.mikuGreen,
                  size: 48,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _hasNext ? widget.onNext : null,
                icon: const Icon(Icons.skip_next, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final modeLabel = _isVideoMode ? 'Local MV Active' : 'Audio Stream Active';
    final vocalists = _track.vocalists.isNotEmpty
        ? _track.vocalists.join(', ')
        : 'Unknown vocalists';
    return Container(
      height: 24,
      color: AppTheme.mikuGreen,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Text(
        'Now Playing: ${_track.title} // $vocalists // $modeLabel',
        style: const TextStyle(
          fontSize: 10,
          color: Colors.black,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
