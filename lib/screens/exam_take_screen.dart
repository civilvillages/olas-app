import 'dart:async';
import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';
import '../core/exam_cache.dart';

/// Feature 3 — the offline exam player.
/// Renders one question at a time (mcq / multi / boolean / theory), keeps a
/// live countdown from the server's ends_at, autosaves every answer to local
/// storage, and auto-submits when time runs out (with a 2-minute warning).
class ExamTakeScreen extends StatefulWidget {
  const ExamTakeScreen({
    super.key,
    required this.api,
    required this.attemptId,
    required this.package,
  });
  final ApiClient api;
  final int attemptId;
  final Map<String, dynamic> package;

  @override
  State<ExamTakeScreen> createState() => _ExamTakeScreenState();
}

class _ExamTakeScreenState extends State<ExamTakeScreen> {
  late List<dynamic> _questions;
  late Map<String, dynamic> _answers; // link_id -> answer
  int _index = 0;

  Timer? _ticker;
  Duration _remaining = Duration.zero;
  bool _warned2min = false;
  bool _submitting = false;

  String _examTitle = 'Exam';
  final Map<String, TextEditingController> _theoryControllers = {};

  @override
  void initState() {
    super.initState();
    final pkg = widget.package;
    final exam = (pkg['exam'] as Map?) ?? const {};
    _examTitle = (exam['title'] as String?) ?? 'Exam';
    _questions = (pkg['questions'] as List?) ?? const [];
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // resume any locally-saved answers
    _answers = await ExamCache.loadAnswers(widget.attemptId);
    // if the package brought server-side saved answers, merge them in
    final saved = (widget.package['saved_answers'] as Map?)?.cast<String, dynamic>();
    if (saved != null) {
      for (final e in saved.entries) {
        _answers.putIfAbsent(e.key, () => e.value);
      }
    }
    _startTimer();
    if (mounted) setState(() {});
  }

