import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/api/api_client.dart';
import 'package:mikudrome/api/config.dart';

void main() {
  tearDown(ApiConfig.resetRuntimeConfigForTests);

  test('ApiClient uses dart define default when no runtime url is set', () {
    ApiConfig.resetRuntimeConfigForTests();

    expect(ApiClient().baseUrl, ApiConfig.dartDefineBaseUrl);
  });

  test('ApiClient uses normalized runtime url when set', () {
    ApiConfig.setRuntimeBaseUrl(' http://192.168.1.10:8080/ ');

    expect(ApiClient().baseUrl, 'http://192.168.1.10:8080');
  });

  test('default ApiClient follows runtime url changes', () {
    final client = ApiClient();
    ApiConfig.setRuntimeBaseUrl('http://192.168.1.10:8080');
    expect(client.baseUrl, 'http://192.168.1.10:8080');
    ApiConfig.setRuntimeBaseUrl('http://192.168.1.11:8080');
    expect(client.baseUrl, 'http://192.168.1.11:8080');
  });

  test('ApiClient can still receive explicit base url', () {
    ApiConfig.setRuntimeBaseUrl('http://192.168.1.10:8080');

    expect(
      ApiClient(baseUrl: 'http://example.test').baseUrl,
      'http://example.test',
    );
  });

  test('default headers include trimmed runtime cookie when configured', () {
    ApiConfig.setRuntimeCookie(' session=abc; token=xyz ');

    expect(ApiConfig.defaultHeaders, {'Cookie': 'session=abc; token=xyz'});
  });

  test('default headers omit cookie when runtime cookie is blank', () {
    ApiConfig.setRuntimeCookie('   ');

    expect(ApiConfig.defaultHeaders, isEmpty);
  });

  test('ApiClient request headers merge cookie with content type', () {
    ApiConfig.setRuntimeCookie('session=abc');

    expect(
      ApiClient().headersForRequest({'Content-Type': 'application/json'}),
      {'Cookie': 'session=abc', 'Content-Type': 'application/json'},
    );
  });
}
