import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline storage for staff score entry.
/// Keys per (class,subject,term):
///   sb:<key>  — the downloaded bundle (students, components, existing scores)
///   sd:<key>  — draft entries: {"student:component": "score"}
///   sp:<key>  — a submitted batch waiting to sync (THE LOCK: while this
///               exists, entry for that class-subject-term is frozen)
class ScoreCache {
  static String key(int classId, int subjectId, int termId) =>
      '$classId:$subjectId:$termId';

  static Future<void> saveBundle(String k, Map<String, dynamic> bundle) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('sb:$k', jsonEncode(bundle));
  }

  static Future<Map<String, dynamic>?> bundle(String k) async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('sb:$k');
    return s == null ? null : (jsonDecode(s) as Map).cast<String, dynamic>();
  }

  static Future<void> saveDraft(String k, Map<String, String> draft) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('sd:$k', jsonEncode(draft));
  }

  static Future<Map<String, String>> draft(String k) async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('sd:$k');
    if (s == null) return {};
    return (jsonDecode(s) as Map).map((a, b) => MapEntry('$a', '$b'));
  }

  /// Submit: freeze the batch. Entry stays locked until sync succeeds.
  static Future<void> savePending(String k, Map<String, dynamic> batch) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('sp:$k', jsonEncode(batch));
  }

  static Future<Map<String, dynamic>?> pending(String k) async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('sp:$k');
    return s == null ? null : (jsonDecode(s) as Map).cast<String, dynamic>();
  }

  static Future<void> clearPending(String k) async {
    final p = await SharedPreferences.getInstance();
    await p.remove('sp:$k');
  }

  static Future<void> clearDraft(String k) async {
    final p = await SharedPreferences.getInstance();
    await p.remove('sd:$k');
  }

  /// All pending batch keys (for sync-on-open).
  static Future<List<String>> pendingKeys() async {
    final p = await SharedPreferences.getInstance();
    return p.getKeys()
        .where((x) => x.startsWith('sp:'))
        .map((x) => x.substring(3))
        .toList();
  }
}
