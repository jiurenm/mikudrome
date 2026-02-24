import 'package:flutter/material.dart';

import '../models/track.dart';
import '../services/api_client.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _defaultBaseUrl = 'http://127.0.0.1:8081';

  final ApiClient _api = ApiClient(baseUrl: _defaultBaseUrl);
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
    if (!track.hasVideo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No MV for "${track.title}"')),
      );
      return;
    }
    final videoUrl = _api.streamVideoUrl(track.id);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PlayerScreen(
          title: track.title,
          videoUrl: videoUrl,
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
