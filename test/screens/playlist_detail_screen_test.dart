import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/api/api_client.dart';
import 'package:mikudrome/models/playlist.dart';
import 'package:mikudrome/models/playlist_detail_data.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/screens/playlist_detail_screen.dart';
import 'package:mikudrome/services/playlist_repository.dart';
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

  testWidgets('PlaylistTrackRow.track keeps legacy track callers working', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaylistTrackRow.track(
            track: const Track(
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
