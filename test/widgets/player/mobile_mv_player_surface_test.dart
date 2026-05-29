import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/api/api.dart';
import 'package:mikudrome/widgets/player/mobile_mv_player_surface.dart';

Widget _buildSurface({
  String? error,
  bool isInitializing = false,
  VoidCallback? onOpenQueue,
  VoidCallback? onRetryVideo,
  VoidCallback? onSwitchToAudio,
}) {
  return MaterialApp(
    home: MobileMvPlayerSurface(
      title: 'Immersive MV',
      subtitle: 'Miku',
      contextLabel: 'MV Test',
      video: const ColoredBox(
        key: ValueKey('mobile-mv-test-video'),
        color: Colors.black,
      ),
      isInitializing: isInitializing,
      error: error,
      isPlaying: true,
      progress: 0.42,
      elapsedLabel: '01:12',
      durationLabel: '03:10',
      canSeek: true,
      hasPrevious: true,
      hasNext: true,
      trackId: 77,
      favoriteClient: ApiClient(),
      accentColor: Colors.cyanAccent,
      onCollapse: () {},
      onRetryVideo: onRetryVideo ?? () {},
      onSwitchToAudio: onSwitchToAudio ?? () {},
      onTogglePlayback: () {},
      onSeek: (_) {},
      onPrevious: () {},
      onNext: () {},
      onCyclePlaybackOrderMode: () {},
      playbackOrderButton: IconButton(
        onPressed: () {},
        icon: const Icon(Icons.repeat, color: Colors.white),
      ),
      onOpenQueue: onOpenQueue ?? () {},
      onEnterFullscreen: () {},
    ),
  );
}

void main() {
  testWidgets('renders immersive MV surface with video frame and queue entry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var queueOpened = false;

    await tester.pumpWidget(
      _buildSurface(onOpenQueue: () => queueOpened = true),
    );

    expect(
      find.byKey(const ValueKey('mobile-mv-player-surface')),
      findsOneWidget,
    );
    expect(
      tester.widget<Scaffold>(
        find.byKey(const ValueKey('mobile-mv-player-surface')),
      ),
      isA<Scaffold>(),
    );
    expect(find.byKey(const ValueKey('mobile-mv-video-frame')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-mv-test-video')), findsOneWidget);
    expect(find.text('Immersive MV'), findsOneWidget);
    expect(find.text('Miku'), findsOneWidget);
    expect(find.text('歌词'), findsNothing);
    expect(
      find.byKey(const ValueKey('mobile-mv-queue-button')),
      findsOneWidget,
    );

    final aspectRatio = tester.widget<AspectRatio>(
      find.byKey(const ValueKey('mobile-mv-video-frame')),
    );
    expect(aspectRatio.aspectRatio, 16 / 9);

    await tester.tap(find.byKey(const ValueKey('mobile-mv-queue-button')));
    expect(queueOpened, isTrue);
  });

  testWidgets('shows retry and switch-to-audio actions when video errors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var retryTapped = false;
    var switchTapped = false;

    await tester.pumpWidget(
      _buildSurface(
        error: 'video failed',
        onRetryVideo: () => retryTapped = true,
        onSwitchToAudio: () => switchTapped = true,
      ),
    );

    expect(find.text('video failed'), findsOneWidget);
    expect(find.text('重试 MV'), findsOneWidget);
    expect(find.text('切到音频'), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-mv-test-video')), findsNothing);

    await tester.tap(find.text('重试 MV'));
    await tester.tap(find.text('切到音频'));

    expect(retryTapped, isTrue);
    expect(switchTapped, isTrue);
  });
}
