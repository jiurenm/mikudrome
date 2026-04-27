import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mikudrome/config/app_config_controller.dart';
import 'package:mikudrome/theme/app_theme.dart';
import 'package:mikudrome/widgets/app_root.dart';

const List<({String family, String assetPath})>
_bundledFonts = <({String family, String assetPath})>[
  (family: 'NotoSansJP', assetPath: 'lib/assets/fonts/NotoSansJP-Regular.ttf'),
  (family: 'NotoSansSC', assetPath: 'lib/assets/fonts/NotoSansSC-Regular.ttf'),
];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadBundledFonts();
  final appConfigController = AppConfigController();
  await appConfigController.load();

  runApp(MikudromeApp(appConfigController: appConfigController));
}

Future<void> loadBundledFonts({
  Future<void> Function(String family, String assetPath)? loadFont,
}) async {
  final effectiveLoader = loadFont ?? _loadBundledFont;
  for (final font in _bundledFonts) {
    await effectiveLoader(font.family, font.assetPath);
  }
}

Future<void> _loadBundledFont(String family, String assetPath) async {
  final fontLoader = FontLoader(family);
  fontLoader.addFont(rootBundle.load(assetPath));
  await fontLoader.load();
}

class MikudromeApp extends StatelessWidget {
  const MikudromeApp({super.key, required this.appConfigController});

  final AppConfigController appConfigController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mikudrome',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      home: AppRoot(controller: appConfigController),
    );
  }
}
