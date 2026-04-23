import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/api/api_client.dart';
import 'package:mikudrome/models/playlist.dart';
import 'package:mikudrome/models/playlist_detail_data.dart';
import 'package:mikudrome/models/playlist_group.dart';
import 'package:mikudrome/models/playlist_item.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/screens/playlist_detail_screen.dart';
import 'package:mikudrome/services/playlist_repository.dart';
import 'package:mikudrome/widgets/playlist_detail/playlist_cover_grid.dart';
import 'package:mikudrome/widgets/playlist_detail/playlist_item_editor_sheet.dart';
import 'package:mikudrome/widgets/playlist_detail/playlist_track_row.dart';

void main() {
  setUp(() {
    PlaylistRepository.instance.removePlaylist(7);
  });

  tearDown(() {
    PlaylistRepository.instance.removePlaylist(7);
  });

  testWidgets('PlaylistDetailScreen renders grouped sections and item notes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlaylistDetailScreen(
          playlistId: 7,
          client: _FakeApiClient(
            PlaylistDetailData.fromJson({
              'playlist': {
                'id': 7,
                'name': 'Focus Mix',
                'track_count': 1,
                'cover_track_ids': [],
                'cover_album_ids': [],
              },
              'groups': [
                {
                  'id': 1,
                  'playlist_id': 7,
                  'title': 'Act 1',
                  'position': 0,
                  'is_system': true,
                  'created_at': 0,
                  'updated_at': 0,
                  'items': [
                    {
                      'id': 101,
                      'playlist_id': 7,
                      'track_id': 11,
                      'group_id': 1,
                      'position': 0,
                      'note': 'intro note',
                      'cover_mode': 'default',
                      'library_cover_id': '',
                      'cached_cover_url': '',
                      'custom_cover_path': '',
                      'created_at': 0,
                      'updated_at': 0,
                      'track': {
                        'id': 11,
                        'title': 'Track A',
                        'audio_path': '/music/a.flac',
                        'video_path': '',
                      },
                    },
                  ],
                },
              ],
            }),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Act 1'), findsOneWidget);
    expect(find.text('Track A'), findsOneWidget);
    expect(find.text('intro note'), findsOneWidget);

    PlaylistRepository.instance.upsertPlaylist(
      const Playlist(
        id: 7,
        name: 'Stale Name',
        trackCount: 0,
      ),
    );
    await tester.pump();

    expect(find.text('Focus Mix'), findsOneWidget);
    expect(find.text('Stale Name'), findsNothing);
  });

  testWidgets('PlaylistDetailScreen shows desktop display mode switch', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: PlaylistDetailScreen(
          playlistId: 7,
          client: _FakeApiClient(_buildReorderableDetail()),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('playlist-display-mode-switch')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('playlist-display-mode-list-icon')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('playlist-display-mode-cover-icon')),
      findsOneWidget,
    );
    expect(find.text('歌单'), findsNothing);
    expect(find.text('封面'), findsNothing);
  });

  testWidgets(
    'PlaylistDetailScreen keeps desktop display mode switch compact on one row',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: _FakeApiClient(_buildReorderableDetail()),
          ),
        ),
      );
      await tester.pump();

      final switchSize = tester.getSize(
        find.byKey(const ValueKey('playlist-display-mode-switch')),
      );
      expect(switchSize.height, lessThanOrEqualTo(44));
      expect(switchSize.width, lessThanOrEqualTo(132));
    },
  );

  testWidgets(
    'PlaylistDetailScreen desktop cover mode switches grouped content rendering',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: _FakeApiClient(_buildReorderableDetail()),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('playlist-cover-grid')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('playlist-track-row-title-desktop-101')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('playlist-display-mode-cover-icon')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('playlist-cover-grid')),
        findsWidgets,
      );
      expect(
        find.byKey(const ValueKey('playlist-track-row-title-desktop-101')),
        findsNothing,
      );
      expect(find.text('Ungrouped'), findsOneWidget);
      expect(find.text('Act 2'), findsOneWidget);
    },
  );

  testWidgets(
    'PlaylistDetailScreen cover mode adds more space between group title and covers',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: _FakeApiClient(_buildReorderableDetail()),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('playlist-display-mode-cover-icon')),
      );
      await tester.pumpAndSettle();

      final titleBottom = tester.getBottomLeft(find.text('Ungrouped')).dy;
      final coverTop = tester
          .getTopLeft(find.byKey(const ValueKey('playlist-cover-card-101')))
          .dy;

      expect(coverTop - titleBottom, greaterThanOrEqualTo(16));
    },
  );

  testWidgets('PlaylistDetailScreen cover mode renders square cover media', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: PlaylistDetailScreen(
          playlistId: 7,
          client: _FakeApiClient(_buildReorderableDetail()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('playlist-display-mode-cover-icon')),
    );
    await tester.pumpAndSettle();

    final coverSize = tester.getSize(
      find.byKey(const ValueKey('playlist-cover-media-101')),
    );
    expect(coverSize.width, closeTo(coverSize.height, 0.1));
  });

  testWidgets('PlaylistDetailScreen cover mode uses a compact play button', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: PlaylistDetailScreen(
          playlistId: 7,
          client: _FakeApiClient(_buildReorderableDetail()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('playlist-display-mode-cover-icon')),
    );
    await tester.pumpAndSettle();

    final playButtonSize = tester.getSize(
      find.byKey(const ValueKey('playlist-cover-play-101')),
    );
    expect(playButtonSize.width, lessThanOrEqualTo(40));
    expect(playButtonSize.height, lessThanOrEqualTo(40));
  });

  testWidgets(
    'PlaylistDetailScreen cover mode only shows play button on hover',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: _FakeApiClient(_buildReorderableDetail()),
            currentPlayingTrackId: 11,
            isPlaying: true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('playlist-display-mode-cover-icon')),
      );
      await tester.pumpAndSettle();

      final hiddenOpacity = tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('playlist-cover-play-opacity-101')),
      );
      expect(hiddenOpacity.opacity, 0);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer();
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('playlist-cover-card-101'))),
      );
      await tester.pumpAndSettle();

      final visibleOpacity = tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('playlist-cover-play-opacity-101')),
      );
      expect(visibleOpacity.opacity, 1);
    },
  );

  testWidgets('PlaylistDetailScreen cover mode shows title toggle on desktop', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: PlaylistDetailScreen(
          playlistId: 7,
          client: _FakeApiClient(_buildReorderableDetail()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('playlist-display-mode-cover-icon')),
    );
    await tester.pumpAndSettle();

    expect(find.text('显示标题'), findsOneWidget);
    expect(find.byKey(const ValueKey('playlist-cover-title-toggle')),
        findsOneWidget);
  });

  testWidgets('PlaylistDetailScreen cover mode uses a compact title toggle', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: PlaylistDetailScreen(
          playlistId: 7,
          client: _FakeApiClient(_buildReorderableDetail()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('playlist-display-mode-cover-icon')),
    );
    await tester.pumpAndSettle();

    final titleToggleSize = tester.getSize(
      find.byKey(const ValueKey('playlist-cover-title-control')),
    );
    expect(titleToggleSize.height, lessThanOrEqualTo(36));
  });

  testWidgets(
    'PlaylistDetailScreen cover mode can hide persistent titles and shrink cards',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: _FakeApiClient(_buildReorderableDetail()),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('playlist-display-mode-cover-icon')),
      );
      await tester.pumpAndSettle();

      final initialCardHeight = tester
          .getSize(find.byKey(const ValueKey('playlist-cover-card-101')))
          .height;
      expect(find.text('Track A'), findsOneWidget);

      await tester
          .tap(find.byKey(const ValueKey('playlist-cover-title-toggle')));
      await tester.pumpAndSettle();

      final collapsedCardHeight = tester
          .getSize(find.byKey(const ValueKey('playlist-cover-card-101')))
          .height;
      expect(collapsedCardHeight, lessThan(initialCardHeight));
      expect(find.text('Track A'), findsNothing);
    },
  );

  testWidgets(
    'PlaylistDetailScreen hidden cover titles appear on hover overlay',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: _FakeApiClient(_buildReorderableDetail()),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('playlist-display-mode-cover-icon')),
      );
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('playlist-cover-title-toggle')));
      await tester.pumpAndSettle();

      expect(find.text('Track A'), findsNothing);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer();
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('playlist-cover-card-101'))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Track A'), findsOneWidget);
    },
  );

  testWidgets(
    'PlaylistDetailScreen cover mode selects current playing item when available',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: _FakeApiClient(_buildReorderableDetail()),
            currentPlayingTrackId: 12,
            isPlaying: true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('playlist-display-mode-cover-icon')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('playlist-cover-card-selected-102')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'PlaylistDetailScreen cover mode selects first item when nothing is playing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: _FakeApiClient(_buildReorderableDetail()),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('playlist-display-mode-cover-icon')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('playlist-cover-card-selected-101')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'PlaylistDetailScreen cover mode taps to select another visible item',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: _FakeApiClient(_buildReorderableDetail()),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('playlist-display-mode-cover-icon')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('playlist-cover-card-102')));
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.byKey(const ValueKey('playlist-cover-card-selected-102')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('playlist-cover-card-selected-101')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'PlaylistDetailScreen cover mode double tap plays selected item',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Track? playedTrack;
      List<Track>? playedQueue;
      int? playedIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: _FakeApiClient(_buildReorderableDetail()),
            onPlayTrack: (track, queue, index) {
              playedTrack = track;
              playedQueue = queue;
              playedIndex = index;
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('playlist-display-mode-cover-icon')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('playlist-cover-card-102')));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(find.byKey(const ValueKey('playlist-cover-card-102')));
      await tester.pumpAndSettle();

      expect(playedTrack?.id, 12);
      expect(playedQueue?.length, 3);
      expect(playedIndex, 1);
    },
  );

  testWidgets('PlaylistDetailScreen keeps mobile layout without display switch',
      (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: _FakeApiClient(_buildReorderableDetail()),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('playlist-display-mode-switch')),
      findsNothing,
    );
    expect(find.text('歌单'), findsNothing);
    expect(find.text('封面'), findsNothing);
  });

  testWidgets(
    'PlaylistDetailScreen hero cover opens and closes the lightbox without affecting actions',
    (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: _FakeApiClient(_buildReorderableDetail()),
          ),
        ),
      );
      await tester.pump();

      expect(find.widgetWithText(FilledButton, 'PLAY'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'EDIT'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Open playlist cover preview'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('playlist-hero-cover-trigger')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('detail-cover-lightbox')), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('detail-cover-lightbox-close-button')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('detail-cover-lightbox')), findsNothing);
      expect(find.widgetWithText(FilledButton, 'PLAY'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'EDIT'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'PlaylistDetailScreen edit mode adds groups and saves item metadata',
    (tester) async {
      final client = _EditableFakeApiClient(_buildEditableDetail());

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: client,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('EDIT'), findsOneWidget);
      await tester.tap(find.text('EDIT'));
      await tester.pumpAndSettle();

      expect(find.text('DONE'), findsOneWidget);
      expect(find.text('ADD GROUP'), findsOneWidget);

      await tester.tap(find.text('ADD GROUP'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Act 2');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Act 2'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Edit Playlist Item'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(TextField, 'Note'), 'updated note');
      await tester.tap(find.widgetWithText(RadioListTile<int>, 'Act 2'));
      await tester.pumpAndSettle();
      await tester
          .tap(find.widgetWithText(RadioListTile<String>, 'Custom Cover'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(client.createdGroupTitles, ['Act 2']);
      expect(client.updatedItemRequests.length, 1);
      expect(client.updatedItemRequests.single.itemId, 101);
      expect(client.updatedItemRequests.single.request.groupId, 2);
      expect(client.updatedItemRequests.single.request.note, 'updated note');
      expect(client.updatedItemRequests.single.request.coverMode, 'custom');
      expect(find.text('updated note'), findsOneWidget);

      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();

      expect(find.text('ADD GROUP'), findsNothing);
    },
  );

  testWidgets(
    'PlaylistDetailScreen edit mode removes item from playlist',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final client = _EditableFakeApiClient(_buildEditableDetail());

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: client,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('EDIT'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove from playlist'));
      await tester.pumpAndSettle();

      expect(client.removedTrackIds, [
        [11],
      ]);
      expect(find.text('Track A'), findsNothing);
      expect(find.text('No tracks in this playlist'), findsOneWidget);
    },
  );

  testWidgets(
    'PlaylistDetailScreen edit mode drags items between groups with grouped reorder payload',
    (tester) async {
      final client = _EditableFakeApiClient(_buildReorderableDetail());

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: client,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('EDIT'));
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Act 2'),
        find.byType(CustomScrollView),
        const Offset(0, -160),
      );
      await tester.pumpAndSettle();

      final handle =
          find.byKey(const ValueKey('playlist-item-101-drag-handle'));
      final target = find.byKey(const ValueKey('playlist-group-2-slot-1'));

      expect(handle, findsOneWidget);
      expect(target, findsOneWidget);

      final start = tester.getCenter(handle);
      final end = tester.getCenter(target);
      final gesture = await tester.startGesture(start);
      await tester.pump();
      await gesture.moveTo(end);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(client.reorderRequests, hasLength(1));
      expect(client.reorderRequests.single, hasLength(2));
      expect(client.reorderRequests.single[0].id, 1);
      expect(client.reorderRequests.single[0].itemIds, [102]);
      expect(client.reorderRequests.single[1].id, 2);
      expect(client.reorderRequests.single[1].itemIds, [201, 101]);
    },
  );

  testWidgets(
    'PlaylistDetailScreen reveals group quick actions on desktop hover and keeps delete hidden for system group',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: _EditableFakeApiClient(_buildThreeGroupDetail()),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('playlist-group-2-rename-button')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('playlist-group-1-rename-button')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('playlist-group-1-more-button')),
        findsNothing,
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer();
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('playlist-group-header-1'))),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('playlist-group-1-rename-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('playlist-group-1-drag-handle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('playlist-group-1-more-button')),
        findsNothing,
      );

      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('playlist-group-header-2'))),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('playlist-group-2-rename-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('playlist-group-2-more-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('playlist-group-2-drag-handle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('playlist-group-2-more-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('playlist-group-1-more-button')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'PlaylistDetailScreen renames system group from quick actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final client = _EditableFakeApiClient(_buildThreeGroupDetail());

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: client,
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer();
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('playlist-group-header-1'))),
      );
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('playlist-group-1-rename-button')));
      await tester.pumpAndSettle();

      expect(find.text('Rename Group'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Loose Tracks');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(client.renamedGroups, [
        (playlistId: 7, groupId: 1, title: 'Loose Tracks'),
      ]);
      expect(find.text('Loose Tracks'), findsOneWidget);
      expect(find.text('Ungrouped'), findsNothing);
    },
  );

  testWidgets(
    'PlaylistDetailScreen renames normal groups from quick actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final client = _EditableFakeApiClient(_buildThreeGroupDetail());

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: client,
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer();
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('playlist-group-header-2'))),
      );
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('playlist-group-2-rename-button')));
      await tester.pumpAndSettle();

      expect(find.text('Rename Group'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Act II');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(client.renamedGroups, [
        (playlistId: 7, groupId: 2, title: 'Act II'),
      ]);
      expect(find.text('Act II'), findsOneWidget);
      expect(find.text('Act 2'), findsNothing);
    },
  );

  testWidgets(
    'PlaylistDetailScreen confirms deleting normal groups and moves items to Ungrouped',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final client = _EditableFakeApiClient(_buildThreeGroupDetail());

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: client,
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer();
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('playlist-group-header-2'))),
      );
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('playlist-group-2-more-button')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('playlist-group-2-delete-action')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Delete group'), findsOneWidget);
      expect(find.textContaining('Act 2'), findsAtLeastNWidgets(1));
      expect(find.text('Tracks in this group will move to Ungrouped.'),
          findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(client.deletedGroups, [
        (playlistId: 7, groupId: 2),
      ]);
      expect(find.text('Act 2'), findsNothing);
      expect(find.text('Track C'), findsOneWidget);
    },
  );

  testWidgets(
    'PlaylistDetailScreen drags normal groups with grouped reorder payload order',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final client = _EditableFakeApiClient(_buildThreeGroupDetail());

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: client,
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer();
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('playlist-group-header-3'))),
      );
      await tester.pumpAndSettle();

      final handle = find.byKey(const ValueKey('playlist-group-3-drag-handle'));
      final target = find.byKey(const ValueKey('playlist-group-drop-slot-1'));

      expect(handle, findsOneWidget);
      expect(target, findsOneWidget);

      final start = tester.getCenter(handle);
      final end = tester.getCenter(target);
      final drag = await tester.startGesture(start);
      await tester.pump();
      await drag.moveTo(end);
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();

      expect(client.reorderRequests, hasLength(1));
      expect(client.reorderRequests.single.map((group) => group.id).toList(),
          [1, 3, 2]);
      expect(find.text('Finale'), findsOneWidget);
    },
  );

  testWidgets(
    'PlaylistDetailScreen lets system group participate in group reorder',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final client = _EditableFakeApiClient(_buildThreeGroupDetail());

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: client,
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer();
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('playlist-group-header-1'))),
      );
      await tester.pumpAndSettle();

      final handle = find.byKey(const ValueKey('playlist-group-1-drag-handle'));
      final target = find.byKey(const ValueKey('playlist-group-drop-slot-2'));

      expect(handle, findsOneWidget);
      expect(target, findsOneWidget);

      final start = tester.getCenter(handle);
      final end = tester.getCenter(target);
      final drag = await tester.startGesture(start);
      await tester.pump();
      await drag.moveTo(end);
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();

      expect(client.reorderRequests, hasLength(1));
      expect(
        client.reorderRequests.single.map((group) => group.id).toList(),
        [2, 1, 3],
      );
    },
  );

  testWidgets('PlaylistTrackRow.track keeps legacy track callers working', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlaylistTrackRow.track(
            track: Track(
              id: 21,
              title: 'Legacy Track',
              audioPath: '/music/legacy.flac',
              videoPath: '',
            ),
            baseUrl: '',
            onTap: _noop,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Legacy Track'), findsOneWidget);
  });

  testWidgets(
    'Custom item cover overrides default cover in playlist detail',
    (tester) async {
      const item = PlaylistItem(
        id: 9,
        playlistId: 7,
        trackId: 3,
        groupId: 1,
        position: 0,
        note: '',
        coverMode: 'custom',
        customCoverPath: 'http://example.test/custom.jpg',
        track: Track(
          id: 3,
          title: 'Track A',
          audioPath: '/a.flac',
          videoPath: '',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaylistTrackRow(
              item: item,
              baseUrl: 'http://example.test',
              onTap: _noop,
              onRemove: _noop,
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image).first);
      final provider =
          (image.image as ResizeImage).imageProvider as NetworkImage;
      expect(provider.url, 'http://example.test/custom.jpg');
    },
  );

  testWidgets(
    'PlaylistCoverGrid falls back to album cover for album-backed tracks',
    (tester) async {
      const item = PlaylistItem(
        id: 12,
        playlistId: 7,
        trackId: 6,
        groupId: 1,
        position: 0,
        note: '',
        coverMode: 'default',
        track: Track(
          id: 6,
          title: 'Album Backed Track',
          audioPath: '/album.flac',
          videoPath: '',
          albumId: 42,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaylistCoverGrid(
              items: const [item],
              selectedItemId: null,
              baseUrl: 'http://example.test',
              showTitles: true,
              onSelect: (_) {},
              onPlay: (_) {},
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image).first;
      final image = tester.widget<Image>(imageFinder);
      final fallback = image.errorBuilder!(
        tester.element(imageFinder),
        Exception('cover load failed'),
        StackTrace.empty,
      );

      expect(fallback, isA<Image>());
      final provider = ((fallback as Image).image as ResizeImage).imageProvider
          as NetworkImage;
      expect(provider.url, 'http://example.test/api/albums/42/cover');
    },
  );

  testWidgets(
    'PlaylistTrackRow shows note in dedicated desktop column',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const item = PlaylistItem(
        id: 10,
        playlistId: 7,
        trackId: 4,
        groupId: 1,
        position: 0,
        note: 'desktop note',
        coverMode: 'default',
        track: Track(
          id: 4,
          title: 'Column Track',
          audioPath: '/column.flac',
          videoPath: '',
          vocal: 'Miku',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(1280, 900)),
            child: Scaffold(
              body: PlaylistTrackRow(
                item: item,
                baseUrl: 'http://example.test',
                onTap: _noop,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('playlist-track-row-title-desktop-10')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('playlist-track-row-note-desktop')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('playlist-track-row-note-mobile')),
          findsNothing);
      expect(find.text('desktop note'), findsOneWidget);

      final titleWidth = tester
          .getSize(
            find.byKey(const ValueKey('playlist-track-row-title-desktop-10')),
          )
          .width;
      expect(titleWidth, lessThan(320));

      final noteText = tester.widget<Text>(
        find.byKey(const ValueKey('playlist-track-row-note-desktop')),
      );
      expect(noteText.maxLines, 3);

      final noteLeft = tester
          .getTopLeft(
              find.byKey(const ValueKey('playlist-track-row-note-desktop')))
          .dx;
      expect(noteLeft, lessThan(600));
    },
  );

  testWidgets(
    'PlaylistTrackRow keeps note under title on mobile',
    (tester) async {
      const item = PlaylistItem(
        id: 11,
        playlistId: 7,
        trackId: 5,
        groupId: 1,
        position: 0,
        note: 'mobile note',
        coverMode: 'default',
        track: Track(
          id: 5,
          title: 'Mobile Track',
          audioPath: '/mobile.flac',
          videoPath: '',
          vocal: 'Miku',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(390, 844)),
            child: Scaffold(
              body: PlaylistTrackRow(
                item: item,
                baseUrl: 'http://example.test',
                onTap: _noop,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('playlist-track-row-note-mobile')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('playlist-track-row-note-desktop')),
          findsNothing);
      expect(find.text('mobile note'), findsOneWidget);

      final noteText = tester.widget<Text>(
        find.byKey(const ValueKey('playlist-track-row-note-mobile')),
      );
      expect(noteText.maxLines, 3);
    },
  );

  testWidgets(
    'PlaylistDetailScreen uses minimum shared desktop title width for short titles',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: _FakeApiClient(
              _buildDesktopTitleWidthDetail(
                shortTitle: 'A',
                longTitle: 'Short Song',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final firstTitle = find.byKey(
        const ValueKey('playlist-track-row-title-desktop-101'),
      );
      final secondTitle = find.byKey(
        const ValueKey('playlist-track-row-title-desktop-102'),
      );

      expect(firstTitle, findsOneWidget);
      expect(secondTitle, findsOneWidget);
      expect(tester.getSize(firstTitle).width, 220);
      expect(tester.getSize(secondTitle).width, 220);
    },
  );

  testWidgets(
    'PlaylistDetailScreen clamps shared desktop title width to max for long titles',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: _FakeApiClient(
              _buildDesktopTitleWidthDetail(
                shortTitle: 'A',
                longTitle:
                    'An Extremely Long Playlist Song Title That Should Hit The Desktop Clamp Width Limit',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final firstTitle = find.byKey(
        const ValueKey('playlist-track-row-title-desktop-101'),
      );
      final secondTitle = find.byKey(
        const ValueKey('playlist-track-row-title-desktop-102'),
      );

      expect(firstTitle, findsOneWidget);
      expect(secondTitle, findsOneWidget);
      expect(tester.getSize(firstTitle).width, 420);
      expect(tester.getSize(secondTitle).width, 420);
    },
  );

  testWidgets(
    'PlaylistItemEditorSheet snapshots library cover for album-backed tracks',
    (tester) async {
      PlaylistItemUpdateRequest? savedRequest;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaylistItemEditorSheet(
              item: const PlaylistItem(
                id: 9,
                playlistId: 7,
                trackId: 3,
                groupId: 1,
                position: 0,
                note: '',
                coverMode: 'default',
                track: Track(
                  id: 3,
                  title: 'Track A',
                  audioPath: '/a.flac',
                  videoPath: '',
                  albumId: 42,
                ),
              ),
              groups: const [
                PlaylistGroup(
                  id: 1,
                  playlistId: 7,
                  title: 'Ungrouped',
                  isSystem: true,
                ),
              ],
              onSave: (request) async {
                savedRequest = request;
              },
            ),
          ),
        ),
      );

      await tester
          .tap(find.widgetWithText(RadioListTile<String>, 'Library Cover'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedRequest, isNotNull);
      expect(savedRequest!.coverMode, 'library');
      expect(savedRequest!.libraryCoverId, 'album:42');
      expect(savedRequest!.cachedCoverUrl, '/api/albums/42/cover');
    },
  );

  testWidgets('PlaylistDetailScreen shows fetch errors with retry affordance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlaylistDetailScreen(
          playlistId: 7,
          client: _ThrowingApiClient(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Failed to load grouped items'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Playlist not found'), findsNothing);
  });

  testWidgets(
    'PlaylistDetailScreen keeps error state when cached playlist metadata exists',
    (tester) async {
      PlaylistRepository.instance.upsertPlaylist(
        const Playlist(
          id: 7,
          name: 'Cached Playlist',
          trackCount: 3,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 7,
            client: _ThrowingApiClient(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Cached Playlist'), findsOneWidget);
      expect(find.text('Failed to load grouped items'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Playlist not found'), findsNothing);
      expect(_playButton(tester).onPressed, isNull);
    },
  );

  testWidgets('PlaylistDetailScreen retry can recover to grouped content', (
    tester,
  ) async {
    final client = _FlakyApiClient(
      PlaylistDetailData.fromJson({
        'playlist': {
          'id': 7,
          'name': 'Recovered Mix',
          'track_count': 1,
          'cover_track_ids': [],
          'cover_album_ids': [],
        },
        'groups': [
          {
            'id': 1,
            'playlist_id': 7,
            'title': 'Recovered Group',
            'position': 0,
            'is_system': true,
            'created_at': 0,
            'updated_at': 0,
            'items': [
              {
                'id': 201,
                'playlist_id': 7,
                'track_id': 31,
                'group_id': 1,
                'position': 0,
                'note': 'back again',
                'cover_mode': 'default',
                'library_cover_id': '',
                'cached_cover_url': '',
                'custom_cover_path': '',
                'created_at': 0,
                'updated_at': 0,
                'track': {
                  'id': 31,
                  'title': 'Track B',
                  'audio_path': '/music/b.flac',
                  'video_path': '',
                },
              },
            ],
          },
        ],
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PlaylistDetailScreen(
          playlistId: 7,
          client: client,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Failed to load grouped items'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Recovered Group'), findsOneWidget);
    expect(find.text('Track B'), findsOneWidget);
    expect(find.text('back again'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(_playButton(tester).onPressed, isNotNull);
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient(this.detail) : super(baseUrl: 'http://example.test');

  final PlaylistDetailData detail;

  @override
  Future<PlaylistDetailData> getPlaylistItems(int id) async => detail;
}

class _EditableFakeApiClient extends ApiClient {
  _EditableFakeApiClient(this._detail) : super(baseUrl: 'http://example.test');

  PlaylistDetailData _detail;
  final List<String> createdGroupTitles = [];
  final List<_UpdatedItemCall> updatedItemRequests = [];
  final List<List<PlaylistGroupReorderInput>> reorderRequests = [];
  final List<List<int>> removedTrackIds = [];
  final List<({int playlistId, int groupId, String title})> renamedGroups = [];
  final List<({int playlistId, int groupId})> deletedGroups = [];

  @override
  Future<PlaylistDetailData> getPlaylistItems(int id) async => _detail;

  @override
  Future<void> reorderPlaylistItems(
    int id,
    List<PlaylistGroupReorderInput> groups,
  ) async {
    reorderRequests.add(groups);

    final itemsById = <int, PlaylistItem>{
      for (final group in _detail.groups)
        for (final item in group.items) item.id: item,
    };

    _detail = PlaylistDetailData(
      playlist: _detail.playlist,
      groups: [
        for (var groupIndex = 0; groupIndex < groups.length; groupIndex++)
          PlaylistGroup(
            id: groups[groupIndex].id,
            playlistId: _detail.groups
                .firstWhere((group) => group.id == groups[groupIndex].id)
                .playlistId,
            title: _detail.groups
                .firstWhere((group) => group.id == groups[groupIndex].id)
                .title,
            position: groupIndex,
            isSystem: _detail.groups
                .firstWhere((group) => group.id == groups[groupIndex].id)
                .isSystem,
            createdAt: _detail.groups
                .firstWhere((group) => group.id == groups[groupIndex].id)
                .createdAt,
            updatedAt: _detail.groups
                .firstWhere((group) => group.id == groups[groupIndex].id)
                .updatedAt,
            items: [
              for (var itemIndex = 0;
                  itemIndex < groups[groupIndex].itemIds.length;
                  itemIndex++)
                PlaylistItem(
                  id: itemsById[groups[groupIndex].itemIds[itemIndex]]!.id,
                  playlistId: itemsById[groups[groupIndex].itemIds[itemIndex]]!
                      .playlistId,
                  trackId:
                      itemsById[groups[groupIndex].itemIds[itemIndex]]!.trackId,
                  groupId: groups[groupIndex].id,
                  position: itemIndex,
                  note: itemsById[groups[groupIndex].itemIds[itemIndex]]!.note,
                  coverMode: itemsById[groups[groupIndex].itemIds[itemIndex]]!
                      .coverMode,
                  libraryCoverId:
                      itemsById[groups[groupIndex].itemIds[itemIndex]]!
                          .libraryCoverId,
                  cachedCoverUrl:
                      itemsById[groups[groupIndex].itemIds[itemIndex]]!
                          .cachedCoverUrl,
                  customCoverPath:
                      itemsById[groups[groupIndex].itemIds[itemIndex]]!
                          .customCoverPath,
                  createdAt: itemsById[groups[groupIndex].itemIds[itemIndex]]!
                      .createdAt,
                  updatedAt: itemsById[groups[groupIndex].itemIds[itemIndex]]!
                      .updatedAt,
                  track:
                      itemsById[groups[groupIndex].itemIds[itemIndex]]!.track,
                ),
            ],
          ),
      ],
    );
  }

  @override
  Future<PlaylistGroup> createPlaylistGroup(int id, String title) async {
    createdGroupTitles.add(title);
    final group = PlaylistGroup(
      id: 2,
      playlistId: id,
      title: title,
      position: _detail.groups.length,
      items: const [],
    );
    _detail = PlaylistDetailData(
      playlist: _detail.playlist,
      groups: [..._detail.groups, group],
    );
    return group;
  }

  @override
  Future<void> renamePlaylistGroup(
      int playlistId, int groupId, String title) async {
    renamedGroups.add((playlistId: playlistId, groupId: groupId, title: title));
    _detail = PlaylistDetailData(
      playlist: _detail.playlist,
      groups: [
        for (final group in _detail.groups)
          if (group.id == groupId)
            PlaylistGroup(
              id: group.id,
              playlistId: group.playlistId,
              title: title,
              position: group.position,
              isSystem: group.isSystem,
              createdAt: group.createdAt,
              updatedAt: group.updatedAt,
              items: group.items,
            )
          else
            group,
      ],
    );
  }

  @override
  Future<void> deletePlaylistGroup(int playlistId, int groupId) async {
    deletedGroups.add((playlistId: playlistId, groupId: groupId));

    final targetGroup =
        _detail.groups.firstWhere((group) => group.id == groupId);
    final ungrouped = _detail.groups.firstWhere((group) => group.isSystem);

    _detail = PlaylistDetailData(
      playlist: _detail.playlist,
      groups: [
        for (final group in _detail.groups)
          if (group.id == ungrouped.id)
            PlaylistGroup(
              id: group.id,
              playlistId: group.playlistId,
              title: group.title,
              position: 0,
              isSystem: group.isSystem,
              createdAt: group.createdAt,
              updatedAt: group.updatedAt,
              items: [
                ...group.items,
                for (final item in targetGroup.items)
                  PlaylistItem(
                    id: item.id,
                    playlistId: item.playlistId,
                    trackId: item.trackId,
                    groupId: group.id,
                    position: group.items.length,
                    note: item.note,
                    coverMode: item.coverMode,
                    libraryCoverId: item.libraryCoverId,
                    cachedCoverUrl: item.cachedCoverUrl,
                    customCoverPath: item.customCoverPath,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt,
                    track: item.track,
                  ),
              ],
            )
          else if (group.id != groupId)
            PlaylistGroup(
              id: group.id,
              playlistId: group.playlistId,
              title: group.title,
              position: group.position > targetGroup.position
                  ? group.position - 1
                  : group.position,
              isSystem: group.isSystem,
              createdAt: group.createdAt,
              updatedAt: group.updatedAt,
              items: group.items,
            ),
      ],
    );
  }

  @override
  Future<void> removeTracksFromPlaylist(int id, List<int> trackIds) async {
    removedTrackIds.add(trackIds);
    _detail = PlaylistDetailData(
      playlist: _detail.playlist,
      groups: [
        for (final group in _detail.groups)
          PlaylistGroup(
            id: group.id,
            playlistId: group.playlistId,
            title: group.title,
            position: group.position,
            isSystem: group.isSystem,
            createdAt: group.createdAt,
            updatedAt: group.updatedAt,
            items: [
              for (final item in group.items)
                if (!trackIds.contains(item.trackId)) item,
            ],
          ),
      ],
    );
  }

  @override
  Future<void> updatePlaylistItem(
    int playlistId,
    int itemId,
    PlaylistItemUpdateRequest request,
  ) async {
    updatedItemRequests.add(_UpdatedItemCall(itemId: itemId, request: request));

    final updatedGroups = <PlaylistGroup>[];
    PlaylistItem? movingItem;
    for (final group in _detail.groups) {
      final items = <PlaylistItem>[];
      for (final item in group.items) {
        if (item.id == itemId) {
          movingItem = PlaylistItem(
            id: item.id,
            playlistId: item.playlistId,
            trackId: item.trackId,
            groupId: request.groupId ?? item.groupId,
            position: item.position,
            note: request.note ?? item.note,
            coverMode: request.coverMode ?? item.coverMode,
            libraryCoverId: request.libraryCoverId ?? item.libraryCoverId,
            cachedCoverUrl: request.cachedCoverUrl ?? item.cachedCoverUrl,
            customCoverPath: request.customCoverPath ?? item.customCoverPath,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
            track: item.track,
          );
          continue;
        }
        items.add(item);
      }
      updatedGroups.add(
        PlaylistGroup(
          id: group.id,
          playlistId: group.playlistId,
          title: group.title,
          position: group.position,
          isSystem: group.isSystem,
          createdAt: group.createdAt,
          updatedAt: group.updatedAt,
          items: items,
        ),
      );
    }

    final targetGroupId = request.groupId ?? movingItem!.groupId;
    _detail = PlaylistDetailData(
      playlist: _detail.playlist,
      groups: [
        for (final group in updatedGroups)
          if (group.id == targetGroupId)
            PlaylistGroup(
              id: group.id,
              playlistId: group.playlistId,
              title: group.title,
              position: group.position,
              isSystem: group.isSystem,
              createdAt: group.createdAt,
              updatedAt: group.updatedAt,
              items: [...group.items, movingItem!],
            )
          else
            group,
      ],
    );
  }
}

class _ThrowingApiClient extends ApiClient {
  _ThrowingApiClient() : super(baseUrl: 'http://example.test');

  @override
  Future<PlaylistDetailData> getPlaylistItems(int id) async {
    throw Exception('Failed to load grouped items');
  }
}

class _FlakyApiClient extends ApiClient {
  _FlakyApiClient(this.detail) : super(baseUrl: 'http://example.test');

  final PlaylistDetailData detail;
  int _calls = 0;

  @override
  Future<PlaylistDetailData> getPlaylistItems(int id) async {
    _calls += 1;
    if (_calls == 1) {
      throw Exception('Failed to load grouped items');
    }
    return detail;
  }
}

FilledButton _playButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'PLAY'));

void _noop() {}

PlaylistDetailData _buildEditableDetail() {
  return const PlaylistDetailData(
    playlist: Playlist(
      id: 7,
      name: 'Edit Mix',
      trackCount: 1,
    ),
    groups: [
      PlaylistGroup(
        id: 1,
        playlistId: 7,
        title: 'Ungrouped',
        position: 0,
        isSystem: true,
        items: [
          PlaylistItem(
            id: 101,
            playlistId: 7,
            trackId: 11,
            groupId: 1,
            position: 0,
            note: 'intro note',
            coverMode: 'default',
            track: Track(
              id: 11,
              title: 'Track A',
              audioPath: '/music/a.flac',
              videoPath: '',
            ),
          ),
        ],
      ),
    ],
  );
}

PlaylistDetailData _buildDesktopTitleWidthDetail({
  required String shortTitle,
  required String longTitle,
}) {
  return PlaylistDetailData(
    playlist: const Playlist(
      id: 7,
      name: 'Desktop Width Mix',
      trackCount: 2,
    ),
    groups: [
      PlaylistGroup(
        id: 1,
        playlistId: 7,
        title: 'Ungrouped',
        position: 0,
        isSystem: true,
        items: [
          PlaylistItem(
            id: 101,
            playlistId: 7,
            trackId: 11,
            groupId: 1,
            position: 0,
            note: 'note a',
            coverMode: 'default',
            track: Track(
              id: 11,
              title: shortTitle,
              audioPath: '/music/a.flac',
              videoPath: '',
            ),
          ),
          PlaylistItem(
            id: 102,
            playlistId: 7,
            trackId: 12,
            groupId: 1,
            position: 1,
            note: 'note b',
            coverMode: 'default',
            track: Track(
              id: 12,
              title: longTitle,
              audioPath: '/music/b.flac',
              videoPath: '',
            ),
          ),
        ],
      ),
    ],
  );
}

PlaylistDetailData _buildReorderableDetail() {
  return const PlaylistDetailData(
    playlist: Playlist(
      id: 7,
      name: 'Edit Mix',
      trackCount: 3,
    ),
    groups: [
      PlaylistGroup(
        id: 1,
        playlistId: 7,
        title: 'Ungrouped',
        position: 0,
        isSystem: true,
        items: [
          PlaylistItem(
            id: 101,
            playlistId: 7,
            trackId: 11,
            groupId: 1,
            position: 0,
            note: '',
            coverMode: 'default',
            track: Track(
              id: 11,
              title: 'Track A',
              audioPath: '/music/a.flac',
              videoPath: '',
            ),
          ),
          PlaylistItem(
            id: 102,
            playlistId: 7,
            trackId: 12,
            groupId: 1,
            position: 1,
            note: '',
            coverMode: 'default',
            track: Track(
              id: 12,
              title: 'Track B',
              audioPath: '/music/b.flac',
              videoPath: '',
            ),
          ),
        ],
      ),
      PlaylistGroup(
        id: 2,
        playlistId: 7,
        title: 'Act 2',
        position: 1,
        items: [
          PlaylistItem(
            id: 201,
            playlistId: 7,
            trackId: 21,
            groupId: 2,
            position: 0,
            note: '',
            coverMode: 'default',
            track: Track(
              id: 21,
              title: 'Track C',
              audioPath: '/music/c.flac',
              videoPath: '',
            ),
          ),
        ],
      ),
    ],
  );
}

PlaylistDetailData _buildThreeGroupDetail() {
  return const PlaylistDetailData(
    playlist: Playlist(
      id: 7,
      name: 'Group Edit Mix',
      trackCount: 4,
    ),
    groups: [
      PlaylistGroup(
        id: 1,
        playlistId: 7,
        title: 'Ungrouped',
        position: 0,
        isSystem: true,
        items: [
          PlaylistItem(
            id: 101,
            playlistId: 7,
            trackId: 11,
            groupId: 1,
            position: 0,
            note: '',
            coverMode: 'default',
            track: Track(
              id: 11,
              title: 'Track A',
              audioPath: '/music/a.flac',
              videoPath: '',
            ),
          ),
        ],
      ),
      PlaylistGroup(
        id: 2,
        playlistId: 7,
        title: 'Act 2',
        position: 1,
        items: [
          PlaylistItem(
            id: 201,
            playlistId: 7,
            trackId: 21,
            groupId: 2,
            position: 0,
            note: '',
            coverMode: 'default',
            track: Track(
              id: 21,
              title: 'Track C',
              audioPath: '/music/c.flac',
              videoPath: '',
            ),
          ),
        ],
      ),
      PlaylistGroup(
        id: 3,
        playlistId: 7,
        title: 'Finale',
        position: 2,
        items: [
          PlaylistItem(
            id: 301,
            playlistId: 7,
            trackId: 31,
            groupId: 3,
            position: 0,
            note: '',
            coverMode: 'default',
            track: Track(
              id: 31,
              title: 'Track D',
              audioPath: '/music/d.flac',
              videoPath: '',
            ),
          ),
        ],
      ),
    ],
  );
}

class _UpdatedItemCall {
  const _UpdatedItemCall({
    required this.itemId,
    required this.request,
  });

  final int itemId;
  final PlaylistItemUpdateRequest request;
}
