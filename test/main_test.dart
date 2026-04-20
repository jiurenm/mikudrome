import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/main.dart';

void main() {
  test('loadBundledFonts registers both bundled font families', () async {
    final calls = <String>[];

    Future<void> fakeLoader(String family, String assetPath) async {
      calls.add('$family:$assetPath');
    }

    await loadBundledFonts(loadFont: fakeLoader);

    expect(
      calls,
      <String>[
        'NotoSansJP:lib/assets/fonts/NotoSansJP-Regular.ttf',
        'NotoSansSC:lib/assets/fonts/NotoSansSC-Regular.ttf',
      ],
    );
  });
}
