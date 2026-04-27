import 'package:flutter/material.dart';

import '../screens/albums_screen.dart';
import '../screens/mv_gallery_screen.dart';
import '../screens/producers_screen.dart';
import '../screens/vocalists_screen.dart';
import '../theme/app_theme.dart';

enum DiscoverSection { albums, producers, vocalists, mv }

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    this.currentSection,
    this.onSectionChanged,
    this.child,
  });

  final DiscoverSection? currentSection;
  final ValueChanged<DiscoverSection>? onSectionChanged;
  final Widget? child;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  DiscoverSection _section = DiscoverSection.albums;

  DiscoverSection get _currentSection => widget.currentSection ?? _section;

  void _selectSection(Set<DiscoverSection> selection) {
    final section = selection.first;
    widget.onSectionChanged?.call(section);
    if (widget.currentSection == null) {
      setState(() {
        _section = section;
      });
    }
  }

  Widget _defaultContent() {
    return switch (_currentSection) {
      DiscoverSection.albums => AlbumsScreen(),
      DiscoverSection.producers => ProducersScreen(),
      DiscoverSection.vocalists => const VocalistsScreen(),
      DiscoverSection.mv => const MvGalleryScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: SegmentedButton<DiscoverSection>(
            segments: const [
              ButtonSegment<DiscoverSection>(
                value: DiscoverSection.albums,
                icon: Icon(Icons.album_outlined),
                label: Text('专辑'),
              ),
              ButtonSegment<DiscoverSection>(
                value: DiscoverSection.producers,
                icon: Icon(Icons.person_search_outlined),
                label: Text('P主'),
              ),
              ButtonSegment<DiscoverSection>(
                value: DiscoverSection.vocalists,
                icon: Icon(Icons.record_voice_over_outlined),
                label: Text('歌手'),
              ),
              ButtonSegment<DiscoverSection>(
                value: DiscoverSection.mv,
                icon: Icon(Icons.movie_outlined),
                label: Text('MV'),
              ),
            ],
            selected: {_currentSection},
            showSelectedIcon: false,
            onSelectionChanged: _selectSection,
            style: _segmentStyle(),
          ),
        ),
        Expanded(child: widget.child ?? _defaultContent()),
      ],
    );
  }
}

ButtonStyle _segmentStyle() {
  return ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppTheme.mikuGreen.withValues(alpha: 0.16);
      }
      return AppTheme.cardBg;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppTheme.textPrimary;
      }
      return AppTheme.textMuted;
    }),
    side: WidgetStateProperty.resolveWith((states) {
      final color = states.contains(WidgetState.selected)
          ? AppTheme.mikuGreen.withValues(alpha: 0.42)
          : Colors.white.withValues(alpha: 0.08);
      return BorderSide(color: color);
    }),
  );
}
