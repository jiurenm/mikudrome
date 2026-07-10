import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/api/config.dart';
import 'package:mikudrome/config/app_config_controller.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/screens/library_home_screen.dart';
import 'package:mikudrome/screens/player_screen.dart';
import 'package:mikudrome/services/mobile_audio_playback.dart';
import 'package:mikudrome/services/playback_storage.dart';
import 'package:mikudrome/widgets/mobile_mini_player.dart';
import 'package:mikudrome/widgets/mobile_player_sheet.dart';
import 'package:mikudrome/widgets/player/mobile_mv_player_surface.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await PlaybackStorage.ensureInitialized();
  });

  testWidgets('initial mobile discover tab uses recommendation home', (
    tester,
  ) async {
    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester);
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _LibraryFakeHttpClient());

    expect(find.text('发现'), findsWidgets);
    expect(find.text('专辑推荐'), findsOneWidget);
    expect(find.text('热门P主'), findsOneWidget);
    expect(find.text('GHOST'), findsWidgets);
  });

  testWidgets('native phone landscape keeps mobile navigation shell', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    try {
      await HttpOverrides.runZoned(() async {
        await _pumpMobileLibrary(tester, size: const Size(844, 390));
        await tester.pumpAndSettle();
      }, createHttpClient: (_) => _LibraryFakeHttpClient());

      expect(
        find.byKey(const ValueKey('mobile-landscape-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mobile-landscape-rail')),
        findsOneWidget,
      );
      expect(find.text('专辑推荐'), findsOneWidget);
      expect(find.text('Albums'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'daily recommendations opens list and plays recommendation queue',
    (tester) async {
      final service = _RecordingMobileAudioPlaybackService();
      addTearDown(service.dispose);

      await HttpOverrides.runZoned(() async {
        await _pumpMobileLibrary(tester, mobileAudioPlaybackService: service);
        await tester.pumpAndSettle();

        await tester.tap(find.text('每日推荐'));
        await tester.pumpAndSettle();

        expect(find.text('Daily One'), findsOneWidget);
        expect(find.text('Daily Two'), findsOneWidget);

        await tester.tap(find.text('Daily Two'));
        await tester.pump(const Duration(milliseconds: 500));
      }, createHttpClient: (_) => _LibraryFakeHttpClient());

      expect(service.playedQueues.last.map((track) => track.id), [301, 302]);
    },
  );

  testWidgets('system back returns to the previous mobile tab', (tester) async {
    late bool handled;
    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(find.text('服务器'), findsOneWidget);

      handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _LibraryFakeHttpClient());

    expect(handled, isTrue);
    expect(find.text('专辑推荐'), findsOneWidget);
    expect(find.text('服务器'), findsNothing);
  });

  testWidgets('successful server edit clears mobile audio cache', (
    tester,
  ) async {
    final service = _RecordingMobileAudioPlaybackService();
    final store = _MemoryAppConfigStore(
      serverUrl: 'http://old.example.test',
      serverCookie: 'session=old',
    );
    final controller = AppConfigController(
      store: store,
      connectionTester: (_, {serverCookie}) async {},
    );
    await controller.load();
    addTearDown(service.dispose);
    addTearDown(controller.dispose);
    addTearDown(ApiConfig.resetRuntimeConfigForTests);

    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(
        tester,
        mobileAudioPlaybackService: service,
        appConfigController: controller,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('服务器'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'http://new.example.test');
      await tester.enterText(fields.at(1), 'session=new');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _LibraryFakeHttpClient());

    expect(service.clearCacheCalls, 1);
    expect(store.serverUrl, 'http://new.example.test');
    expect(store.serverCookie, 'session=new');
  });

  testWidgets(
    'discover more opens the full mobile section and back restores home',
    (tester) async {
      late bool handled;
      await HttpOverrides.runZoned(() async {
        await _pumpMobileLibrary(tester);
        await tester.pumpAndSettle();

        await tester.tap(find.text('更多 >').first);
        await tester.pumpAndSettle();

        expect(find.text('专辑推荐'), findsOneWidget);
        expect(find.text('(全部)'), findsOneWidget);
        expect(find.text('全部'), findsOneWidget);
        expect(find.text('最新'), findsOneWidget);
        expect(find.text('最热'), findsOneWidget);
        expect(find.text('VOCALOID'), findsOneWidget);
        expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
        expect(find.text('Albums'), findsNothing);
        expect(find.text('热门P主'), findsNothing);

        await tester.tap(find.byTooltip('搜索'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Neru');
        await tester.pumpAndSettle();

        expect(find.text('25時、ナイトコードで。'), findsOneWidget);
        expect(find.text('GHOST'), findsNothing);

        handled = await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }, createHttpClient: (_) => _LibraryFakeHttpClient());

      expect(handled, isTrue);
      expect(find.text('专辑推荐'), findsOneWidget);
      expect(find.text('Albums'), findsNothing);
    },
  );

  testWidgets('producer section page shows mobile back to discover home', (
    tester,
  ) async {
    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, '更多 >').at(1));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('producer-mobile-list')),
        findsOneWidget,
      );
      expect(find.byTooltip('返回'), findsOneWidget);

      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _LibraryFakeHttpClient());

    expect(find.text('热门P主'), findsOneWidget);
    expect(find.byKey(const ValueKey('producer-mobile-list')), findsNothing);
  });

  testWidgets('vocalist section page shows mobile back to discover home', (
    tester,
  ) async {
    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -360),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '更多 >').at(2));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('vocalist-mobile-list')),
        findsOneWidget,
      );
      expect(find.byTooltip('返回'), findsOneWidget);

      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _LibraryFakeHttpClient());

    expect(find.text('虚拟歌手'), findsOneWidget);
    expect(find.byKey(const ValueKey('vocalist-mobile-list')), findsNothing);
  });

  testWidgets('MV section page shows mobile back to discover home', (
    tester,
  ) async {
    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '更多 >').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('mv-gallery-scroll')), findsOneWidget);
      expect(find.byTooltip('返回'), findsOneWidget);

      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _LibraryFakeHttpClient());

    expect(find.text('专辑推荐'), findsOneWidget);
    expect(find.byKey(const ValueKey('mv-gallery-scroll')), findsNothing);
  });

  testWidgets('tapping a discover home album opens its detail page', (
    tester,
  ) async {
    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('GHOST').last);
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _LibraryFakeHttpClient());

    expect(find.text('Ghost Track'), findsOneWidget);
    expect(find.text('专辑推荐'), findsNothing);
  });

  testWidgets('tapping a discover home producer opens its detail page', (
    tester,
  ) async {
    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('discover-producer-1')));
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _LibraryFakeHttpClient());

    expect(
      find.byKey(const ValueKey('producer-detail-mobile-app-bar')),
      findsOneWidget,
    );
    expect(find.text('热门P主'), findsNothing);
  });

  testWidgets('tapping a discover home vocalist opens its detail page', (
    tester,
  ) async {
    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester);
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -360));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discover-vocalist-初音ミク')));
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => _LibraryFakeHttpClient());

    expect(
      find.byKey(const ValueKey('vocalist-detail-mobile-app-bar')),
      findsOneWidget,
    );
    expect(find.text('歌曲 1'), findsOneWidget);

    await tester.tap(find.text('歌曲 1'));
    await tester.pumpAndSettle();

    expect(find.text('Vocal Track'), findsOneWidget);
    expect(find.text('虚拟歌手'), findsNothing);
  });

  testWidgets('mobile shuffle resubmits the visible queue to audio playback', (
    tester,
  ) async {
    final service = _RecordingMobileAudioPlaybackService();
    addTearDown(service.dispose);

    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester, mobileAudioPlaybackService: service);
      await tester.pumpAndSettle();

      await tester.tap(find.text('GHOST').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '播放全部'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(service.playedQueues.last.map((track) => track.id), [
        101,
        102,
        103,
      ]);

      await tester.tap(find.byTooltip('随机播放'));
      await tester.pump(const Duration(milliseconds: 500));
    }, createHttpClient: (_) => _LibraryFakeHttpClient());

    expect(service.playedQueues, hasLength(greaterThanOrEqualTo(2)));
    expect(service.playedQueues.last.first.id, 101);
    expect(
      service.playedQueues.last.map((track) => track.id),
      containsAll([101, 102, 103]),
    );
  });

  testWidgets('mobile playback order button updates audio loop mode', (
    tester,
  ) async {
    final service = _RecordingMobileAudioPlaybackService();
    addTearDown(service.dispose);

    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester, mobileAudioPlaybackService: service);
      await tester.pumpAndSettle();

      await tester.tap(find.text('GHOST').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '播放全部'));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byTooltip('播放顺序：顺序播放'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byTooltip('播放顺序：列表循环'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byTooltip('播放顺序：单曲循环'));
      await tester.pump(const Duration(milliseconds: 100));
    }, createHttpClient: (_) => _LibraryFakeHttpClient());

    expect(service.orderModes, [
      MobilePlaybackOrderMode.sequential,
      MobilePlaybackOrderMode.listLoop,
      MobilePlaybackOrderMode.singleLoop,
      MobilePlaybackOrderMode.sequential,
    ]);
  });

  testWidgets('mobile audio queue receives favorite callbacks', (tester) async {
    final service = _RecordingMobileAudioPlaybackService();
    addTearDown(service.dispose);

    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester, mobileAudioPlaybackService: service);
      await tester.pumpAndSettle();

      await tester.tap(find.text('GHOST').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '播放全部'));
      await tester.pump(const Duration(milliseconds: 500));
    }, createHttpClient: (_) => _LibraryFakeHttpClient());

    expect(service.lastIsTrackFavorited, isNotNull);
    expect(service.lastToggleTrackFavorite, isNotNull);
    expect(service.lastIsTrackFavorited!(101), isFalse);
  });

  testWidgets(
    'restored mobile playback shows paused mini player and resumes from saved progress',
    (tester) async {
      final service = _RecordingMobileAudioPlaybackService();
      addTearDown(service.dispose);
      await _seedPlaybackState(progress: 0.5);

      await HttpOverrides.runZoned(() async {
        await _pumpMobileLibrary(tester, mobileAudioPlaybackService: service);
        await tester.pumpAndSettle();

        expect(find.byType(MobileMiniPlayer), findsOneWidget);
        final miniPlayer = tester.widget<MobileMiniPlayer>(
          find.byType(MobileMiniPlayer),
        );
        expect(miniPlayer.track.id, 402);
        expect(miniPlayer.isPlaying, isFalse);
        expect(miniPlayer.progress, 0.5);
        expect(service.playedQueues, isEmpty);

        await tester.tap(
          find.descendant(
            of: find.byType(MobileMiniPlayer),
            matching: find.byIcon(Icons.play_arrow),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
      }, createHttpClient: (_) => _LibraryFakeHttpClient());

      expect(service.playedQueues, hasLength(1));
      expect(service.playedQueues.single.map((track) => track.id), [401, 402]);
      expect(service.playedIndexes.single, 1);
      expect(service.orderModes.last, MobilePlaybackOrderMode.listLoop);
      expect(service.initialPositions.single, const Duration(seconds: 75));
      expect(service.seekPositions, isEmpty);
      expect(service.currentState.position, const Duration(seconds: 75));
    },
  );

  testWidgets(
    'restored mobile playback mini player opens details without starting audio',
    (tester) async {
      final service = _RecordingMobileAudioPlaybackService();
      addTearDown(service.dispose);
      await _seedPlaybackState(progress: 0.5);

      await HttpOverrides.runZoned(() async {
        await _pumpMobileLibrary(tester, mobileAudioPlaybackService: service);
        await tester.pumpAndSettle();

        await tester.tap(find.byType(MobileMiniPlayer));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.byKey(const ValueKey('mobile-player-immersive')),
          findsOneWidget,
        );
      }, createHttpClient: (_) => _LibraryFakeHttpClient());

      expect(service.playedQueues, isEmpty);
    },
  );

  testWidgets(
    'restored mobile playback at zero progress starts without seeking',
    (tester) async {
      final service = _RecordingMobileAudioPlaybackService();
      addTearDown(service.dispose);
      await _seedPlaybackState(progress: 0);

      await HttpOverrides.runZoned(() async {
        await _pumpMobileLibrary(tester, mobileAudioPlaybackService: service);
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: find.byType(MobileMiniPlayer),
            matching: find.byIcon(Icons.play_arrow),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
      }, createHttpClient: (_) => _LibraryFakeHttpClient());

      expect(service.playedQueues, hasLength(1));
      expect(service.playedIndexes.single, 1);
      expect(service.initialPositions.single, Duration.zero);
      expect(service.seekPositions, isEmpty);
    },
  );

  testWidgets('mobile back collapses MV into mobile audio playback', (
    tester,
  ) async {
    final service = _RecordingMobileAudioPlaybackService();
    addTearDown(service.dispose);

    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester, mobileAudioPlaybackService: service);
      await tester.pumpAndSettle();
      await _openAlbumMvFromDiscoverHome(tester);

      final handled = await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(handled, isTrue);
      final sheet = tester.widget<MobilePlayerSheet>(
        find.byType(MobilePlayerSheet),
      );
      expect(sheet.expanded, isFalse);
      expect(
        find.byType(MobileMiniPlayer, skipOffstage: false),
        findsOneWidget,
      );
    }, createHttpClient: (_) => _LibraryFakeHttpClient());

    expect(service.playedQueues, hasLength(1));
    expect(service.playedQueues.single.map((track) => track.id), [
      101,
      102,
      103,
    ]);
    expect(service.playedIndexes.single, 0);
  });

  testWidgets('standalone MV collapses to mini player without audio fallback', (
    tester,
  ) async {
    final service = _RecordingMobileAudioPlaybackService();
    addTearDown(service.dispose);

    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester, mobileAudioPlaybackService: service);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '更多 >').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('愛言葉V'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(const ValueKey('mobile-mv-player-surface')),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('收起').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final sheet = tester.widget<MobilePlayerSheet>(
        find.byType(MobilePlayerSheet),
      );
      expect(sheet.expanded, isFalse);
      expect(
        find.byKey(const ValueKey('mobile-mv-player-surface')),
        findsNothing,
      );
      expect(
        find.byType(MobileMiniPlayer, skipOffstage: false),
        findsOneWidget,
      );
    }, createHttpClient: (_) => _LibraryFakeHttpClient());

    expect(service.playedQueues, isEmpty);
  });

  testWidgets('failed mobile audio startup keeps MV player open on collapse', (
    tester,
  ) async {
    final service = _FailingMobileAudioPlaybackService();
    addTearDown(service.dispose);

    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester, mobileAudioPlaybackService: service);
      await tester.pumpAndSettle();
      await _openAlbumMvFromDiscoverHome(tester);

      await tester.tap(find.byTooltip('收起').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('mobile-mv-player-surface')),
        findsOneWidget,
      );
    }, createHttpClient: (_) => _LibraryFakeHttpClient());

    expect(service.playQueueAttempts, 1);
  });

  testWidgets('drag collapse keeps MV open until mobile audio starts', (
    tester,
  ) async {
    final service = _DelayedMobileAudioPlaybackService();
    addTearDown(service.dispose);

    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester, mobileAudioPlaybackService: service);
      await tester.pumpAndSettle();
      await _openAlbumMvFromDiscoverHome(tester);

      await tester.drag(
        find.byKey(const ValueKey('mobile-mv-player-surface')),
        const Offset(0, 700),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(service.playQueueAttempts, 1);
      expect(
        find.byKey(const ValueKey('mobile-mv-player-surface')),
        findsOneWidget,
      );

      service.completePlayQueue();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(
        find.byKey(const ValueKey('mobile-mv-player-surface')),
        findsNothing,
      );
      expect(find.byType(MobileMiniPlayer), findsOneWidget);
    }, createHttpClient: (_) => _LibraryFakeHttpClient());
  });

  testWidgets('stale MV collapse completion repairs current audio queue', (
    tester,
  ) async {
    final service = _FirstPlayQueueDelayedMobileAudioPlaybackService();
    addTearDown(service.dispose);

    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester, mobileAudioPlaybackService: service);
      await tester.pumpAndSettle();
      await _openAlbumMvFromDiscoverHome(tester);

      await tester.drag(
        find.byKey(const ValueKey('mobile-mv-player-surface')),
        const Offset(0, 700),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(service.playQueueAttempts, 1);

      final nextButton = find.descendant(
        of: find.byKey(const ValueKey('mobile-mv-player-surface')),
        matching: find.byIcon(Icons.skip_next),
      );
      final nextControl = tester.widget<IconButton>(
        find.ancestor(of: nextButton, matching: find.byType(IconButton)).first,
      );
      nextControl.onPressed!();
      await tester.pump(const Duration(milliseconds: 500));

      expect(service.playQueueAttempts, 2);
      expect(service.currentState.index, 1);

      service.completeFirstPlayQueue();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(service.playQueueAttempts, 3);
      expect(service.currentState.index, 1);
      expect(service.playedIndexes.last, 1);
    }, createHttpClient: (_) => _LibraryFakeHttpClient());
  });

  testWidgets('same-track MV reopen invalidates delayed collapse', (
    tester,
  ) async {
    final service = _FirstPlayQueueDelayedMobileAudioPlaybackService();
    addTearDown(service.dispose);

    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester, mobileAudioPlaybackService: service);
      await tester.pumpAndSettle();
      await _openAlbumMvFromDiscoverHome(tester);

      await tester.drag(
        find.byKey(const ValueKey('mobile-mv-player-surface')),
        const Offset(0, 700),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(service.playQueueAttempts, 1);

      final mvBadge = tester.widget<InkWell>(
        find.byKey(const ValueKey('album-track-row-mv-101')),
      );
      mvBadge.onTap!();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(const ValueKey('mobile-mv-player-surface')),
        findsOneWidget,
      );

      service.completeFirstPlayQueue();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(
        find.byKey(const ValueKey('mobile-mv-player-surface')),
        findsOneWidget,
      );
      expect(find.byType(MobileMiniPlayer), findsNothing);
    }, createHttpClient: (_) => _LibraryFakeHttpClient());
  });

  testWidgets('mixed queue returns from audio-only item to next MV', (
    tester,
  ) async {
    final service = _RecordingMobileAudioPlaybackService();
    addTearDown(service.dispose);

    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester, mobileAudioPlaybackService: service);
      await tester.pumpAndSettle();
      await _openAlbumMvFromDiscoverHome(tester);

      _invokeScopedIconButton(
        tester,
        scope: find.byKey(const ValueKey('mobile-mv-player-surface')),
        icon: Icons.skip_next,
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(const ValueKey('mobile-mv-player-surface')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('mobile-player-immersive')),
        findsOneWidget,
      );
      expect(find.text('Ghost Track 2'), findsWidgets);
      expect(service.currentState.index, 1);

      _invokeScopedIconButton(
        tester,
        scope: find.byKey(const ValueKey('mobile-player-immersive')),
        icon: Icons.skip_next,
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(const ValueKey('mobile-mv-player-surface')),
        findsOneWidget,
      );
      expect(find.text('Ghost Track 3'), findsWidgets);
    }, createHttpClient: (_) => _LibraryFakeHttpClient());
  });

  testWidgets('explicit switch to audio keeps later MV queue items audio', (
    tester,
  ) async {
    final service = _RecordingMobileAudioPlaybackService();
    addTearDown(service.dispose);

    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester, mobileAudioPlaybackService: service);
      await tester.pumpAndSettle();
      await _openAlbumMvFromDiscoverHome(tester);

      final surface = tester.widget<MobileMvPlayerSurface>(
        find.byType(MobileMvPlayerSurface),
      );
      surface.onSwitchToAudio();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(const ValueKey('mobile-player-immersive')),
        findsOneWidget,
      );

      _invokeScopedIconButton(
        tester,
        scope: find.byKey(const ValueKey('mobile-player-immersive')),
        icon: Icons.skip_next,
      );
      await tester.pump(const Duration(milliseconds: 500));

      _invokeScopedIconButton(
        tester,
        scope: find.byKey(const ValueKey('mobile-player-immersive')),
        icon: Icons.skip_next,
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(const ValueKey('mobile-mv-player-surface')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('mobile-player-immersive')),
        findsOneWidget,
      );
      expect(find.text('Ghost Track 3'), findsWidgets);
      expect(service.currentState.index, 2);
    }, createHttpClient: (_) => _LibraryFakeHttpClient());
  });

  testWidgets('explicit switch to MV keeps later MV queue items video', (
    tester,
  ) async {
    final service = _RecordingMobileAudioPlaybackService();
    addTearDown(service.dispose);

    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester, mobileAudioPlaybackService: service);
      await tester.pumpAndSettle();

      await tester.tap(find.text('GHOST').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ghost Track'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(const ValueKey('mobile-player-immersive')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mobile-mv-player-surface')),
        findsNothing,
      );

      final player = tester.widget<PlayerScreen>(find.byType(PlayerScreen));
      player.onSwitchPlaybackMode(PlaybackMode.video);
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(const ValueKey('mobile-mv-player-surface')),
        findsOneWidget,
      );

      _invokeScopedIconButton(
        tester,
        scope: find.byKey(const ValueKey('mobile-mv-player-surface')),
        icon: Icons.skip_next,
      );
      await tester.pump(const Duration(milliseconds: 500));

      _invokeScopedIconButton(
        tester,
        scope: find.byKey(const ValueKey('mobile-player-immersive')),
        icon: Icons.skip_next,
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(const ValueKey('mobile-mv-player-surface')),
        findsOneWidget,
      );
      expect(find.text('Ghost Track 3'), findsWidgets);
    }, createHttpClient: (_) => _LibraryFakeHttpClient());
  });

  testWidgets('system back returns from a mobile destination to My Music', (
    tester,
  ) async {
    await _pumpMobileLibrary(tester);

    await tester.tap(find.text('我的音乐'));
    await tester.pumpAndSettle();
    expect(find.text('收藏'), findsOneWidget);

    await tester.tap(find.text('歌单'));
    await tester.pumpAndSettle();
    expect(find.text('收藏'), findsNothing);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('歌单'), findsOneWidget);
  });

  testWidgets(
    'recent played entry opens history and plays one selected track',
    (tester) async {
      final service = _RecordingMobileAudioPlaybackService();
      addTearDown(service.dispose);

      await HttpOverrides.runZoned(() async {
        await _pumpMobileLibrary(tester, mobileAudioPlaybackService: service);
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.library_music_outlined));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(InkWell, '最近播放').first);
        await tester.pumpAndSettle();

        expect(find.text('最近播放'), findsWidgets);
        expect(find.text('Recent One'), findsOneWidget);
        expect(find.text('Recent Two'), findsOneWidget);

        await tester.tap(find.text('Recent Two'));
        await tester.pump(const Duration(milliseconds: 500));
      }, createHttpClient: (_) => _LibraryFakeHttpClient());

      expect(service.playedQueues.last.map((track) => track.id), [202]);
    },
  );

  testWidgets('recent playback history waits for ten percent progress', (
    tester,
  ) async {
    final service = _RecordingMobileAudioPlaybackService();
    final httpClient = _LibraryFakeHttpClient();
    addTearDown(service.dispose);

    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester, mobileAudioPlaybackService: service);
      await tester.pumpAndSettle();

      await tester.tap(find.text('每日推荐'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Daily One'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(httpClient.playbackHistoryPosts, isEmpty);

      await service.seek(const Duration(seconds: 18));
      await _pumpUntil(
        tester,
        () => httpClient.playbackHistoryPosts.isNotEmpty,
      );

      expect(httpClient.playbackHistoryPosts, hasLength(1));
    }, createHttpClient: (_) => httpClient);
  });

  testWidgets('recent played more opens history list', (tester) async {
    await HttpOverrides.runZoned(() async {
      await _pumpMobileLibrary(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.library_music_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '更多'));
      await tester.pumpAndSettle();

      expect(find.text('Recent One'), findsOneWidget);
      expect(find.text('Recent Two'), findsOneWidget);
    }, createHttpClient: (_) => _LibraryFakeHttpClient());
  });
}

