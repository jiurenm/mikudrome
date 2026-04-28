import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/screens/library_home_screen.dart';

void main() {
  testWidgets('system back returns to the previous mobile tab', (tester) async {
    await _pumpMobileLibrary(tester);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('服务器'), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.text('专辑'), findsWidgets);
    expect(find.text('服务器'), findsNothing);
  });

  testWidgets('system back returns from a mobile destination to My Music', (
    tester,
  ) async {
    await _pumpMobileLibrary(tester);

    await tester.tap(find.text('我的音乐'));
    await tester.pumpAndSettle();
    expect(find.text('收藏'), findsOneWidget);

    await tester.tap(find.text('歌单'));
    await tester.pumpAndSettle();
    expect(find.text('收藏'), findsNothing);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('歌单'), findsOneWidget);
  });
}

Future<void> _pumpMobileLibrary(WidgetTester tester) {
  return tester.pumpWidget(
    const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(390, 844)),
        child: LibraryHomeScreen(),
      ),
    ),
  );
}
