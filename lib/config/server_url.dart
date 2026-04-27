class ServerUrlException implements Exception {
  const ServerUrlException(this.message);

  final String message;

  @override
  String toString() => message;
}

String normalizeServerUrl(String input) {
  var value = input.trim();
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  if (value.isEmpty) {
    throw const ServerUrlException('Server URL is required.');
  }

  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw const ServerUrlException(
      'Enter a full server URL such as http://192.168.1.10:8080.',
    );
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    throw const ServerUrlException(
      'Server URL must start with http:// or https://.',
    );
  }
  if (uri.hasQuery || uri.hasFragment) {
    throw const ServerUrlException(
      'Server URL must not include query strings or fragments.',
    );
  }
  try {
    uri.port;
  } on FormatException {
    throw const ServerUrlException('Enter a valid server port.');
  }
  return value;
}