class _LibraryRecordedRequest {
  _LibraryRecordedRequest({required this.method, required this.url});

  final String method;
  final Uri url;
}

class _LibraryFakeHttpClient implements HttpClient {
  final requests = <_LibraryRecordedRequest>[];

  List<_LibraryRecordedRequest> get playbackHistoryPosts => requests
      .where(
        (request) =>
            request.method == 'POST' &&
            request.url.path == '/api/playback/history',
      )
      .toList();

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => openUrl('GET', url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final request = _LibraryRecordedRequest(method: method, url: url);
    requests.add(request);
    return _LibraryFakeHttpClientRequest(method, url);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LibraryFakeHttpClientRequest implements HttpClientRequest {
  _LibraryFakeHttpClientRequest(this.method, this.url);

  @override
  final String method;
  final Uri url;
  bool _followRedirects = true;
  int _maxRedirects = 5;
  int _contentLength = 0;
  bool _persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async {
    return _LibraryFakeHttpClientResponse(method, url);
  }

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding _) {}

  @override
  bool get followRedirects => _followRedirects;

  @override
  set followRedirects(bool value) {
    _followRedirects = value;
  }

  @override
  int get maxRedirects => _maxRedirects;

  @override
  set maxRedirects(int value) {
    _maxRedirects = value;
  }

  @override
  int get contentLength => _contentLength;

  @override
  set contentLength(int value) {
    _contentLength = value;
  }

  @override
  bool get persistentConnection => _persistentConnection;

  @override
  set persistentConnection(bool value) {
    _persistentConnection = value;
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  @override
  void add(List<int> data) {}

  @override
  void write(Object? object) {}

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void writeln([Object? object = '']) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LibraryFakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _LibraryFakeHttpClientResponse(this.method, this.url)
    : _bytes = utf8.encode(method == 'GET' ? _bodyFor(url) : '');

  final String method;
  final Uri url;
  final List<int> _bytes;

  static String _bodyFor(Uri url) {
    if (url.path.startsWith('/api/vocalists/') &&
        url.path.endsWith('/tracks')) {
      return jsonEncode({
        'name': '初音ミク',
        'albums': [
          {
            'id': 1,
            'title': 'GHOST',
            'producer_name': 'DECO*27',
            'track_count': 1,
          },
        ],
        'tracks': [
          {
            'id': 211,
            'title': 'Vocal Track',
            'audio_path': 'vocal.flac',
            'album_id': 1,
            'track_number': 1,
            'duration_seconds': 188,
            'artists': 'DECO*27 feat. 初音ミク',
            'composer': 'DECO*27',
            'vocal': '初音ミク',
          },
        ],
      });
    }
    return switch (url.path) {
      '/api/albums' => jsonEncode({
        'albums': [
          {
            'id': 1,
            'title': 'GHOST',
            'producer_name': 'DECO*27',
            'track_count': 12,
          },
          {
            'id': 2,
            'title': '25時、ナイトコードで。',
            'producer_name': 'Neru',
            'track_count': 8,
          },
        ],
      }),
      '/api/albums/1' => jsonEncode({
        'album': {
          'id': 1,
          'title': 'GHOST',
          'producer_name': 'DECO*27',
          'track_count': 1,
        },
        'tracks': [
          {
            'id': 101,
            'title': 'Ghost Track',
            'audio_path': 'ghost.flac',
            'video_path': 'ghost.mp4',
            'album_id': 1,
            'track_number': 1,
            'duration_seconds': 219,
            'artists': 'DECO*27 feat. 初音ミク',
            'composer': 'DECO*27',
            'vocal': '初音ミク',
          },
          {
            'id': 102,
            'title': 'Ghost Track 2',
            'audio_path': 'ghost-2.flac',
            'album_id': 1,
            'track_number': 2,
            'duration_seconds': 201,
            'artists': 'DECO*27 feat. 初音ミク',
            'composer': 'DECO*27',
            'vocal': '初音ミク',
          },
          {
            'id': 103,
            'title': 'Ghost Track 3',
            'audio_path': 'ghost-3.flac',
            'video_path': 'ghost-3.mp4',
            'album_id': 1,
            'track_number': 3,
            'duration_seconds': 222,
            'artists': 'DECO*27 feat. 初音ミク',
            'composer': 'DECO*27',
            'vocal': '初音ミク',
          },
        ],
      }),
      '/api/producers' => jsonEncode({
        'producers': [
          {'id': 1, 'name': 'DECO*27', 'track_count': 27, 'album_count': 3},
        ],
      }),
      '/api/producers/1' => jsonEncode({
        'producer': {
          'id': 1,
          'name': 'DECO*27',
          'track_count': 1,
          'album_count': 1,
        },
        'albums': [
          {
            'id': 1,
            'title': 'GHOST',
            'producer_name': 'DECO*27',
            'track_count': 1,
          },
        ],
        'tracks': [
          {
            'id': 201,
            'title': 'Producer Track',
            'audio_path': 'producer.flac',
            'album_id': 1,
            'track_number': 1,
            'duration_seconds': 199,
            'artists': 'DECO*27 feat. 初音ミク',
            'composer': 'DECO*27',
            'vocal': '初音ミク',
          },
        ],
      }),
      '/api/vocalists' => jsonEncode({
        'vocalists': [
          {'name': '初音ミク', 'track_count': 30, 'album_count': 4},
        ],
      }),
      '/api/videos' => jsonEncode({
        'videos': [
          {
            'id': 1,
            'title': '愛言葉V - DECO*27 feat. 初音ミク',
            'duration_seconds': 240,
            'composer': 'DECO*27',
            'vocal': '初音ミク',
          },
        ],
      }),
      '/api/recommendations/daily' => jsonEncode({
        'date': '2026-05-22',
        'tracks': [
          {
            'id': 301,
            'title': 'Daily One',
            'audio_path': 'daily-one.flac',
            'duration_seconds': 180,
            'composer': 'kz',
            'vocal': '初音ミク',
          },
          {
            'id': 302,
            'title': 'Daily Two',
            'audio_path': 'daily-two.flac',
            'duration_seconds': 201,
            'composer': 'ryo',
            'vocal': '初音ミク',
          },
        ],
      }),
      '/api/playback/history' => jsonEncode({
        'items': [
          {
            'track': {
              'id': 201,
              'title': 'Recent One',
              'audio_path': 'recent-one.flac',
              'album_id': 1,
              'duration_seconds': 180,
              'composer': 'PinocchioP',
              'vocal': '初音ミク',
            },
            'position_ms': 12000,
            'duration_ms': 180000,
            'playback_mode': 'audio',
            'context_label': 'Album / Recent',
            'played_at': 1779072000,
          },
          {
            'track': {
              'id': 202,
              'title': 'Recent Two',
              'audio_path': 'recent-two.flac',
              'album_id': 1,
              'duration_seconds': 200,
              'composer': 'ryo',
              'vocal': '初音ミク',
            },
            'position_ms': 30000,
            'duration_ms': 200000,
            'playback_mode': 'audio',
            'context_label': 'Album / Recent',
            'played_at': 1779071000,
          },
        ],
      }),
      _ => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"></svg>',
    };
  }

  @override
  int get contentLength => _bytes.length;

  @override
  int get statusCode => method == 'GET' ? HttpStatus.ok : HttpStatus.noContent;

  @override
  HttpHeaders get headers => _LibraryFakeHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<Cookie> get cookies => const [];

  @override
  Future<Socket> detachSocket() {
    throw UnimplementedError();
  }

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  String get reasonPhrase => 'OK';

  @override
  bool get persistentConnection => false;

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) {
    throw UnimplementedError();
  }

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> data)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LibraryFakeHttpHeaders implements HttpHeaders {
  static const Map<String, List<String>> _values = {
    HttpHeaders.contentTypeHeader: ['application/json'],
  };

  @override
  List<String>? operator [](String name) {
    return _values[name.toLowerCase()];
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingMobileAudioPlaybackService
    extends FakeMobileAudioPlaybackService {
  final playedQueues = <List<Track>>[];
  final playedIndexes = <int>[];
  final orderModes = <MobilePlaybackOrderMode>[];
  final initialPositions = <Duration>[];
  final seekPositions = <Duration>[];
  TrackFavoriteStatus? lastIsTrackFavorited;
  TrackFavoriteToggle? lastToggleTrackFavorite;
  int clearCacheCalls = 0;

  @override
  Future<void> clearCache() async {
    clearCacheCalls += 1;
    await super.clearCache();
  }

  @override
  Future<void> playQueue({
    required List<Track> queue,
    required int index,
    required AudioUrlForTrack audioUrlForTrack,
    CoverUrlForTrack? coverUrlForTrack,
    MobilePlaybackOrderMode orderMode = MobilePlaybackOrderMode.sequential,
    Duration initialPosition = Duration.zero,
    TrackFavoriteStatus? isTrackFavorited,
    TrackFavoriteToggle? toggleTrackFavorite,
  }) {
    playedQueues.add(List<Track>.from(queue));
    playedIndexes.add(index);
    orderModes.add(orderMode);
    initialPositions.add(initialPosition);
    lastIsTrackFavorited = isTrackFavorited;
    lastToggleTrackFavorite = toggleTrackFavorite;
    return super.playQueue(
      queue: queue,
      index: index,
      audioUrlForTrack: audioUrlForTrack,
      coverUrlForTrack: coverUrlForTrack,
      orderMode: orderMode,
      initialPosition: initialPosition,
      isTrackFavorited: isTrackFavorited,
      toggleTrackFavorite: toggleTrackFavorite,
    );
  }

  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
    await super.seek(position);
  }

  @override
  Future<void> setPlaybackOrderMode(MobilePlaybackOrderMode orderMode) async {
    orderModes.add(orderMode);
    await super.setPlaybackOrderMode(orderMode);
  }
}

class _FailingMobileAudioPlaybackService
    extends _RecordingMobileAudioPlaybackService {
  int playQueueAttempts = 0;

  @override
  Future<void> playQueue({
    required List<Track> queue,
    required int index,
    required AudioUrlForTrack audioUrlForTrack,
    CoverUrlForTrack? coverUrlForTrack,
    MobilePlaybackOrderMode orderMode = MobilePlaybackOrderMode.sequential,
    Duration initialPosition = Duration.zero,
    TrackFavoriteStatus? isTrackFavorited,
    TrackFavoriteToggle? toggleTrackFavorite,
  }) async {
    playQueueAttempts += 1;
    throw StateError('audio startup failed');
  }
}

class _DelayedMobileAudioPlaybackService
    extends _RecordingMobileAudioPlaybackService {
  final Completer<void> _playQueueCompleter = Completer<void>();
  int playQueueAttempts = 0;

  void completePlayQueue() {
    if (!_playQueueCompleter.isCompleted) {
      _playQueueCompleter.complete();
    }
  }

  @override
  Future<void> playQueue({
    required List<Track> queue,
    required int index,
    required AudioUrlForTrack audioUrlForTrack,
    CoverUrlForTrack? coverUrlForTrack,
    MobilePlaybackOrderMode orderMode = MobilePlaybackOrderMode.sequential,
    Duration initialPosition = Duration.zero,
    TrackFavoriteStatus? isTrackFavorited,
    TrackFavoriteToggle? toggleTrackFavorite,
  }) async {
    playQueueAttempts += 1;
    await _playQueueCompleter.future;
    await super.playQueue(
      queue: queue,
      index: index,
      audioUrlForTrack: audioUrlForTrack,
      coverUrlForTrack: coverUrlForTrack,
      orderMode: orderMode,
      initialPosition: initialPosition,
      isTrackFavorited: isTrackFavorited,
      toggleTrackFavorite: toggleTrackFavorite,
    );
  }

  @override
  Future<void> dispose() async {
    completePlayQueue();
    await super.dispose();
  }
}

class _FirstPlayQueueDelayedMobileAudioPlaybackService
    extends _RecordingMobileAudioPlaybackService {
  final Completer<void> _firstPlayQueueCompleter = Completer<void>();
  int playQueueAttempts = 0;

  void completeFirstPlayQueue() {
    if (!_firstPlayQueueCompleter.isCompleted) {
      _firstPlayQueueCompleter.complete();
    }
  }

  @override
  Future<void> playQueue({
    required List<Track> queue,
    required int index,
    required AudioUrlForTrack audioUrlForTrack,
    CoverUrlForTrack? coverUrlForTrack,
    MobilePlaybackOrderMode orderMode = MobilePlaybackOrderMode.sequential,
    Duration initialPosition = Duration.zero,
    TrackFavoriteStatus? isTrackFavorited,
    TrackFavoriteToggle? toggleTrackFavorite,
  }) async {
    playQueueAttempts += 1;
    if (playQueueAttempts == 1) {
      await _firstPlayQueueCompleter.future;
    }
    await super.playQueue(
      queue: queue,
      index: index,
      audioUrlForTrack: audioUrlForTrack,
      coverUrlForTrack: coverUrlForTrack,
      orderMode: orderMode,
      initialPosition: initialPosition,
      isTrackFavorited: isTrackFavorited,
      toggleTrackFavorite: toggleTrackFavorite,
    );
  }

  @override
  Future<void> dispose() async {
    completeFirstPlayQueue();
    await super.dispose();
  }
}

Future<void> _seedPlaybackState({required double progress}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'mikudrome_queue': jsonEncode([
      {
        'id': 401,
        'title': 'Resume One',
        'audio_path': 'resume-one.flac',
        'video_path': '',
        'album_id': 4,
        'duration_seconds': 120,
        'vocal': '初音ミク',
      },
      {
        'id': 402,
        'title': 'Resume Two',
        'audio_path': 'resume-two.flac',
        'video_path': '',
        'album_id': 4,
        'duration_seconds': 150,
        'vocal': '鏡音リン',
      },
    ]),
    'mikudrome_index': '1',
    'mikudrome_progress': progress.toString(),
    'mikudrome_mode': 'audio',
    'mikudrome_order_mode': 'listLoop',
    'mikudrome_context': 'Playlist / Resume',
  });
  await PlaybackStorage.ensureInitialized();
}

