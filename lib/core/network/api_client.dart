import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';

typedef AccessTokenProvider = Future<String?> Function();

/// Small HTTP client used by remote repositories. It never stores credentials;
/// a future Cognito integration supplies the short-lived access token.
class ApiClient {
  factory ApiClient({
    required ApiConfig config,
    http.Client? httpClient,
    AccessTokenProvider? accessTokenProvider,
  }) => ApiClient._(config, httpClient ?? http.Client(), accessTokenProvider);

  ApiClient._(this._config, this._httpClient, this._accessTokenProvider);

  final ApiConfig _config;
  final http.Client _httpClient;
  final AccessTokenProvider? _accessTokenProvider;

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    if (!_config.isConfigured) {
      throw const ApiException(
        message: 'Dịch vụ trực tuyến chưa được cấu hình.',
        isNetworkError: true,
      );
    }

    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    final token = await _accessTokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final request = http.Request(method, _config.uri(path, query))
        ..headers.addAll(headers)
        ..body = body == null ? '' : jsonEncode(body);
      final streamed = await _httpClient.send(request).timeout(_config.timeout);
      final response = await http.Response.fromStream(streamed);
      final decoded = response.body.isEmpty ? null : _decode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          message: _messageFrom(decoded) ?? 'Yêu cầu không thành công.',
          statusCode: response.statusCode,
        );
      }
      return decoded;
    } on TimeoutException {
      throw const ApiException(
        message: 'Kết nối mất quá nhiều thời gian. Vui lòng thử lại.',
        isNetworkError: true,
      );
    } on http.ClientException {
      throw const ApiException(
        message: 'Không thể kết nối đến máy chủ.',
        isNetworkError: true,
      );
    }
  }

  dynamic _decode(String value) {
    try {
      return jsonDecode(value);
    } on FormatException {
      return value;
    }
  }

  String? _messageFrom(dynamic body) => body is Map<String, dynamic>
      ? body['message'] as String? ?? body['error'] as String?
      : null;

  void close() => _httpClient.close();
}
