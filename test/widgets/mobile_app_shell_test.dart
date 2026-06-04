import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/widgets/mobile_app_shell.dart';

void main() {
  testWidgets('shows Discover, My Music, and Settings tabs', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MobileAppShell(
          discover: Text('discover body'),
          myMusic: Text('music body'),
          settings: Text('settings body'),
        ),
      ),
    );

    expect(find.text('发现'), findsOneWidget);
    expect(find.text('我的音乐'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('switches between top-level tabs', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MobileAppShell(
          discover: Text('专辑'),
          myMusic: Column(children: [Text('收藏'), Text('歌单')]),
          settings: Column(children: [Text('服务器'), Text('媒体库重扫')]),
        ),
      ),
    );

    expect(find.text('专辑'), findsWidgets);

    await tester.tap(find.text('我的音乐'));
    await tester.pumpAndSettle();
    expect(find.text('收藏'), findsWidgets);
    expect(find.text('歌单'), findsWidgets);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('服务器'), findsWidgets);
    expect(find.text('媒体库重扫'), findsWidgets);
  });

  testWidgets('preserves tab state when switching away and back', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MobileAppShell(
          discover: _CounterTab(),
          myMusic: Text('music body'),
          settings: Text('settings body'),
        ),
      ),
    );

    await tester.tap(find.text('increment'));
    await tester.pump();
    expect(find.text('count 1'), findsOneWidget);

    await tester.tap(find.text('我的音乐'));
    await tester.pumpAndSettle();
    expect(find.text('music body'), findsOneWidget);

    await tester.tap(find.text('发现'));
    await tester.pumpAndSettle();
    expect(find.text('count 1'), findsOneWidget);
  });

  testWidgets('uses a left rail on native phone landscape', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(844, 390)),
          child: MobileAppShell(
            discover: Text('discover body'),
            myMusic: Text('music body'),
            settings: Text('settings body'),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('mobile-landscape-shell')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mobile-landscape-rail')), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.text('discover body'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('landscape rail switches tabs', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(844, 390)),
          child: MobileAppShell(
            discover: Text('discover body'),
            myMusic: Text('music body'),
            settings: Text('settings body'),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('我的音乐'));
    await tester.pumpAndSettle();
    expect(find.text('music body'), findsOneWidget);

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('settings body'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}

class _CounterTab extends StatefulWidget {
  const _CounterTab();

  @override
  State<_CounterTab> createState() => _CounterTabState();
}

class _CounterTabState extends State<_CounterTab> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('count $_count'),
        TextButton(
          onPressed: () => setState(() {
            _count++;
          }),
          child: const Text('increment'),
        ),
      ],
    );
  }
}
