import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/api/api_client.dart';
import 'package:mikudrome/api/config.dart';

void main() {
  tearDown(ApiConfig.resetRuntimeBaseUrlForTests);

  test('ApiClient uses dart define default when no runtime url is set', () {
    ApiConfig.resetRuntimeBaseUrlForTests();

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
}
