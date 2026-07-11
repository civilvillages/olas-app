import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/auth_storage.dart';
import '../models/user.dart';

enum AuthStatus { unknown, authenticating, signedIn, signedOut }

/// Holds the authentication state for the whole app. Screens listen to this
/// to know whether to show login or the home area, and call [login]/[logout].
class AuthState extends ChangeNotifier {
  AuthState({ApiClient? api, AuthStorage? storage})
      : api = api ?? ApiClient(),
        _storage = storage ?? AuthStorage();

  final ApiClient api;
  final AuthStorage _storage;

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;
  String? lastError;

  /// Called once at startup: if we have a stored token, adopt it and verify
  /// it with /auth/me. A dead token silently drops us to the login screen.
  Future<void> restore() async {
    final token = await _storage.readToken();
    if (token == null) {
      _set(AuthStatus.signedOut);
      return;
    }
    api.token = token;

    // Optimistically show the cached user while we verify in the background.
    final cached = await _storage.readUser();
    if (cached != null) {
      user = AppUser.fromJson(cached);
    }

    final res = await api.get('/auth/me');
    if (res.success && res.data['user'] != null) {
      user = AppUser.fromJson(res.data['user'] as Map<String, dynamic>);
      await _storage.save(token: token, user: user!.toJson());
      _set(AuthStatus.signedIn);
    } else {
      // Token invalid/expired/revoked — clear and require a fresh login.
      await _storage.clear();
      api.token = null;
      user = null;
      _set(AuthStatus.signedOut);
    }
  }

  /// Log in with any accepted identifier (username, email, or admission number)
  /// plus password. Returns true on success.
  Future<bool> login(String identifier, String password) async {
    lastError = null;
    _set(AuthStatus.authenticating);

    final res = await api.post('/auth/login', withAuth: false, body: {
      'username': identifier.trim(),
      'password': password,
      'device_name': 'OLAS Mobile App',
    });

    if (res.success && res.data['token'] != null) {
      final token = res.data['token'] as String;
      api.token = token;
      user = AppUser.fromJson(
          (res.data['user'] as Map<String, dynamic>?) ?? const {});
      await _storage.save(token: token, user: user!.toJson());
      _set(AuthStatus.signedIn);
      return true;
    }

    lastError = res.friendlyError;
    _set(AuthStatus.signedOut);
    return false;
  }

  /// Log out: tell the server to revoke this token, then clear locally
  /// regardless of the server's reply (we always end up signed out).
  Future<void> logout() async {
    try {
      await api.post('/auth/logout');
    } catch (_) {
      // ignore — we clear locally no matter what
    }
    await _storage.clear();
    api.token = null;
    user = null;
    _set(AuthStatus.signedOut);
  }

  void _set(AuthStatus s) {
    status = s;
    notifyListeners();
  }
}
