import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/widgets/settings_screen.dart';

void main() {
  testWidgets('shows configured server url and edit callback', (tester) async {
    var edited = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsScreen(
            serverUrl: 'http://192.168.1.10:8080',
            onEditServer: () => edited = true,
          ),
        ),
      ),
    );

    expect(find.text('http://192.168.1.10:8080'), findsOneWidget);

    await tester.tap(find.text('服务器'));
    expect(edited, isTrue);
  });

  testWidgets('starts rescan through callback', (tester) async {
    var rescanned = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsScreen(onRescan: () => rescanned = true)),
      ),
    );

    await tester.tap(find.text('媒体库重扫'));

    expect(rescanned, isTrue);
  });
}
