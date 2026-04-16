import 'package:mikudrome/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/playlist_detail_data.dart';

void main() {
  group('PlaylistDetailData.fromJson', () {
    test('parses grouped playlist response with nested track data', () {
      final detail = PlaylistDetailData.fromJson({
        'playlist': {
          'id': 7,
          'name': 'Focus Mix',
          'cover_path': '/api/playlists/7/cover',
          'track_count': 2,
          'cover_track_ids': [11, 12],
          'cover_album_ids': [21],
          'created_at': 100,
          'updated_at': 200,
        },
        'groups': [
          {
            'id': 1,
            'playlist_id': 7,
            'title': 'Ungrouped',
            'position': 0,
            'is_system': true,
            'created_at': 100,
            'updated_at': 200,
            'items': [
              {
                'id': 101,
                'playlist_id': 7,
                'track_id': 11,
                'group_id': 1,
                'position': 0,
                'note': 'Start here',
                'cover_mode': 'library',
                'library_cover_id': 'album-21',
                'cached_cover_url': 'https://example.test/cover.jpg',
                'custom_cover_path': '/tmp/custom.jpg',
                'created_at': 110,
                'updated_at': 210,
                'track': {
                  'id': 11,
                  'title': 'Song A',
                  'audio_path': '/music/a.flac',
                  'video_path': '',
                  'album_id': 21,
                  'disc_number': 1,
                  'track_number': 1,
                  'artists': 'Miku',
                  'year': 2024,
                  'duration_seconds': 180,
                  'format': 'FLAC',
                  'is_favorite': true,
                },
              },
            ],
          },
          {
            'id': 2,
            'playlist_id': 7,
            'title': 'Highlights',
            'position': 1,
            'is_system': false,
            'created_at': 120,
            'updated_at': 220,
            'items': [],
          },
        ],
      });

      expect(detail.playlist.id, 7);
      expect(detail.playlist.name, 'Focus Mix');
      expect(detail.playlist.coverTrackIds, [11, 12]);
      expect(detail.playlist.coverAlbumIds, [21]);

      expect(detail.groups, hasLength(2));
      expect(detail.groups.first.id, 1);
      expect(detail.groups.first.isSystem, isTrue);
      expect(detail.groups.first.items, hasLength(1));
      expect(detail.groups.first.items.first.id, 101);
      expect(detail.groups.first.items.first.note, 'Start here');
      expect(detail.groups.first.items.first.track.id, 11);
      expect(detail.groups.first.items.first.track.title, 'Song A');
      expect(detail.groups.first.items.first.track.isFavorite, isTrue);

      expect(detail.groups.last.id, 2);
      expect(detail.groups.last.isSystem, isFalse);
      expect(detail.groups.last.items, isEmpty);
    });

    test('defaults missing or null arrays to empty lists', () {
      final detail = PlaylistDetailData.fromJson({
        'playlist': {
          'id': 9,
          'name': 'Empty',
          'cover_track_ids': null,
          'cover_album_ids': null,
        },
        'groups': [
          {
            'id': 1,
            'playlist_id': 9,
            'title': 'Ungrouped',
            'position': 0,
            'is_system': true,
            'created_at': 0,
            'updated_at': 0,
            'items': null,
          },
        ],
      });

      expect(detail.playlist.coverTrackIds, isEmpty);
      expect(detail.playlist.coverAlbumIds, isEmpty);
      expect(detail.groups, hasLength(1));
      expect(detail.groups.first.items, isEmpty);
    });
  });

  group('grouped playlist request payloads', () {
    test('serializes grouped reorder payload with stable keys', () {
      const payload = PlaylistItemsOrderInput(
        groups: [
          PlaylistGroupReorderInput(id: 5, itemIds: [11, 12]),
        ],
      );

      expect(payload.toJson(), {
        'groups': [
          {
            'id': 5,
            'items': [11, 12]
          },
        ],
      });
    });

    test('serializes group title payload with stable keys', () {
      const payload = PlaylistGroupTitleInput(title: 'Highlights');

      expect(payload.toJson(), {
        'title': 'Highlights',
      });
    });
  });
}
