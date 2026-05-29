import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/models/track.dart';
import 'package:mikudrome/screens/library_home_screen.dart';
import 'package:mikudrome/services/playback_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await PlaybackStorage.ensureInitialized();
  });

  test('saves and loads playback state on non-web platforms', () {
    const queue = <Track>[
      Track(id: 1, title: 'One', audioPath: '/one.flac', videoPath: ''),
      Track(id: 2, title: 'Two', audioPath: '/two.flac', videoPath: ''),
    ];

    PlaybackStorage.save(
      queue: queue,
      index: 1,
      progress: 0.42,
      mode: PlaybackMode.audio,
      orderMode: PlaybackOrderMode.listLoop,
      contextLabel: 'Album / Test',
    );

    final saved = PlaybackStorage.load();
    expect(saved, isNotNull);
    expect(saved!.queue.map((track) => track.id), [1, 2]);
    expect(saved.index, 1);
    expect(saved.progress, 0.42);
    expect(saved.mode, PlaybackMode.audio);
    expect(saved.orderMode, PlaybackOrderMode.listLoop);
    expect(saved.contextLabel, 'Album / Test');
  });

  test('preserves standalone MV stream override urls', () {
    const queue = <Track>[
      Track(
        id: -9,
        title: 'Standalone MV',
        audioPath: '',
        videoPath: 'standalone',
        videoStreamOverrideUrl: 'http://example.test/api/videos/9/stream',
        coverOverrideUrl: 'http://example.test/api/videos/9/thumb',
      ),
    ];

    PlaybackStorage.save(
      queue: queue,
      index: 0,
      progress: 0.25,
      mode: PlaybackMode.video,
      orderMode: PlaybackOrderMode.sequential,
      contextLabel: 'MV Gallery / Standalone MV',
    );

    final saved = PlaybackStorage.load();
    expect(saved, isNotNull);
    expect(
      saved!.queue.single.videoStreamOverrideUrl,
      queue.single.videoStreamOverrideUrl,
    );
    expect(saved.queue.single.coverOverrideUrl, queue.single.coverOverrideUrl);
    expect(saved.mode, PlaybackMode.video);
  });

  test('clamps invalid saved index and progress', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mikudrome_queue':
          '[{"id":3,"title":"Three","audio_path":"/three.flac"}]',
      'mikudrome_index': '99',
      'mikudrome_progress': '2',
      'mikudrome_mode': 'video',
      'mikudrome_order_mode': 'singleLoop',
      'mikudrome_context': 'Queue',
    });
    await PlaybackStorage.ensureInitialized();

    final saved = PlaybackStorage.load();

    expect(saved, isNotNull);
    expect(saved!.index, 0);
    expect(saved.progress, 1.0);
    expect(saved.mode, PlaybackMode.video);
    expect(saved.orderMode, PlaybackOrderMode.singleLoop);
  });

  test('clears playback state', () {
    PlaybackStorage.save(
      queue: const [
        Track(id: 1, title: 'One', audioPath: '/one.flac', videoPath: ''),
      ],
      index: 0,
      progress: 0.5,
      mode: PlaybackMode.audio,
      orderMode: PlaybackOrderMode.sequential,
      contextLabel: 'Queue',
    );

    PlaybackStorage.clear();

    expect(PlaybackStorage.load(), isNull);
  });
}
