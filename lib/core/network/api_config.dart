/// Runtime API configuration supplied when building or running the app.
///
/// Example: `flutter run --dart-define=API_BASE_URL=https://api.example.com`.
/// The empty default deliberately keeps the current local-first app offline.
class ApiConfig {
  ApiConfig({String? baseUrl, Duration? timeout})
    : baseUrl = baseUrl ?? _definedBaseUrl,
      timeout = timeout ?? _definedTimeout;

  static const _definedBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _timeoutSeconds = int.fromEnvironment(
    'API_TIMEOUT_SECONDS',
    defaultValue: 15,
  );
  static final _definedTimeout = Duration(seconds: _timeoutSeconds);

  final String baseUrl;
  final Duration timeout;

  bool get isConfigured => Uri.tryParse(baseUrl)?.hasScheme ?? false;

  Uri uri(String path, [Map<String, String>? queryParameters]) {
    if (!isConfigured) {
      throw StateError('API_BASE_URL chưa được cấu hình.');
    }
    final base = Uri.parse(baseUrl);
    final normalizedBase = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return base.replace(
      path: '$normalizedBase$normalizedPath',
      queryParameters: queryParameters,
    );
  }
}
