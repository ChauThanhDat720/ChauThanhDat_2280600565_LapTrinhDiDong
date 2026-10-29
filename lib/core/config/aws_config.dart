import 'dart:convert';

class AwsSettings {
  const AwsSettings({
    required this.mode,
    required this.region,
    required this.userPoolId,
    required this.appClientId,
    required this.apiBaseUrl,
    this.allowInsecureHttp = false,
  });
  final String mode, region, userPoolId, appClientId, apiBaseUrl;
  final bool allowInsecureHttp;
  bool get useAws => mode == 'aws';
  bool get useShared => mode == 'shared';
  void validate() {
    if (!['local', 'aws', 'shared'].contains(mode)) {
      throw StateError('BACKEND_MODE phải là local, aws hoặc shared.');
    }
    if (useShared) {
      final uri = Uri.tryParse(apiBaseUrl);
      if (uri == null ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          !(uri.scheme == 'https' ||
              (allowInsecureHttp && uri.scheme == 'http'))) {
        throw StateError(
          'Backend chia sẻ cần API_BASE_URL HTTPS. Demo local HTTP cần ALLOW_INSECURE_HTTP=true.',
        );
      }
      return;
    }
    if (!useAws) return;
    final missing = <String>[
      if (region.isEmpty) 'AWS_REGION',
      if (userPoolId.isEmpty) 'COGNITO_USER_POOL_ID',
      if (appClientId.isEmpty) 'COGNITO_APP_CLIENT_ID',
      if (apiBaseUrl.isEmpty) 'API_BASE_URL',
    ];
    if (missing.isNotEmpty) {
      throw StateError('Thiếu cấu hình AWS: ${missing.join(', ')}.');
    }
    if (!RegExp(r'^[a-z]{2}(?:-[a-z]+)+-\d$').hasMatch(region) ||
        !userPoolId.startsWith('${region}_')) {
      throw StateError('AWS_REGION và COGNITO_USER_POOL_ID không khớp.');
    }
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw StateError(
        'API_BASE_URL phải là URL HTTPS hợp lệ, không có query, fragment hoặc mật khẩu.',
      );
    }
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(appClientId)) {
      throw StateError('COGNITO_APP_CLIENT_ID không hợp lệ.');
    }
  }
}

abstract final class AwsConfig {
  static const settings = AwsSettings(
    mode: String.fromEnvironment('BACKEND_MODE', defaultValue: 'local'),
    region: String.fromEnvironment('AWS_REGION'),
    userPoolId: String.fromEnvironment('COGNITO_USER_POOL_ID'),
    appClientId: String.fromEnvironment('COGNITO_APP_CLIENT_ID'),
    apiBaseUrl: String.fromEnvironment('API_BASE_URL'),
    allowInsecureHttp: bool.fromEnvironment('ALLOW_INSECURE_HTTP'),
  );
  static bool get useAws => settings.useAws;
  static bool get useShared => settings.useShared;
  static String get region => settings.region;
  static String get userPoolId => settings.userPoolId;
  static String get appClientId => settings.appClientId;
  static bool get isCognitoConfigured =>
      region.isNotEmpty && userPoolId.isNotEmpty && appClientId.isNotEmpty;
  static String get amplifyConfiguration => jsonEncode({
    'UserAgent': 'smart-hospital',
    'Version': '1.0',
    'auth': {
      'plugins': {
        'awsCognitoAuthPlugin': {
          'UserAgent': 'smart-hospital',
          'Version': '1.0',
          'IdentityManager': {'Default': {}},
          'CognitoUserPool': {
            'Default': {
              'PoolId': userPoolId,
              'AppClientId': appClientId,
              'Region': region,
            },
          },
          'Auth': {
            'Default': {'authenticationFlowType': 'USER_SRP_AUTH'},
          },
        },
      },
    },
  });
}
