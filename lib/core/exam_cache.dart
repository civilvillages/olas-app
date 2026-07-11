import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local, offline-first storage for a downloaded exam and the student's
/// in-progress answers. Everything is JSON in shared_preferences, so it
/// survives the app closing and needs no network.
///
/// Keys:
///   pkg:<attemptId>       -> the full exam package (questions, options, timing)
///   ans:<attemptId>       -> { link_id: answer } map, saved after every change
///   meta:<attemptId>      -> small status record (submitted?, endsAt, examTitle)
///   pending_submits       -> [attemptId, ...] queued for sync when back online
class ExamCache {
  static Future<SharedPreferences> get _p async =>
      SharedPreferences.getInstance();

  // ---- package ----
  static Future<void> savePackage(int attemptId, Map<String, dynamic> pkg) async {
    final p = await _p;
    await p.setString('pkg:$attemptId', jsonEncode(pkg));
  }

  static Future<Map<String, dynamic>?> loadPackage(int attemptId) async {
    final p = await _p;
    final s = p.getString('pkg:$attemptId');
    return s == null ? null : jsonDecode(s) as Map<String, dynamic>;
  }

  // ---- answers ----
  static Future<void> saveAnswers(
      int attemptId, Map<String, dynamic> answers) async {
    final p = await _p;
    await p.setString('ans:$attemptId', jsonEncode(answers));
  }

  static Future<Map<String, dynamic>> loadAnswers(int attemptId) async {
    final p = await _p;
    final s = p.getString('ans:$attemptId');
    if (s == null) return {};
    return (jsonDecode(s) as Map).cast<String, dynamic>();
  }

  // ---- meta ----
  static Future<void> saveMeta(int attemptId, Map<String, dynamic> meta) async {
    final p = await _p;
    await p.setString('meta:$attemptId', jsonEncode(meta));
  }

  static Future<Map<String, dynamic>?> loadMeta(int attemptId) async {
    final p = await _p;
    final s = p.getString('meta:$attemptId');
    return s == null ? null : (jsonDecode(s) as Map).cast<String, dynamic>();
  }

  // ---- pending submits (offline queue) ----
  static Future<void> queueSubmit(int attemptId) async {
    final p = await _p;
    final list = p.getStringList('pending_submits') ?? [];
    if (!list.contains('$attemptId')) {
      list.add('$attemptId');
      await p.setStringList('pending_submits', list);
    }
  }

  static Future<List<int>> pendingSubmits() async {
    final p = await _p;
    return (p.getStringList('pending_submits') ?? [])
        .map(int.parse)
        .toList();
  }

  static Future<void> clearPending(int attemptId) async {
    final p = await _p;
    final list = p.getStringList('pending_submits') ?? [];
    list.remove('$attemptId');
    await p.setStringList('pending_submits', list);
  }

  // ---- cleanup after a confirmed submit ----
  static Future<void> purge(int attemptId) async {
    final p = await _p;
    await p.remove('pkg:$attemptId');
    await p.remove('ans:$attemptId');
    // keep meta so the UI can show "submitted"; clear pending
    await clearPending(attemptId);
  }
}
