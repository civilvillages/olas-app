import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';
import '../core/exam_cache.dart';
import '../models/exam.dart';
import 'exam_take_screen.dart';

/// Feature 2 detail + Feature 3 launch.
/// The Download & start button calls /start, fetches the offline package,
/// caches it, and opens the exam player.
class ExamDetailScreen extends StatefulWidget {
  const ExamDetailScreen({super.key, required this.api, required this.exam});
  final ApiClient api;
  final Exam exam;

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen> {
  bool _busy = false;
  String _busyLabel = '';

  Exam get exam => widget.exam;

  Future<void> _startAndDownload() async {
    // Password gate first, if the exam needs one.
    String? password;
    if (exam.requiresPassword) {
      password = await _askPassword();
      if (password == null) return; // cancelled
    }

    setState(() {
      _busy = true;
      _busyLabel = 'Starting exam…';
    });

    // 1) start (or resume) the attempt
    final startRes = await widget.api.post(
      '/cbt/exams/${exam.id}/start',
      body: password != null ? {'password': password} : {},
    );
    if (!startRes.success) {
      _fail(startRes.friendlyError);
      return;
    }
    final attempt = (startRes.data['attempt'] as Map?)?.cast<String, dynamic>();
    final attemptId = (attempt?['id'] as num?)?.toInt();
    if (attemptId == null) {
      _fail('Could not start the exam (no attempt id returned).');
      return;
    }

    // 2) download the offline package
    setState(() => _busyLabel = 'Downloading questions…');
    final pkgRes = await widget.api.get('/cbt/attempts/$attemptId/package');
    if (!pkgRes.success) {
      _fail(pkgRes.friendlyError);
      return;
    }

    // 3) cache it locally so the exam runs offline
    final pkg = pkgRes.data;
    await ExamCache.savePackage(attemptId, pkg);
    await ExamCache.saveMeta(attemptId, {
      'exam_title': exam.title,
      'downloaded_at': DateTime.now().toIso8601String(),
    });

    if (!mounted) return;
    setState(() => _busy = false);

    // 4) launch the player
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamTakeScreen(
          api: widget.api,
          attemptId: attemptId,
          package: pkg,
        ),
      ),
    );
    if (mounted) Navigator.pop(context); // return to list after exam
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() => _busy = false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Could not start'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<String?> _askPassword() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exam password'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Enter the password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Continue')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (label, _) = exam.tag;
    return Scaffold(
      appBar: AppBar(title: const Text('Exam details')),
      body: Stack(children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(exam.title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('${exam.subject} · ${exam.term}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(children: [
                _row('Questions', '${exam.questionCount}'),
                _row('Duration', '${exam.durationMinutes} minutes'),
                _row('Total marks', '${exam.totalMarks}'),
                _row('Pass mark', '${exam.passMark}'),
                _row('Attempts', '${exam.attemptsMade} of ${exam.maxAttempts} used'),
                if (exam.requiresPassword)
                  _row('Password', 'Required', highlight: true),
              ]),
            ),
            const SizedBox(height: 16),
            if (exam.instructions.trim().isNotEmpty) ...[
              const Text('Instructions',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 6),
              Text(exam.instructions,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
              const SizedBox(height: 20),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Branding.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: (exam.canStart && !_busy) ? _startAndDownload : null,
                icon: const Icon(Icons.download_outlined),
                label: Text(exam.hasInProgress
                    ? 'Resume exam'
                    : (exam.canStart ? 'Download & start' : 'Not available')),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                exam.canStart
                    ? 'Once downloaded, the exam runs even with no signal.'
                    : (label == 'Completed'
                        ? 'You have completed this exam.'
                        : 'This exam is not open for you right now.'),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        if (_busy)
          Container(
            color: Colors.black45,
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_busyLabel),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _row(String k, String v, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(k, style: TextStyle(color: Colors.grey.shade600)),
        Text(v,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: highlight ? Branding.primaryColor : Colors.black87)),
      ]),
    );
  }
}
