import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/branding.dart';

/// The shape every OLAS API response takes: {success, data, error, meta}.
class ApiResult {
  final bool success;
  final Map<String, dynamic> data;
  final Map<String, dynamic> meta;

  /// The raw `data` payload exactly as the server sent it — a Map, a List, or
  /// null. Use [listData] when an endpoint returns a top-level array.
  final dynamic rawData;

  final String? errorCode;
  final String? errorMessage;
  final int statusCode;

  ApiResult({
    required this.success,
    required this.data,
    required this.meta,
    required this.statusCode,
    this.rawData,
    this.errorCode,
    this.errorMessage,
  });

  /// `data` when the endpoint returns a top-level JSON array. Empty if not.
  List<dynamic> get listData => rawData is List ? rawData as List : const [];

  /// A human-friendly message for any failure (network or API).
  String get friendlyError =>
      errorMessage ?? 'Something went wrong. Please try again.';
}

/// Coerce any JSON value to a `Map<String, dynamic>`. A List, null, string, or
/// number all degrade to an empty map instead of throwing on a bad cast — this
/// is the single guard that stops shape drift from white-screening a page.
Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map) {
    return v.map((k, val) => MapEntry('$k', val));
  }
  return const {};
}

/// Public safe accessors for screens — never throw on unexpected shapes.
Map<String, dynamic> asMap(dynamic v) => _asMap(v);
List<dynamic> asList(dynamic v) => v is List ? v : const [];

/// Coerce a `{key: value}` map OR a `[{...}, {...}]` list into a list of
/// entries the UI can iterate. Grade distributions, gender splits, etc. arrive
/// in both shapes across endpoints; this normalizes them.
/// - Map  {A: 5, B: 3}                    -> [(A,5),(B,3)]
/// - List [{grade:A,count:5}, ...]         -> [(A,5)...] using [keyField]/[valField]
List<MapEntry<String, dynamic>> asEntries(dynamic v,
    {String keyField = 'label', String valField = 'value'}) {
  if (v is Map) {
    return v.entries.map((e) => MapEntry('${e.key}', e.value)).toList();
  }
  if (v is List) {
    return v.whereType<Map>().map((m) {
      final k = m[keyField] ?? m['grade'] ?? m['name'] ?? m['key'] ?? m['label'];
      final val = m[valField] ?? m['count'] ?? m['total'] ?? m['value'];
      return MapEntry('$k', val);
    }).toList();
  }
  return const [];
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

  Future<ApiResult> _send(Future<http.Response> Function() run) async {
    try {
      final res = await run();
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
      final error = _asMap(decoded['error']);
      return ApiResult(
        success: success,
        // Coerce defensively: some endpoints legitimately return a JSON array
        // for `data`. Casting that straight to Map<String,dynamic> used to throw
        // "List is not a subtype of Map" and white-screen the whole page. Now a
        // list payload is preserved under `rawData` and `data` degrades to {}.
        data: _asMap(decoded['data']),
        meta: _asMap(decoded['meta']),
        rawData: decoded['data'],
        statusCode: res.statusCode,
        errorCode: error['code'] as String?,
        errorMessage: error['message'] as String?,
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
