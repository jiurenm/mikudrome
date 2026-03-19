import 'package:flutter/material.dart';

import '../../models/track.dart';
import '../player_screen_parts.dart';

class TrackInfoSection extends StatelessWidget {
  const TrackInfoSection({
    super.key,
    required this.track,
  });

  final Track track;

  @override
  Widget build(BuildContext context) {
    final vocalists = track.vocalists;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 10,
            children: [
              CreditColumn(
                label: 'Composer',
                value: track.composerDisplay,
              ),
              Container(
                width: 1,
                height: 28,
                color: Colors.grey.shade700,
              ),
              CreditColumn(
                label: 'Lyricist',
                value: track.lyricistDisplay,
              ),
              Container(
                width: 1,
                height: 28,
                color: Colors.grey.shade700,
              ),
              VocalBadgeColumn(vocalists: vocalists),
            ],
          ),
        ],
      ),
    );
  }
}