  void _startTimer() {
    final attempt = (widget.package['attempt'] as Map?) ?? const {};
    final endsAtStr = attempt['ends_at'] as String?;
    final serverNowStr = attempt['server_time'] as String?;
    DateTime endsAt;
    DateTime base;
    try {
      endsAt = DateTime.parse(endsAtStr!).toUtc();
      base = serverNowStr != null
          ? DateTime.parse(serverNowStr).toUtc()
          : DateTime.now().toUtc();
    } catch (_) {
      // fallback: duration_minutes from now
      final mins = (attempt['duration_minutes'] as num?)?.toInt() ?? 30;
      endsAt = DateTime.now().toUtc().add(Duration(minutes: mins));
      base = DateTime.now().toUtc();
    }
    // offset between device clock and server clock at load
    final skew = DateTime.now().toUtc().difference(base);
    _tick(endsAt, skew);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick(endsAt, skew));
  }

  void _tick(DateTime endsAt, Duration skew) {
    final nowServer = DateTime.now().toUtc().subtract(skew);
    final rem = endsAt.difference(nowServer);
    if (!mounted) return;
    setState(() => _remaining = rem.isNegative ? Duration.zero : rem);

    if (!_warned2min &&
        rem.inSeconds <= 120 &&
        rem.inSeconds > 0) {
      _warned2min = true;
      _showTimeWarning();
    }
    if (rem.inSeconds <= 0 && !_submitting) {
      _autoSubmit();
    }
  }

  void _showTimeWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFFB8860B),
        duration: Duration(seconds: 6),
        content: Text('2 minutes left — the exam will submit automatically.'),
      ),
    );
  }

  Future<void> _setAnswer(String linkId, dynamic value) async {
    setState(() => _answers[linkId] = value);
    await ExamCache.saveAnswers(widget.attemptId, _answers);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final c in _theoryControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  int get _answeredCount =>
      _questions.where((q) => _isAnswered(q)).length;

  bool _isAnswered(dynamic q) {
    final id = '${q['link_id']}';
    final a = _answers[id];
    if (a == null) return false;
    if (a is String) return a.trim().isNotEmpty;
    if (a is List) return a.isNotEmpty;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_examTitle)),
        body: const Center(child: Text('This exam has no questions.')),
      );
    }
    final q = _questions[_index];
    final low = _remaining.inSeconds <= 120;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Branding.primaryColor,
          foregroundColor: Colors.white,
          title: Text('Q${_index + 1} of ${_questions.length}'),
          actions: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: low ? Colors.red.shade700 : Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  const Icon(Icons.timer, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(_fmt(_remaining),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                ]),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            LinearProgressIndicator(
              value: (_index + 1) / _questions.length,
              backgroundColor: Colors.grey.shade200,
              color: Branding.primaryColor,
            ),
            Expanded(child: _questionBody(q)),
            _navBar(),
          ],
        ),
      ),
    );
  }

  Widget _questionBody(dynamic q) {
    final id = '${q['link_id']}';
    final type = (q['type'] as String?) ?? 'mcq';
    final marks = q['marks'];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Branding.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$marks mark${marks == 1 ? '' : 's'}',
                style: TextStyle(
                    color: Branding.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
          if (_isAnswered(q))
            Row(children: [
              Icon(Icons.check_circle, size: 16, color: Branding.successColor),
              const SizedBox(width: 4),
              Text('Answered',
                  style: TextStyle(color: Branding.successColor, fontSize: 12)),
            ]),
        ]),
        const SizedBox(height: 12),
        Text(
          _stripHtml((q['question_html'] as String?) ?? ''),
          style: const TextStyle(fontSize: 17, height: 1.4),
        ),
        const SizedBox(height: 20),
        ..._options(q, id, type),
      ],
    );
  }

  List<Widget> _options(dynamic q, String id, String type) {
    if (type == 'theory') {
      final ctrl = _theoryControllers.putIfAbsent(
        id,
        () => TextEditingController(text: (_answers[id] as String?) ?? ''),
      );
      return [
        TextField(
          minLines: 4,
          maxLines: 10,
          controller: ctrl,
          decoration: InputDecoration(
            hintText: 'Type your answer…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (v) => _setAnswer(id, v),
        ),
      ];
    }

    final options = (q['options'] as List?) ?? const [];
    final multi = type == 'multi';
    final current = _answers[id];

    return options.map<Widget>((opt) {
      final idx = (opt['idx'] as num).toInt();
      final text = _stripHtml((opt['html'] as String?) ?? '');
      final bool selected = multi
          ? (current is List && current.contains(idx))
          : (current == idx);

      return Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? Branding.primaryColor : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (multi) {
              final list = (current is List ? List.from(current) : <dynamic>[]);
              if (list.contains(idx)) {
                list.remove(idx);
              } else {
                list.add(idx);
              }
              _setAnswer(id, list);
            } else {
              _setAnswer(id, idx);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(
                multi
                    ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
                    : (selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked),
                color: selected ? Branding.primaryColor : Colors.grey.shade400,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
            ]),
          ),
        ),
      );
    }).toList();
  }

  Widget _navBar() {
    final isLast = _index == _questions.length - 1;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
      ),
      child: Row(children: [
        if (_index > 0)
          OutlinedButton.icon(
            onPressed: () => setState(() => _index--),
            icon: const Icon(Icons.chevron_left),
            label: const Text('Previous'),
          ),
        const Spacer(),
        Text('$_answeredCount / ${_questions.length} answered',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const Spacer(),
        if (!isLast)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Branding.primaryColor),
            onPressed: () => setState(() => _index++),
            icon: const Icon(Icons.chevron_right),
            label: const Text('Next'),
          )
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Branding.successColor),
            onPressed: _submitting ? null : _confirmSubmit,
            icon: const Icon(Icons.check),
            label: const Text('Submit'),
          ),
      ]),
    );
  }

  Future<void> _confirmSubmit() async {
    final unanswered = _questions.length - _answeredCount;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit exam?'),
        content: Text(unanswered == 0
            ? 'All questions answered. Submit your exam?'
            : 'You have $unanswered unanswered question(s). Submit anyway?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep working')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (yes == true) _submit(auto: false);
  }

  Future<void> _autoSubmit() async {
    _ticker?.cancel();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Time's up — submitting your exam."),
      ));
    }
    _submit(auto: true);
  }

  Future<void> _submit({required bool auto}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    _ticker?.cancel();

    // Build the wire payload the server expects: an ARRAY of answer objects,
    // each with link_id and the field matching its type:
    //   single-choice/boolean -> selected_original_idx (int)
    //   multi-choice           -> selected_original_idxs (int list)
    //   theory                 -> answer_text (string)
    final answerList = <Map<String, dynamic>>[];
    for (final q in _questions) {
      final linkId = (q['link_id'] as num).toInt();
      final type = (q['type'] as String?) ?? 'mcq';
      final a = _answers['$linkId'];
      if (a == null) continue;
      final item = <String, dynamic>{'link_id': linkId};
      if (type == 'theory') {
        if (a is String && a.trim().isNotEmpty) {
          item['answer_text'] = a;
        } else {
          continue;
        }
      } else if (type == 'multi') {
        if (a is List && a.isNotEmpty) {
          item['selected_original_idxs'] = a.map((e) => e as int).toList();
        } else {
          continue;
        }
      } else {
        // mcq / boolean -> single index
        if (a is int) {
          item['selected_original_idx'] = a;
        } else {
          continue;
        }
      }
      answerList.add(item);
    }
    final payload = {
      'answers': answerList,
      'auto_submitted': auto,
    };

    final res = await widget.api
        .post('/cbt/attempts/${widget.attemptId}/submit', body: payload);

    if (res.success) {
      await ExamCache.purge(widget.attemptId);
      if (!mounted) return;
      _showDone(online: true, data: res.data);
    } else {
      // offline or failed: queue for sync, keep answers safe
      await ExamCache.queueSubmit(widget.attemptId);
      await ExamCache.saveMeta(widget.attemptId, {
        'submitted_locally': true,
        'exam_title': _examTitle,
        'auto': auto,
      });
      if (!mounted) return;
      _showDone(online: false, data: null);
    }
  }

  void _showDone({required bool online, Map<String, dynamic>? data}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(online ? 'Submitted' : 'Saved offline'),
        content: Text(online
            ? 'Your exam has been submitted successfully.'
            : 'No connection right now — your answers are saved and will sync '
                'automatically when you are back online.'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx); // dialog
              Navigator.pop(context); // take screen -> back to list
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLeave() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave the exam?'),
        content: const Text(
            'Your answers are saved. The timer keeps running while you are away, '
            'and the exam will submit automatically when time is up.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );
    if (yes == true && mounted) Navigator.pop(context);
  }

  /// Minimal HTML-to-text so question/option HTML renders cleanly.
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }
}
