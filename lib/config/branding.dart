import 'package:flutter/material.dart';

/// ============================================================================
/// OLAS SCHOOL — WHITE-LABEL BRANDING
/// ----------------------------------------------------------------------------
/// This is the ONLY file you edit when installing the app for a different
/// school. Change the values below, update the app name (see setup guide,
/// step "Rename per school"), drop in a new logo, and rebuild.
/// Nothing else in the codebase needs to change.
/// ============================================================================
class Branding {
  Branding._();

  /// The school's display name (shown on the login screen and headers).
  static const String schoolName = 'OLAS School';

  /// A short tagline under the school name on the login screen. Optional.
  static const String tagline = 'School Portal';

  /// The base URL of THIS school's portal API. No trailing slash.
  /// e.g. https://schoolapp.civilvillage.com/api/v1
  static const String apiBaseUrl = 'https://schoolapp.civilvillage.com/api/v1';

  /// Primary brand colour (buttons, highlights, app bar).
  static const Color primaryColor = Color(0xFF0D6EFD);

  /// A darker shade of the primary, used for gradients / pressed states.
  static const Color primaryDark = Color(0xFF0A58CA);

  /// Accent colour for success states (e.g. "available now").
  static const Color successColor = Color(0xFF198754);

  /// Asset path to the school logo shown on the login screen.
  /// Place the file at assets/images/logo.png (see pubspec.yaml).
  /// If the asset is missing, a lettered placeholder is shown instead.
  static const String logoAsset = 'assets/images/logo.png';

  /// Support contact shown on the login screen's help text. Optional.
  static const String supportContact = 'civivillages@gmail.com';
}