Future<void> _openAlbumMvFromDiscoverHome(WidgetTester tester) async {
  await tester.tap(find.text('GHOST').last);
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey('album-track-row-mv-101')));
  await tester.pump(const Duration(milliseconds: 500));

  expect(
    find.byKey(const ValueKey('mobile-mv-player-surface')),
    findsOneWidget,
  );
}

void _invokeScopedIconButton(
  WidgetTester tester, {
  required Finder scope,
  required IconData icon,
}) {
  final iconFinder = find.descendant(of: scope, matching: find.byIcon(icon));
  final control = tester.widget<IconButton>(
    find.ancestor(of: iconFinder, matching: find.byType(IconButton)).first,
  );
  control.onPressed!();
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int attempts = 10,
}) async {
  for (var i = 0; i < attempts && !condition(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpMobileLibrary(
  WidgetTester tester, {
  MobileAudioPlaybackService? mobileAudioPlaybackService,
  AppConfigController? appConfigController,
  Size size = const Size(390, 844),
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  return tester.pumpWidget(
    MaterialApp(
      home: LibraryHomeScreen(
        appConfigController: appConfigController,
        mobileAudioPlaybackService: mobileAudioPlaybackService,
      ),
    ),
  );
}

class _MemoryAppConfigStore implements AppConfigStore {
  _MemoryAppConfigStore({this.serverUrl, this.serverCookie});

  String? serverUrl;
  String? serverCookie;

  @override
  Future<String?> loadServerUrl() async => serverUrl;

  @override
  Future<String?> loadServerCookie() async => serverCookie;

  @override
  Future<void> saveServerUrl(String serverUrl) async {
    this.serverUrl = serverUrl;
  }

  @override
  Future<void> saveServerCookie(String? serverCookie) async {
    this.serverCookie = serverCookie;
  }

  @override
  Future<void> clearServerUrl() async {
    serverUrl = null;
  }

  @override
  Future<void> clearServerCookie() async {
    serverCookie = null;
  }
}
