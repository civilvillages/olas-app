import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// ============================================================================
/// OLAS SCHOOL — WHITE-LABEL BRANDING (server-driven)
/// ----------------------------------------------------------------------------
/// For a new school you now edit only ONE line: [apiBaseUrl] (point it at that
/// school's portal). Everything else — app name, tagline, colours, logo,
/// contact details and which features are enabled — is set from that school's
/// own portal (Settings → App / White-Label) and fetched on launch. No rebuild
/// needed to rebrand.
///
/// The constants below are only FALLBACK defaults, used before the config has
/// loaded or if the server can't be reached.
/// ============================================================================
class Branding {
  Branding._();

  /// The ONE value baked per build: this school's portal API. No trailing slash.
  static const String apiBaseUrl = 'https://schoolapp.civilvillage.com/api/v1';

  // ---- Fallback defaults (used until /app-config loads) --------------------
  static const String _defaultName = 'OLAS School';
  static const String _defaultTagline = 'School Portal';
  static const Color _defaultPrimary = Color(0xFF0D6EFD);
  static const Color _defaultAccent = Color(0xFF198754);
  static const String logoAsset = 'assets/images/logo.png';
  static const String _defaultSupport = 'civivillages@gmail.com';

  // ---- Live values (populated by load(); safe defaults meanwhile) ----------
  static String schoolName = _defaultName;
  static String tagline = _defaultTagline;
  static String logoUrl = ''; // network logo; empty -> use logoAsset/placeholder
  static Color primaryColor = _defaultPrimary;
  static Color primaryDark = _shade(_defaultPrimary, 0.82);
  static Color successColor = _defaultAccent;
  static String supportContact = _defaultSupport;
  static String websiteUrl = '';
  static String privacyUrl = '';
  static String contactPhone = '';

  /// Feature flags — default ON so nothing disappears before config loads.
  static final Map<String, bool> features = {
    'results': true,
    'cbt': true,
    'fees': true,
    'messaging': true,
    'announcements': true,
    'attendance': true,
    'events': true,
  };

  static bool loaded = false;

  /// True if a feature is enabled for this install. Unknown keys default true.
  static bool enabled(String key) => features[key] ?? true;

  /// Fetch identity + features from this install's portal. Call once at startup
  /// (before runApp, or in a splash). Never throws — falls back to defaults.
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

      schoolName = _str(id['app_name'], _defaultName);
      tagline = _str(id['tagline'], _defaultTagline);
      logoUrl = _str(id['logo_url'], '');
      primaryColor = _hex(id['primary_color'], _defaultPrimary);
      primaryDark = _shade(primaryColor, 0.82);
      successColor = _hex(id['accent_color'], _defaultAccent);

      supportContact = _str(contact['email'], _defaultSupport);
      contactPhone = _str(contact['phone'], '');
      websiteUrl = _str(contact['website'], '');
      privacyUrl = _str(contact['privacy_url'], '');

      for (final k in features.keys.toList()) {
        if (feat.containsKey(k)) features[k] = feat[k] == true;
      }
      loaded = true;
    } catch (_) {
      // keep defaults; app still works offline / if config endpoint is down
    }
  }

  // ---- helpers -------------------------------------------------------------
  static String _str(dynamic v, String d) =>
      (v is String && v.trim().isNotEmpty) ? v.trim() : d;

  /// Parse '#RRGGBB' or 'RRGGBB' into a Color; fall back on any error.
  static Color _hex(dynamic v, Color d) {
    if (v is! String) return d;
    var s = v.trim().replaceAll('#', '');
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return d;
    final n = int.tryParse(s, radix: 16);
    return n == null ? d : Color(n);
  }

  /// Darken a colour by [factor] (0..1) for gradient/pressed states.
  static Color _shade(Color c, double factor) {
    return Color.fromARGB(
      c.alpha,
      (c.red * factor).round().clamp(0, 255),
      (c.green * factor).round().clamp(0, 255),
      (c.blue * factor).round().clamp(0, 255),
    );
  }
}
