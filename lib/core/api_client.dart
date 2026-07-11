import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/branding.dart';

/// The shape every OLAS API response takes: {success, data, error, meta}.
class ApiResult {
  final bool success;
  final Map<String, dynamic> data;
  final Map<String, dynamic> meta;
  final String? errorCode;
  final String? errorMessage;
  final int statusCode;

  ApiResult({
    required this.success,
    required this.data,
    required this.meta,
    required this.statusCode,
    this.errorCode,
    this.errorMessage,
  });

  /// A human-friendly message for any failure (network or API).
  String get friendlyError =>
      errorMessage ?? 'Something went wrong. Please try again.';
}

/// Thin wrapper over the OLAS REST API. Every method returns an [ApiResult];
/// callers check [ApiResult.success] and read [data]/[meta] or [friendlyError].
class ApiClient {
  ApiClient({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  String? _token;

  /// Set/clear the bearer token used for authenticated calls.
  set token(String? value) => _token = value;
  String? get token => _token;

  Uri _url(String path, [Map<String, dynamic>? query]) {
    final base = Branding.apiBaseUrl;
    final full = '$base$path';
    final uri = Uri.parse(full);
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...query.map((k, v) => MapEntry(k, '$v')),
    });
  }

  Map<String, String> _headers({bool withAuth = true, bool json = false}) {
    final h = <String, String>{'Accept': 'application/json'};
    if (json) h['Content-Type'] = 'application/json';
    if (withAuth && _token != null) h['Authorization'] = 'Bearer $_token';
    return h;
  }

  Future<ApiResult> get(String path,
      {Map<String, dynamic>? query, bool withAuth = true}) async {
    return _send(() =>
        _http.get(_url(path, query), headers: _headers(withAuth: withAuth)));
  }

  Future<ApiResult> post(String path,
      {Map<String, dynamic>? body, bool withAuth = true}) async {
    return _send(() => _http.post(
          _url(path),
          headers: _headers(withAuth: withAuth, json: true),
          body: jsonEncode(body ?? {}),
        ));
  }

  Future<ApiResult> put(String path,
      {Map<String, dynamic>? body, bool withAuth = true}) async {
    return _send(() => _http.put(
          _url(path),
          headers: _headers(withAuth: withAuth, json: true),
          body: jsonEncode(body ?? {}),
        ));
  }

  Future<ApiResult> delete(String path, {bool withAuth = true}) async {
    return _send(() =>
        _http.delete(_url(path), headers: _headers(withAuth: withAuth)));
  }

  /// Runs the request, decodes the envelope, and never throws for a normal
  /// API error — it returns an unsuccessful [ApiResult] instead. Only truly
  /// unexpected failures (no network) surface as a synthetic error result.
  Future<ApiResult> _send(Future<http.Response> Function() run) async {
    try {
      final res = await run().timeout(const Duration(seconds: 30));
      Map<String, dynamic> decoded;
      try {
        decoded = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return ApiResult(
          success: false,
          data: const {},
          meta: const {},
          statusCode: res.statusCode,
          errorCode: 'bad_response',
          errorMessage: 'The server returned an unexpected response.',
        );
      }

      final success = decoded['success'] == true;
      final error = decoded['error'] as Map<String, dynamic>?;
      return ApiResult(
        success: success,
        data: (decoded['data'] as Map<String, dynamic>?) ?? const {},
        meta: (decoded['meta'] as Map<String, dynamic>?) ?? const {},
        statusCode: res.statusCode,
        errorCode: error?['code'] as String?,
        errorMessage: error?['message'] as String?,
      );
    } catch (e) {
      return ApiResult(
        success: false,
        data: const {},
        meta: const {},
        statusCode: 0,
        errorCode: 'network_error',
        errorMessage:
            'Could not reach the server. Check your internet connection and try again.',
      );
    }
  }
}
