import 'dart:async';
import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';
import '../core/exam_cache.dart';

/// Feature 3+4 — the portal-style exam player.
/// Mirrors the web portal: an instructions page first, then the exam with a
/// question-number grid (answered / flagged states), lettered options,
/// flag-for-review, an always-visible Submit, autosave, a server-synced
/// countdown with a 2-minute warning, and auto-submit at zero.
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
  List<dynamic> _questions = const [];
  Map<String, dynamic> _answers = {};
  final Set<String> _flagged = {};
  final Map<String, TextEditingController> _theoryControllers = {};

  int _index = 0;
  bool _started = false; // instructions page until they press Start

  Timer? _ticker;
  Duration _remaining = Duration.zero;
  bool _warned2min = false;
  bool _submitting = false;
  DateTime? _lastSaved;

  String _examTitle = 'Exam';
  int _durationMinutes = 0;

  @override
  void initState() {
    super.initState();
    final pkg = widget.package;
    final exam = (pkg['exam'] as Map?) ?? const {};
    _examTitle = (exam['title'] as String?) ?? 'Exam';
    _durationMinutes = (exam['duration_minutes'] as num?)?.toInt() ?? 0;
    _questions = (pkg['questions'] as List?) ?? const [];
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final cached = await ExamCache.loadAnswers(widget.attemptId);
    _answers.addAll(cached);
    if (mounted) setState(() {});
  }

  /* ------------------------------ timer ------------------------------ */

  void _startTimer() {
    final attempt = (widget.package['attempt'] as Map?) ?? const {};
    final endsAtStr = attempt['deadline'] as String?;
    final serverNowStr = attempt['server_now'] as String?;
    DateTime endsAt;
    DateTime base;
    try {
      endsAt = DateTime.parse(endsAtStr!).toUtc();
      base = serverNowStr != null
          ? DateTime.parse(serverNowStr).toUtc()
          : DateTime.now().toUtc();
    } catch (_) {
      final secs = (attempt['remaining_seconds'] as num?)?.toInt() ?? 1800;
      endsAt = DateTime.now().toUtc().add(Duration(seconds: secs));
      base = DateTime.now().toUtc();
    }
    final skew = DateTime.now().toUtc().difference(base);
    _tick(endsAt, skew);
    _ticker =
        Timer.periodic(const Duration(seconds: 1), (_) => _tick(endsAt, skew));
  }

  void _tick(DateTime endsAt, Duration skew) {
    final nowServer = DateTime.now().toUtc().subtract(skew);
    final rem = endsAt.difference(nowServer);
    if (!mounted) return;
    setState(() => _remaining = rem.isNegative ? Duration.zero : rem);
    if (!_warned2min && rem.inSeconds <= 120 && rem.inSeconds > 0) {
      _warned2min = true;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: Color(0xFFB8860B),
        duration: Duration(seconds: 6),
        content: Text('2 minutes left — the exam will submit automatically.'),
      ));
    }
    if (rem.inSeconds <= 0 && !_submitting && _started) {
      _submit(auto: true);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  /* ----------------------------- answers ----------------------------- */

  Future<void> _setAnswer(String linkId, dynamic value) async {
    setState(() => _answers[linkId] = value);
    await ExamCache.saveAnswers(widget.attemptId, _answers);
    if (mounted) setState(() => _lastSaved = DateTime.now());
  }

  bool _isAnswered(dynamic q) {
    final a = _answers['${q['link_id']}'];
    if (a == null) return false;
    if (a is String) return a.trim().isNotEmpty;
    if (a is List) return a.isNotEmpty;
    return true;
  }

  int get _answeredCount => _questions.where(_isAnswered).length;

  bool _isTheory(String t) => t == 'theory' || t == 'essay';
  bool _isMulti(String t) =>
      t == 'multi' || t == 'multiple_response' || t == 'multiple_select';

  String _typeLabel(String t) {
    if (_isTheory(t)) return 'theory';
    if (_isMulti(t)) return 'multiple response';
    if (t == 'true_false' || t == 'boolean') return 'true / false';
    return 'multiple choice';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final c in _theoryControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /* ------------------------------ build ------------------------------ */

  @override
  Widget build(BuildContext context) {
    if (!_started) return _instructionsPage();
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_examTitle)),
        body: const Center(child: Text('This exam has no questions.')),
      );
    }
    final low = _remaining.inSeconds <= 120;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Branding.primaryColor,
          foregroundColor: Colors.white,
          titleSpacing: 12,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_examTitle,
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis),
              Text(
                _lastSaved == null ? '' : 'All changes saved.',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: low ? Colors.red.shade700 : Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_fmt(_remaining),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              _questionGridCard(),
              const SizedBox(height: 12),
              _questionCard(_questions[_index]),
            ],
          ),
        ),
      ),
    );
  }

  /* ----------------------- instructions page ------------------------ */

  Widget _instructionsPage() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Branding.primaryColor,
        foregroundColor: Colors.white,
        title: Text(_examTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Before you begin',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _rule('You have $_durationMinutes minutes once the timer starts.'),
            _rule('You can navigate freely between questions and flag any to review later.'),
            _rule('Your answers are saved automatically after every change.'),
            _rule('The exam auto-submits when the timer reaches zero.'),
            _rule('Once you submit, you cannot retake unless attempts remain.'),
            _rule('If you lose connection, keep going — everything is saved on this phone and will sync when you are back online.'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Branding.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  setState(() => _started = true);
                  _startTimer();
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Exam'),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Make sure you have $_durationMinutes uninterrupted minutes before starting.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rule(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('•  '),
        Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
      ]),
    );
  }

  /* ------------------------ question grid card ----------------------- */

  Widget _questionGridCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Questions',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('$_answeredCount/${_questions.length}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_questions.length, (i) {
              final q = _questions[i];
              final id = '${q['link_id']}';
              final answered = _isAnswered(q);
              final flagged = _flagged.contains(id);
              final current = i == _index;
              Color bg;
              Color fg;
              if (current) {
                bg = Branding.primaryColor;
                fg = Colors.white;
              } else if (flagged) {
                bg = const Color(0xFFFFF4D6);
                fg = const Color(0xFF8A6D00);
              } else if (answered) {
                bg = const Color(0xFFE2F3E9);
                fg = const Color(0xFF14683A);
              } else {
                bg = Colors.white;
                fg = Colors.black87;
              }
              return InkWell(
                onTap: () => setState(() => _index = i),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 42,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            current ? Branding.primaryColor : Colors.grey.shade300),
                  ),
                  child: Text('${i + 1}',
                      style:
                          TextStyle(color: fg, fontWeight: FontWeight.w600)),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Row(children: [
            _legend(const Color(0xFFE2F3E9), 'Answered'),
            const SizedBox(width: 14),
            _legend(const Color(0xFFFFF4D6), 'Flagged for review'),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Branding.successColor),
              onPressed: _submitting ? null : _confirmSubmit,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Submit Exam'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _legend(Color c, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.grey.shade300))),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
    ]);
  }

  /* -------------------------- question card -------------------------- */

  Widget _questionCard(dynamic q) {
    final id = '${q['link_id']}';
    final type = (q['type'] as String?) ?? 'mcq';
    final marks = q['marks'];
    final flagged = _flagged.contains(id);
    final isLast = _index == _questions.length - 1;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'Question ${_index + 1} of ${_questions.length} · ${_typeLabel(type)} · $marks mark${marks == 1 ? '' : 's'}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Text(_stripHtml((q['text'] as String?) ?? ''),
              style: const TextStyle(fontSize: 17, height: 1.4)),
          const SizedBox(height: 16),
          ..._options(q, id, type),
          const SizedBox(height: 14),
          Row(children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    flagged ? const Color(0xFF8A6D00) : Colors.grey.shade700,
                side: BorderSide(
                    color: flagged
                        ? const Color(0xFFE0B93F)
                        : Colors.grey.shade300),
              ),
              onPressed: () => setState(() {
                flagged ? _flagged.remove(id) : _flagged.add(id);
              }),
              icon: Icon(flagged ? Icons.flag : Icons.outlined_flag, size: 18),
              label: Text(flagged ? 'Flagged' : 'Flag for review'),
            ),
            const Spacer(),
            if (_index > 0)
              IconButton.outlined(
                onPressed: () => setState(() => _index--),
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous',
              ),
            const SizedBox(width: 8),
            if (!isLast)
              FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: Branding.primaryColor),
                onPressed: () => setState(() => _index++),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Next'),
                  Icon(Icons.chevron_right, size: 18),
                ]),
              ),
          ]),
        ]),
      ),
    );
  }

  List<Widget> _options(dynamic q, String id, String type) {
    if (_isTheory(type)) {
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
    final multi = _isMulti(type);
    final current = _answers[id];
    const letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

    final widgets = <Widget>[];
    for (var i = 0; i < options.length; i++) {
      final opt = options[i];
      final idx = (opt['original_idx'] as num).toInt();
      final text = _stripHtml((opt['text'] as String?) ?? '');
      final letter = i < letters.length ? letters[i] : '${i + 1}';
      final bool selected = multi
          ? (current is List && current.contains(idx))
          : (current == idx);

      widgets.add(Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? Branding.primaryColor : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (multi) {
              final list = (current is List ? List.from(current) : <dynamic>[]);
              list.contains(idx) ? list.remove(idx) : list.add(idx);
              _setAnswer(id, list);
            } else {
              _setAnswer(id, idx);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              Icon(
                multi
                    ? (selected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank)
                    : (selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked),
                size: 20,
                color: selected ? Branding.primaryColor : Colors.grey.shade400,
              ),
              const SizedBox(width: 10),
              Text('$letter.',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Branding.primaryColor
                          : Colors.grey.shade700)),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
            ]),
          ),
        ),
      ));
    }
    return widgets;
  }

  /* ------------------------------ submit ----------------------------- */

  Future<void> _confirmSubmit() async {
    final unanswered = _questions.length - _answeredCount;
    final flaggedCount = _flagged.length;
    final parts = <String>[];
    if (unanswered > 0) parts.add('$unanswered unanswered');
    if (flaggedCount > 0) parts.add('$flaggedCount flagged for review');
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit exam?'),
        content: Text(parts.isEmpty
            ? 'All questions answered. Submit your exam?'
            : 'You have ${parts.join(' and ')}. Submit anyway?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep working')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit')),
        ],
      ),
    );
    if (yes == true) _submit(auto: false);
  }

  Future<void> _submit({required bool auto}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    _ticker?.cancel();

    final answerList = <Map<String, dynamic>>[];
    for (final q in _questions) {
      final linkId = (q['link_id'] as num).toInt();
      final type = (q['type'] as String?) ?? 'mcq';
      final a = _answers['$linkId'];
      if (a == null) continue;
      final item = <String, dynamic>{'link_id': linkId};
      if (_isTheory(type)) {
        if (a is String && a.trim().isNotEmpty) {
          item['answer_text'] = a;
        } else {
          continue;
        }
      } else if (_isMulti(type)) {
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
      answerList.add(item);
    }

    final res = await widget.api.post(
      '/cbt/attempts/${widget.attemptId}/submit',
      body: {'answers': answerList, 'auto_submitted': auto},
    );

    if (res.success) {
      await ExamCache.purge(widget.attemptId);
      if (!mounted) return;
      _showDone(online: true);
    } else {
      await ExamCache.queueSubmit(widget.attemptId);
      await ExamCache.saveMeta(widget.attemptId, {
        'submitted_locally': true,
        'exam_title': _examTitle,
        'auto': auto,
      });
      if (!mounted) return;
      _showDone(online: false);
    }
  }

  void _showDone({required bool online}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(online ? 'Submitted' : 'Saved — will sync'),
        content: Text(online
            ? 'Your exam has been submitted successfully.'
            : 'You appear to be offline. Your answers are safely stored on '
                'this phone and will be submitted automatically the next time '
                'the app opens with a connection.'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
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
            'Your answers are saved. The timer keeps running while you are '
            'away, and the exam will submit automatically when time is up.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Stay')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Leave')),
        ],
      ),
    );
    if (yes == true && mounted) Navigator.pop(context);
  }

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
