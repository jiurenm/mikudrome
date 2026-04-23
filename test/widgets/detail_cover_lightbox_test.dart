import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/widgets/detail_cover_lightbox.dart';

Widget _buildHarness() {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: DetailCoverLightboxTrigger(
          key: const ValueKey('detail-cover-trigger'),
          semanticLabel: 'Open cover preview',
          lightboxBuilder: (_) => Container(
            key: const ValueKey('detail-cover-preview-child'),
            width: 320,
            height: 320,
            color: Colors.teal,
          ),
          child: Container(
            width: 96,
            height: 96,
            color: Colors.teal,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('DetailCoverLightboxTrigger opens and closes the lightbox',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(_buildHarness());

    expect(find.bySemanticsLabel('Open cover preview'), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-cover-lightbox')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('detail-cover-trigger')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('detail-cover-lightbox')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('detail-cover-lightbox-close-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('detail-cover-preview-child')),
        findsOneWidget);
    expect(
      tester.getRect(find.byKey(const ValueKey('detail-cover-lightbox-backdrop'))),
      tester.getRect(find.byKey(const ValueKey('detail-cover-lightbox'))),
    );

    await tester.tap(
      find.byKey(const ValueKey('detail-cover-lightbox-close-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('detail-cover-lightbox')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('detail-cover-trigger')));
    await tester.pumpAndSettle();

    final backdropRect = tester.getRect(
      find.byKey(const ValueKey('detail-cover-lightbox-backdrop')),
    );
    await tester.tapAt(backdropRect.bottomLeft - const Offset(-16, 16));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('detail-cover-lightbox')), findsNothing);
    semantics.dispose();
  });

  testWidgets('DetailCoverLightbox supports desktop wheel zoom',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildHarness());
    await tester.tap(find.byKey(const ValueKey('detail-cover-trigger')));
    await tester.pumpAndSettle();

    final interactiveViewer = find.byKey(
      const ValueKey('detail-cover-lightbox-viewer'),
    );
    final renderBox = tester.renderObject<RenderBox>(interactiveViewer);
    final pointerPosition = tester.getTopLeft(interactiveViewer) +
        const Offset(240, 180);
    final localPointerPosition = renderBox.globalToLocal(pointerPosition);

    final before = tester.widget<InteractiveViewer>(interactiveViewer);
    final beforeScenePoint =
        before.transformationController!.toScene(localPointerPosition);
    expect(
      before.transformationController!.value.getMaxScaleOnAxis(),
      1.0,
    );

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: pointerPosition,
        scrollDelta: const Offset(0, -40),
      ),
    );
    await tester.pump();

    final after = tester.widget<InteractiveViewer>(interactiveViewer);
    final afterScenePoint =
        after.transformationController!.toScene(localPointerPosition);
    expect(
      after.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1.0),
    );
    expect((afterScenePoint - beforeScenePoint).distance, lessThan(0.1));

    await tester.tap(
      find.byKey(const ValueKey('detail-cover-lightbox-close-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('detail-cover-lightbox')), findsNothing);
  });

  testWidgets(
    'DetailCoverLightboxTrigger supports keyboard activation with Enter and Space',
    (tester) async {
      await tester.pumpWidget(_buildHarness());

      expect(find.byKey(const ValueKey('detail-cover-lightbox')), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('detail-cover-lightbox')), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('detail-cover-lightbox-close-button')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('detail-cover-lightbox')), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('detail-cover-lightbox')), findsOneWidget);
    },
  );

  testWidgets('DetailCoverLightbox closes on Escape', (tester) async {
    await tester.pumpWidget(_buildHarness());
    await tester.tap(find.byKey(const ValueKey('detail-cover-trigger')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('detail-cover-lightbox')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('detail-cover-lightbox')), findsNothing);
  });
}
