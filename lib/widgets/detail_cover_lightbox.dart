import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DetailCoverLightboxTrigger extends StatelessWidget {
  const DetailCoverLightboxTrigger({
    super.key,
    required this.child,
    required this.lightboxBuilder,
    required this.semanticLabel,
  });

  final Widget child;
  final WidgetBuilder lightboxBuilder;
  final String semanticLabel;

  void _openLightbox(BuildContext context) {
    showDetailCoverLightbox(
      context,
      child: lightboxBuilder(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _openLightbox(context);
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        label: semanticLabel,
        onTap: () => _openLightbox(context),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openLightbox(context),
          child: child,
        ),
      ),
    );
  }
}

Future<void> showDetailCoverLightbox(
  BuildContext context, {
  required Widget child,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierLabel: 'Close cover preview',
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    pageBuilder: (context, animation, secondaryAnimation) {
      return DetailCoverLightbox(child: child);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class DetailCoverLightbox extends StatefulWidget {
  const DetailCoverLightbox({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<DetailCoverLightbox> createState() => _DetailCoverLightboxState();
}

class _DetailCoverLightboxState extends State<DetailCoverLightbox> {
  static const double _minScale = 1.0;
  static const double _maxScale = 4.0;

  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }

    final focalPoint = event.localPosition;
    final currentScale =
        _transformationController.value.getMaxScaleOnAxis().clamp(
              _minScale,
              _maxScale,
            );
    final targetScale = (currentScale * (event.scrollDelta.dy < 0 ? 1.1 : 0.9))
        .clamp(_minScale, _maxScale);
    final scaleDelta = targetScale / currentScale;

    final nextTransform = Matrix4.identity()
      ..translateByDouble(focalPoint.dx, focalPoint.dy, 0, 1)
      ..scaleByDouble(scaleDelta, scaleDelta, 1, 1)
      ..translateByDouble(-focalPoint.dx, -focalPoint.dy, 0, 1)
      ..multiply(_transformationController.value);

    _transformationController.value = nextTransform;
  }

  void _dismissLightbox() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              _dismissLightbox();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Material(
            key: const ValueKey('detail-cover-lightbox'),
            color: Colors.black.withValues(alpha: 0.94),
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      key: const ValueKey('detail-cover-lightbox-backdrop'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _dismissLightbox,
                    ),
                  ),
                  Center(
                    child: Listener(
                      onPointerSignal: _handlePointerSignal,
                      child: InteractiveViewer(
                        key: const ValueKey('detail-cover-lightbox-viewer'),
                        transformationController: _transformationController,
                        minScale: _minScale,
                        maxScale: _maxScale,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: viewport.width - 32,
                            maxHeight: viewport.height - 32,
                          ),
                          child: widget.child,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      key: const ValueKey('detail-cover-lightbox-close-button'),
                      onPressed: _dismissLightbox,
                      icon: const Icon(Icons.close),
                      tooltip: 'Close cover preview',
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
