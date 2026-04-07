import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_exception.dart';

class ApiMultipartFile {
  const ApiMultipartFile({
    required this.fieldName,
    required this.filename,
    required this.bytes,
    required this.contentType,
  });

  final String fieldName;
  final String filename;
  final Uint8List bytes;
  final MediaType contentType;
}

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
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _httpClient.get(
        _buildUri(path, queryParameters: queryParameters),
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
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _httpClient.get(
        _buildUri(path, queryParameters: queryParameters),
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
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _httpClient.post(
        _buildUri(path, queryParameters: queryParameters),
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
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _httpClient.patch(
        _buildUri(path, queryParameters: queryParameters),
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

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? fields,
    List<ApiMultipartFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) {
    return _sendMultipart(
      'POST',
      path,
      headers: headers,
      fields: fields,
      files: files,
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> patchMultipart(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? fields,
    List<ApiMultipartFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) {
    return _sendMultipart(
      'PATCH',
      path,
      headers: headers,
      fields: fields,
      files: files,
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>?> getNullableJson(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _httpClient.get(
        _buildUri(path, queryParameters: queryParameters),
        headers: _headers(headers),
      );
      return _decodeNullableMapResponse(response);
    } on http.ClientException {
      throw const ApiException(
        message:
            'Unable to reach the server. Check your network connection and ensure the API server is running.',
      );
    }
  }

  Future<void> delete(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _httpClient.delete(
        _buildUri(path, queryParameters: queryParameters),
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

  Uri _buildUri(String path, {Map<String, dynamic>? queryParameters}) {
    final uri = Uri.parse('${_baseUrlResolver()}$path');
    final normalized = _normalizeQueryParameters(queryParameters);

    if (normalized.isEmpty) {
      return uri;
    }

    return uri.replace(
      query: _buildQueryString(<String, List<String>>{
        ...uri.queryParametersAll,
        ...normalized,
      }),
    );
  }

  Map<String, String> _headers(Map<String, String>? headers) {
    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...?headers,
    };
  }

  Map<String, String> _multipartHeaders(Map<String, String>? headers) {
    return <String, String>{'Accept': 'application/json', ...?headers};
  }

  Future<Map<String, dynamic>> _sendMultipart(
    String method,
    String path, {
    Map<String, String>? headers,
    Map<String, String>? fields,
    List<ApiMultipartFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final request =
          http.MultipartRequest(
              method,
              _buildUri(path, queryParameters: queryParameters),
            )
            ..headers.addAll(_multipartHeaders(headers))
            ..fields.addAll(fields ?? const <String, String>{});

      request.files.addAll(
        files.map(
          (file) => http.MultipartFile.fromBytes(
            file.fieldName,
            file.bytes,
            filename: file.filename,
            contentType: file.contentType,
          ),
        ),
      );

      final streamedResponse = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      return _decodeMapResponse(response);
    } on http.ClientException {
      throw const ApiException(
        message:
            'Unable to reach the server. Check your network connection and ensure the API server is running.',
      );
    }
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

  Map<String, dynamic>? _decodeNullableMapResponse(http.Response response) {
    final dynamic decoded = _decodeDynamicBody(response);
    _ensureSuccess(response, decoded: decoded);

    if (decoded == null) {
      return null;
    }

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

  Map<String, List<String>> _normalizeQueryParameters(
    Map<String, dynamic>? queryParameters,
  ) {
    if (queryParameters == null || queryParameters.isEmpty) {
      return const <String, List<String>>{};
    }

    final normalized = <String, List<String>>{};

    for (final entry in queryParameters.entries) {
      final value = entry.value;

      if (value == null) {
        continue;
      }

      if (value is Iterable && value is! String) {
        final values = value
            .map(_normalizeQueryValue)
            .whereType<String>()
            .where((item) => item.isNotEmpty)
            .toList(growable: false);

        if (values.isNotEmpty) {
          normalized[entry.key] = values;
        }

        continue;
      }

      final normalizedValue = _normalizeQueryValue(value);
      if (normalizedValue != null && normalizedValue.isNotEmpty) {
        normalized[entry.key] = <String>[normalizedValue];
      }
    }

    return normalized;
  }

  String? _normalizeQueryValue(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    return value.toString();
  }

  String _buildQueryString(Map<String, List<String>> queryParameters) {
    final parts = <String>[];

    for (final entry in queryParameters.entries) {
      final encodedKey = Uri.encodeQueryComponent(entry.key);

      for (final value in entry.value) {
        parts.add('$encodedKey=${Uri.encodeQueryComponent(value)}');
      }
    }

    return parts.join('&');
  }
}
