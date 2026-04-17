import 'package:flutter/material.dart';

class PlaylistGroupSection extends StatelessWidget {
  const PlaylistGroupSection({
    super.key,
    required this.title,
    required this.children,
    this.spacing = 8,
  });

  final String title;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: spacing),
        ...children,
      ],
    );
  }
}
