import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';

/// Feature 5 — one attempt's result, matching the portal's student view:
/// big score, percentage, pass/fail, correct / incorrect / unanswered counts.
/// Withheld results show the server's own release message.
class ResultDetailScreen extends StatefulWidget {
  const ResultDetailScreen(
      {super.key, required this.api, required this.attemptId});
  final ApiClient api;
  final int attemptId;

  @override
  State<ResultDetailScreen> createState() => _ResultDetailScreenState();
}

class _ResultDetailScreenState extends State<ResultDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _r = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await widget.api.get('/cbt/attempts/${widget.attemptId}/result');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        _r = res.data;
      } else {
        _error = res.friendlyError;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Branding.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Result'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(_error!, textAlign: TextAlign.center),
                ))
              : _body(),
    );
  }

  Widget _body() {
    final visible = (_r['result_visible'] as bool?) ?? false;
    final title = '${_r['exam_title'] ?? 'Exam'}';
    final subject = '${_r['subject'] ?? ''}';

    if (!visible) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(subject, style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 40),
        Icon(Icons.lock_clock, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Center(
          child: Text(
            '${_r['message'] ?? 'Results will be released by the school.'}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
        ),
      ]);
    }

    final score = (_r['score'] as num?) ?? 0;
    final total = (_r['total_marks'] as num?) ?? 0;
    final passMark = (_r['pass_mark'] as num?) ?? 0;
    final pct = total > 0 ? (score / total * 100) : 0.0;
    final passed = total > 0 && score >= passMark;
    final correct = (_r['correct_answers'] as num?)?.toInt() ?? 0;
    final incorrect = (_r['incorrect_answers'] as num?)?.toInt() ?? 0;
    final unanswered = (_r['unanswered'] as num?)?.toInt() ?? 0;
    final pendingReview = (_r['pending_manual_review'] as bool?) ?? false;

    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      Text(subject, style: TextStyle(color: Colors.grey.shade600)),
      const SizedBox(height: 20),

      // Score hero card
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: (passed ? Branding.successColor : Colors.red.shade700)
              .withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: (passed ? Branding.successColor : Colors.red.shade700)
                  .withOpacity(0.3)),
        ),
        child: Column(children: [
          Text('${_trim(score)} / ${_trim(total)}',
              style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color:
                      passed ? Branding.successColor : Colors.red.shade700)),
          const SizedBox(height: 4),
          Text('${pct.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade700)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: passed ? Branding.successColor : Colors.red.shade700,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(passed ? 'PASSED' : 'FAILED',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
          if (pendingReview) ...[
            const SizedBox(height: 10),
            Text('Some answers are awaiting manual marking — this score may change.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          ],
        ]),
      ),
      const SizedBox(height: 16),

      // Counts row (portal-style)
      Row(children: [
        _stat('Correct', correct, Branding.successColor),
        const SizedBox(width: 10),
        _stat('Incorrect', incorrect, Colors.red.shade700),
        const SizedBox(width: 10),
        _stat('Unanswered', unanswered, Colors.grey.shade600),
      ]),
      const SizedBox(height: 16),

      // Meta
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(children: [
          _row('Attempt', '#${_r['attempt_number'] ?? 1}'),
          _row('Pass mark', _trim(passMark)),
          _row('Submitted',
              _fmtDate('${_r['submitted_at'] ?? ''}')),
          if ((_r['auto_submitted'] as bool?) ?? false)
            _row('Note', 'Auto-submitted when time expired'),
        ]),
      ),
    ]);
  }

  Widget _stat(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text('$value',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ]),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(k, style: TextStyle(color: Colors.grey.shade600)),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );
  }

  String _trim(num n) =>
      n == n.roundToDouble() ? '${n.toInt()}' : n.toStringAsFixed(1);

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final ap = d.hour >= 12 ? 'PM' : 'AM';
      return '${d.day} ${months[d.month - 1]} ${d.year}, $h:${d.minute.toString().padLeft(2, '0')} $ap';
    } catch (_) {
      return iso;
    }
  }
}
