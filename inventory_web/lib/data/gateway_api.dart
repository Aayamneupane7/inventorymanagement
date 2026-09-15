import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

const gatewayUrl = String.fromEnvironment(
  'GATEWAY_URL',
  defaultValue: '/gateway',
);

class GatewayException implements Exception {
  GatewayException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class GatewayApi {
  GatewayApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<Map<String, dynamic>> login(String username, String password) =>
      _request(
        'POST',
        '/api/v1/auth/login',
        body: {'username': username, 'password': password},
      );

  Future<List<Map<String, dynamic>>> list(
    String path,
    String key,
    String token,
  ) async {
    final body = await _request('GET', path, token: token);
    return (body[key] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> get(String path, String token) =>
      _request('GET', path, token: token);
  Future<Map<String, dynamic>> post(
    String path,
    String token,
    Map<String, dynamic> body,
  ) => _request('POST', path, token: token, body: body);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(method, Uri.parse('$gatewayUrl$path'))
      ..headers.addAll({
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      })
      ..body = body == null ? '' : jsonEncode(body);
    late http.StreamedResponse response;
    try {
      response = await _client
          .send(request)
          .timeout(const Duration(seconds: 15));
    } on http.ClientException {
      throw GatewayException(
        'Cannot reach the inventory gateway. Check that the inventory services are running and try again.',
      );
    } on TimeoutException {
      throw GatewayException('The inventory gateway took too long to respond.');
    }
    final rawBody = await response.stream.bytesToString();
    final value = rawBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(rawBody) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GatewayException(
        value['error'] as String? ??
            'The inventory server rejected the request.',
        statusCode: response.statusCode,
      );
    }
    return value;
  }
}
