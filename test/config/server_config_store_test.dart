import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/config/server_config_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('starts empty when no server url is saved', () async {
    final store = ServerConfigStore();

    expect(await store.loadServerUrl(), isNull);
    expect(await store.loadServerCookie(), isNull);
  });

  test('normalizes stored server url on load', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mikudrome_server_url': ' http://192.168.1.10:8080/ ',
    });
    final store = ServerConfigStore();

    expect(await store.loadServerUrl(), 'http://192.168.1.10:8080');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mikudrome_server_url'), 'http://192.168.1.10:8080');
  });

  test('clears invalid stored server url on load', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mikudrome_server_url': 'ftp://example.test',
    });
    final store = ServerConfigStore();

    expect(await store.loadServerUrl(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mikudrome_server_url'), isNull);
  });

  test('saves normalized server url', () async {
    final store = ServerConfigStore();

    await store.saveServerUrl(' http://192.168.1.10:8080/ ');

    expect(await store.loadServerUrl(), 'http://192.168.1.10:8080');
  });

  test('saves trimmed server cookie', () async {
    final store = ServerConfigStore();

    await store.saveServerCookie(' session=abc; token=xyz ');

    expect(await store.loadServerCookie(), 'session=abc; token=xyz');
  });

  test('clears blank server cookie', () async {
    final store = ServerConfigStore();
    await store.saveServerCookie('session=abc');

    await store.saveServerCookie('   ');

    expect(await store.loadServerCookie(), isNull);
  });

  test('clears server url', () async {
    final store = ServerConfigStore();
    await store.saveServerUrl('http://192.168.1.10:8080');

    await store.clearServerUrl();

    expect(await store.loadServerUrl(), isNull);
  });

  test('clears server cookie', () async {
    final store = ServerConfigStore();
    await store.saveServerCookie('session=abc');

    await store.clearServerCookie();

    expect(await store.loadServerCookie(), isNull);
  });
}
