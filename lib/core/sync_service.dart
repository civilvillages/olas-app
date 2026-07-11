import '../core/api_client.dart';
import 'exam_cache.dart';

/// Feature 4 — flush offline-queued submissions when connectivity returns.
///
/// The server's /cbt/sync endpoint accepts:
///   { "submissions": [ { "attempt_id": n, "answers": [...] }, ... ] }
/// and processes each with the same grading path as a direct submit.
/// Late syncs are accepted within the server's grace window.
class SyncService {
  SyncService(this.api);
  final ApiClient api;

  bool _running = false;

  /// True if any offline submission is still waiting to reach the server.
  static Future<bool> hasPending() async =>
      (await ExamCache.pendingSubmits()).isNotEmpty;

  /// Attempt ids that are queued (used to block retakes of those exams).
  static Future<List<int>> pendingIds() => ExamCache.pendingSubmits();

  /// Try to push everything in the queue. Safe to call repeatedly; no-ops
  /// while a flush is already running or when the queue is empty.
  /// Returns (synced, failed) counts.
  Future<(int, int)> flush() async {
    if (_running) return (0, 0);
    _running = true;
    var ok = 0, bad = 0;
    try {
      final ids = await ExamCache.pendingSubmits();
      if (ids.isEmpty) return (0, 0);

      final submissions = <Map<String, dynamic>>[];
      for (final id in ids) {
        final answers = await ExamCache.loadAnswers(id);
        final pkg = await ExamCache.loadPackage(id);
        final questions = (pkg?['questions'] as List?) ?? const [];
        submissions.add({
          'attempt_id': id,
          'answers': _wireAnswers(questions, answers),
        });
      }

      final res = await api.post('/cbt/sync', body: {'submissions': submissions});
      if (res.success) {
        // The server reports per-item results; treat presence in the response
        // as processed either way (accepted or already-final) and clear.
        for (final id in ids) {
          await ExamCache.purge(id);
          ok++;
        }
      } else {
        bad = ids.length;
      }
    } finally {
      _running = false;
    }
    return (ok, bad);
  }

  /// Convert the local {link_id: value} map into the server's typed array,
  /// using each question's type from the cached package.
  static List<Map<String, dynamic>> _wireAnswers(
      List<dynamic> questions, Map<String, dynamic> answers) {
    bool isTheory(String t) => t == 'theory' || t == 'essay';
    bool isMulti(String t) =>
        t == 'multi' || t == 'multiple_response' || t == 'multiple_select';

    final out = <Map<String, dynamic>>[];
    for (final q in questions) {
      final linkId = (q['link_id'] as num).toInt();
      final type = (q['type'] as String?) ?? 'mcq';
      final a = answers['$linkId'];
      if (a == null) continue;
      final item = <String, dynamic>{'link_id': linkId};
      if (isTheory(type)) {
        if (a is String && a.trim().isNotEmpty) {
          item['answer_text'] = a;
        } else {
          continue;
        }
      } else if (isMulti(type)) {
        if (a is List && a.isNotEmpty) {
          item['selected_original_idxs'] = a.map((e) => e as int).toList();
        } else {
          continue;
        }
      } else {
        if (a is int) {
          item['selected_original_idx'] = a;
        } else {
          continue;
        }
      }
      out.add(item);
    }
    return out;
  }
}
