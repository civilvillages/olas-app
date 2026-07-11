import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the auth token and a small cached copy of the signed-in user,
/// so the app can skip the login screen on next launch. Uses the platform
/// keystore/keychain via flutter_secure_storage — the token is never in
/// plain SharedPreferences.
class AuthStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kToken = 'olas_token';
  static const _kUser = 'olas_user';

  Future<void> save({required String token, required Map<String, dynamic> user}) async {
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kUser, value: jsonEncode(user));
  }

  Future<String?> readToken() => _storage.read(key: _kToken);

  Future<Map<String, dynamic>?> readUser() async {
    final raw = await _storage.read(key: _kUser);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kUser);
  }
}
