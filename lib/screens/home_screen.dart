import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/track.dart';
import 'library_home_screen.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiClient _api = ApiClient();
  List<Track> _tracks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getTracks();
      setState(() {
        _tracks = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openPlayer(Track track) {
    final queue = List<Track>.from(_tracks);
    final index = queue.indexWhere((item) => item.id == track.id);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PlayerScreen(
          track: track,
          queue: queue,
          currentIndex: index < 0 ? 0 : index,
          contextLabel: 'Home / All Tracks',
          playbackMode:
              track.hasVideo ? PlaybackMode.video : PlaybackMode.audio,
          onSelectTrack: (_) {},
          onPrevious: () {},
          onNext: () {},
          onClose: () => Navigator.of(context).maybePop(),
          onSwitchPlaybackMode: (_) {},
          playbackOrderMode: PlaybackOrderMode.sequential,
          onCyclePlaybackOrderMode: () {},
          onPlaybackStateChanged: ({
            required bool isPlaying,
            required double progress,
            required String elapsedLabel,
            required String durationLabel,
          }) {},
          baseUrl: _api.baseUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mikudrome'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadTracks,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadTracks,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_tracks.isEmpty) {
      return const Center(
        child: Text('No tracks. Add media and run the server.'),
      );
    }
    return ListView.builder(
      itemCount: _tracks.length,
      itemBuilder: (context, index) {
        final track = _tracks[index];
        return ListTile(
          leading: Icon(
            track.hasVideo ? Icons.video_library : Icons.music_note,
            color: track.hasVideo ? Theme.of(context).colorScheme.primary : null,
          ),
          title: Text(track.title),
          subtitle: track.hasVideo ? const Text('Tap to play MV') : null,
          onTap: () => _openPlayer(track),
        );
      },
    );
  }
}
