import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/config/server_url.dart';

void main() {
  group('normalizeServerUrl', () {
    test('trims whitespace and removes trailing slashes', () {
      expect(
        normalizeServerUrl('  http://192.168.1.10:8080///  '),
        'http://192.168.1.10:8080',
      );
    });

    test('keeps https URLs valid', () {
      expect(
        normalizeServerUrl('https://music.example.test/'),
        'https://music.example.test',
      );
    });

    test('rejects missing scheme', () {
      expect(
        () => normalizeServerUrl('192.168.1.10:8080'),
        throwsA(isA<ServerUrlException>()),
      );
    });

    test('rejects unsupported schemes', () {
      expect(
        () => normalizeServerUrl('ftp://example.test'),
        throwsA(isA<ServerUrlException>()),
      );
    });

    test('rejects query strings', () {
      expect(
        () => normalizeServerUrl('http://192.168.1.10:8080?x=1'),
        throwsA(isA<ServerUrlException>()),
      );
    });

    test('rejects empty query delimiters', () {
      expect(
        () => normalizeServerUrl('http://192.168.1.10:8080?'),
        throwsA(isA<ServerUrlException>()),
      );
    });

    test('rejects fragments', () {
      expect(
        () => normalizeServerUrl('http://192.168.1.10:8080#app'),
        throwsA(isA<ServerUrlException>()),
      );
    });

    test('rejects empty fragment delimiters', () {
      expect(
        () => normalizeServerUrl('http://192.168.1.10:8080#'),
        throwsA(isA<ServerUrlException>()),
      );
    });

    test('rejects malformed ports', () {
      expect(
        () => normalizeServerUrl('http://192.168.1.10:808O'),
        throwsA(isA<ServerUrlException>()),
      );
    });

    test('rejects empty input', () {
      expect(
        () => normalizeServerUrl('   '),
        throwsA(isA<ServerUrlException>()),
      );
    });
  });
}
