import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

class ApiClient {
  ApiClient({
    required String Function() baseUrlResolver,
    http.Client? httpClient,
  }) : _baseUrlResolver = baseUrlResolver,
       _httpClient = httpClient ?? http.Client();

  final String Function() _baseUrlResolver;
  final http.Client _httpClient;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _httpClient.get(
        _buildUri(path),
        headers: _headers(headers),
      );
      return _decodeMapResponse(response);
    } on http.ClientException {
      throw const ApiException(
        message:
            'Unable to reach the server. Check your network connection and ensure the API server is running.',
      );
    }
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _httpClient.get(
        _buildUri(path),
        headers: _headers(headers),
      );
      return _decodeListResponse(response);
    } on http.ClientException {
      throw const ApiException(
        message:
            'Unable to reach the server. Check your network connection and ensure the API server is running.',
      );
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      final response = await _httpClient.post(
        _buildUri(path),
        headers: _headers(headers),
        body: body == null ? null : jsonEncode(body),
      );
      return _decodeMapResponse(response);
    } on http.ClientException {
      throw const ApiException(
        message:
            'Unable to reach the server. Check your network connection and ensure the API server is running.',
      );
    }
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      final response = await _httpClient.patch(
        _buildUri(path),
        headers: _headers(headers),
        body: body == null ? null : jsonEncode(body),
      );
      return _decodeMapResponse(response);
    } on http.ClientException {
      throw const ApiException(
        message:
            'Unable to reach the server. Check your network connection and ensure the API server is running.',
      );
    }
  }

  Future<void> delete(String path, {Map<String, String>? headers}) async {
    try {
      final response = await _httpClient.delete(
        _buildUri(path),
        headers: _headers(headers),
      );
      _ensureSuccess(response);
    } on http.ClientException {
      throw const ApiException(
        message:
            'Unable to reach the server. Check your network connection and ensure the API server is running.',
      );
    }
  }

  Uri _buildUri(String path) {
    return Uri.parse('${_baseUrlResolver()}$path');
  }

  Map<String, String> _headers(Map<String, String>? headers) {
    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...?headers,
    };
  }

  Map<String, dynamic> _decodeMapResponse(http.Response response) {
    final dynamic decoded = _decodeDynamicBody(response);
    _ensureSuccess(response, decoded: decoded);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw ApiException(
      message: 'Unexpected API response format.',
      statusCode: response.statusCode,
    );
  }

  List<dynamic> _decodeListResponse(http.Response response) {
    final dynamic decoded = _decodeDynamicBody(response);
    _ensureSuccess(response, decoded: decoded);

    if (decoded is List<dynamic>) {
      return decoded;
    }

    throw ApiException(
      message: 'Unexpected API response format.',
      statusCode: response.statusCode,
    );
  }

  dynamic _decodeDynamicBody(http.Response response) {
    final body = response.body.trim();

    return body.isEmpty ? null : jsonDecode(body);
  }

  void _ensureSuccess(http.Response response, {dynamic decoded}) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw ApiException(
      message: _extractErrorMessage(decoded),
      statusCode: response.statusCode,
    );
  }

  String _extractErrorMessage(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final message = decoded['message'];

      if (message is String && message.trim().isNotEmpty) {
        return message;
      }

      if (message is List && message.isNotEmpty) {
        return message.join(', ');
      }
    }

    return 'Request failed. Please try again.';
  }
}
