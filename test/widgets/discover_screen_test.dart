import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/widgets/discover_screen.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844)),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('DiscoverScreen shows section tabs by default', (tester) async {
    await tester.pumpWidget(_harness(const DiscoverScreen(child: Text('内容'))));

    expect(find.text('专辑'), findsOneWidget);
    expect(find.text('P主'), findsOneWidget);
    expect(find.text('歌手'), findsOneWidget);
    expect(find.text('内容'), findsOneWidget);
  });

  testWidgets('DiscoverScreen can hide section tabs for detail pages', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        const DiscoverScreen(showSectionTabs: false, child: Text('详情内容')),
      ),
    );

    expect(find.text('专辑'), findsNothing);
    expect(find.text('P主'), findsNothing);
    expect(find.text('歌手'), findsNothing);
    expect(find.text('详情内容'), findsOneWidget);
  });
}
