import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// ============================================================================
/// OLAS SCHOOL — WHITE-LABEL BRANDING (server-driven, const-safe)
/// ----------------------------------------------------------------------------
/// For a new school you edit only ONE line: [apiBaseUrl]. Everything else —
/// app name, tagline, logo, colours and enabled features — is set from that
/// school's own portal (Settings → App / White-Label) and fetched on launch.
///
/// IMPORTANT (why colours come in two forms):
///   * The `const` colours below (primaryColor / primaryDark / successColor)
///     are COMPILE-TIME constants, so existing `const` widgets keep working.
///   * The server's colours are applied at the THEME level via themeData(),
///     which recolours the whole app at runtime without needing const anywhere.
///   * If you want a specific widget to follow the *server* colour exactly,
///     use Theme.of(context).colorScheme.primary instead of Branding.primaryColor.
/// ============================================================================
class Branding {
  Branding._();

  /// The ONE value baked per build: this school's portal API. No trailing slash.
  static const String apiBaseUrl = 'https://schoolapp.civilvillage.com/api/v1';

  // ---- Compile-time constant colours (keep existing const widgets valid) ----
  static const Color primaryColor = Color(0xFF0D6EFD);
  static const Color primaryDark = Color(0xFF0A58CA);
  static const Color successColor = Color(0xFF198754);
  static const String logoAsset = 'assets/images/logo.png';

  // ---- Runtime values from the server (safe defaults until load()) ----------
  static String schoolName = 'OLAS School';
  static String tagline = 'School Portal';
  static String logoUrl = '';
  static String supportContact = 'civivillages@gmail.com';
  static String contactPhone = '';
  static String websiteUrl = '';
  static String privacyUrl = '';
  static String apkUrl = '';
  static String storeUrl = '';

  /// Server-driven colours (used to build the app THEME; default to the consts).
  static Color themePrimary = primaryColor;
  static Color themeAccent = successColor;

  /// Feature flags — default ON so nothing disappears before config loads.
  static final Map<String, bool> features = {
    'results': true, 'cbt': true, 'fees': true, 'messaging': true,
    'announcements': true, 'attendance': true, 'events': true,
  };

  static bool loaded = false;

  /// True if a feature is enabled for this install. Unknown keys default true.
  static bool enabled(String key) => features[key] ?? true;

  /// Build a ThemeData from the server colours. Call in MaterialApp(theme:).
  /// This is how the server's brand colours recolour the whole app at runtime.
  static ThemeData themeData() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: themePrimary,
        primary: themePrimary,
        secondary: themeAccent,
      ),
      appBarTheme: AppBarTheme(backgroundColor: themePrimary, foregroundColor: Colors.white),
    );
  }

  /// Fetch identity + features from this install's portal. Call once at startup
  /// (before runApp). Never throws — falls back to defaults on any error.
  static Future<void> load({http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final res = await c
          .get(Uri.parse('$apiBaseUrl/app-config'),
              headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body);
      final data = (body is Map && body['data'] is Map) ? body['data'] as Map : null;
      if (data == null) return;

      final id = (data['identity'] as Map?) ?? const {};
      final contact = (data['contact'] as Map?) ?? const {};
      final feat = (data['features'] as Map?) ?? const {};

      schoolName = _str(id['app_name'], schoolName);
      tagline = _str(id['tagline'], tagline);
      logoUrl = _str(id['logo_url'], '');
      themePrimary = _hex(id['primary_color'], primaryColor);
      themeAccent = _hex(id['accent_color'], successColor);

      supportContact = _str(contact['email'], supportContact);
      contactPhone = _str(contact['phone'], '');
      websiteUrl = _str(contact['website'], '');
      privacyUrl = _str(contact['privacy_url'], '');
      apkUrl = _str(contact['apk_url'], '');
      storeUrl = _str(contact['store_url'], '');

      for (final k in features.keys.toList()) {
        if (feat.containsKey(k)) features[k] = feat[k] == true;
      }
      loaded = true;
    } catch (_) {
      // keep defaults; app still works offline / if the endpoint is down
    }
  }

  // ---- helpers -------------------------------------------------------------
  static String _str(dynamic v, String d) =>
      (v is String && v.trim().isNotEmpty) ? v.trim() : d;

  static Color _hex(dynamic v, Color d) {
    if (v is! String) return d;
    var s = v.trim().replaceAll('#', '');
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return d;
    final n = int.tryParse(s, radix: 16);
    return n == null ? d : Color(n);
  }
}
