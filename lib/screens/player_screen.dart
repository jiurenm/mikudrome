import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';

/// Full MV player layout matching miku_player.html: header, track list sidebar, 16:9 video, controls, footer.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.title,
    required this.videoUrl,
    this.producerName = 'ピノキオピー',
    this.vocalists = '初音ミク',
  });

  final String title;
  final String videoUrl;
  final String producerName;
  final String vocalists;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSidebar(context),
                Expanded(
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Center(
                            child: _controller.value.isInitialized
                                ? _buildVideoArea()
                                : const Center(child: CircularProgressIndicator(color: AppTheme.mikuGreen)),
                          ),
                        ),
                        _buildTrackInfo(context),
                        _buildControls(context),
                      ],
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.mikuGreen,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.album, color: Colors.black, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'MIKUDROME',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: AppTheme.mikuGreen,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text('NAS: Online', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
              const SizedBox(width: 24),
              Text('Storage: 2.4TB / 8TB', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: MediaQuery.sizeOf(context).width * 0.28,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade800)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Library / Albums',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              const Icon(Icons.search, color: AppTheme.textMuted, size: 18),
            ],
          ),
          const SizedBox(height: 16),
          _TrackListItem(
            title: widget.title,
            subtitle: '${widget.producerName} • ${widget.vocalists}',
            isActive: true,
            hasMv: true,
          ),
          _TrackListItem(
            title: '偶像宣言',
            subtitle: 'Mitchie M • 初音ミク',
            isActive: false,
            hasMv: false,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoArea() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.mikuGreen.withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoPlayer(_controller),
                Center(
                  child: Material(
                    color: AppTheme.mikuGreen.withValues(alpha: 0.2),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _controller.value.isPlaying
                              ? _controller.pause()
                              : _controller.play();
                        });
                      },
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.mikuGreen.withValues(alpha: 0.5)),
                        ),
                        child: Icon(
                          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: AppTheme.mikuGreen,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            widget.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(
                    'Producer',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.producerName,
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppTheme.mikuGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(width: 1, height: 32, color: AppTheme.textMuted),
              const SizedBox(width: 24),
              Column(
                children: [
                  Text(
                    'Vocalists',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.mikuGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.mikuGreen),
                    ),
                    child: Text(
                      widget.vocalists,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.mikuGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 0, 48, 32),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.33,
              backgroundColor: Colors.grey.shade800,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.mikuGreen),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shuffle, color: AppTheme.textMuted),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(
                      _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 32,
                      color: AppTheme.mikuGreen,
                    ),
                    onPressed: () {
                      setState(() {
                        _controller.value.isPlaying
                            ? _controller.pause()
                            : _controller.play();
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.repeat, color: AppTheme.textMuted),
                    onPressed: () {},
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.closed_caption, color: AppTheme.mikuGreen),
                  const SizedBox(width: 16),
                  const Icon(Icons.download, color: AppTheme.textMuted),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      height: 24,
      color: AppTheme.mikuGreen,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Text(
        'Now Streaming: ${widget.title} // ${widget.producerName} feat. ${widget.vocalists} // Local MV Link Active',
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

class _TrackListItem extends StatelessWidget {
  const _TrackListItem({
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.hasMv,
  });

  final String title;
  final String subtitle;
  final bool isActive;
  final bool hasMv;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white.withValues(alpha: 0.03)
            : null,
        borderRadius: BorderRadius.circular(8),
        border: isActive
            ? Border(left: BorderSide(color: AppTheme.mikuGreen, width: 4))
            : null,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              'https://api.dicebear.com/7.x/identicon/svg?seed=${title.hashCode}',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 48,
                height: 48,
                color: AppTheme.cardBg,
                child: const Icon(Icons.music_note),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isActive ? AppTheme.mikuGreen : AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (hasMv)
            const Icon(Icons.movie, size: 14, color: AppTheme.mikuGreen),
        ],
      ),
    );
  }
}
