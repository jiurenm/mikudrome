import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class AssetSliderThumbShape extends SliderComponentShape {
  const AssetSliderThumbShape({
    required this.image,
    required this.size,
  });

  final ImageProvider image;
  final double size;

  static final Map<ImageProvider, ui.Image> _imageCache =
      <ImageProvider, ui.Image>{};
  static final Set<ImageProvider> _pendingResolves = <ImageProvider>{};

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size.square(size);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final rect = Rect.fromCenter(center: center, width: size, height: size);
    final resolvedImage = _imageCache[image];

    if (resolvedImage != null) {
      paintImage(
        canvas: context.canvas,
        rect: rect,
        image: resolvedImage,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
      return;
    }

    _resolveImage(parentBox);

    final fallbackColor = sliderTheme.thumbColor ?? Colors.white;
    context.canvas.drawCircle(
      center,
      size / 2,
      Paint()
        ..color = fallbackColor
        ..isAntiAlias = true,
    );
  }

  void _resolveImage(RenderBox parentBox) {
    if (_pendingResolves.contains(image)) return;

    _pendingResolves.add(image);
    final imageStream = image.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        _imageCache[image] = info.image;
        _pendingResolves.remove(image);
        imageStream.removeListener(listener);
        parentBox.markNeedsPaint();
      },
      onError: (Object _, StackTrace? __) {
        _pendingResolves.remove(image);
        imageStream.removeListener(listener);
      },
    );
    imageStream.addListener(listener);
  }
}
