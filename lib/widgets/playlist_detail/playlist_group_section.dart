import 'package:flutter/material.dart';

class PlaylistGroupSection extends StatelessWidget {
  const PlaylistGroupSection({
    super.key,
    this.title,
    this.header,
    required this.children,
    this.spacing = 8,
  });

  final String? title;
  final Widget? header;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final resolvedHeader = header ??
        Text(
          title ?? '',
          style: Theme.of(context).textTheme.titleMedium,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        resolvedHeader,
        SizedBox(height: spacing),
        ...children,
      ],
    );
  }
}
