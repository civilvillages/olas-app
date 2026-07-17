import 'package:flutter/material.dart';
import '../../config/branding.dart';
import '../../core/api_client.dart';

/// Theory Marking — pick an exam, see attempts (pending-first), mark each
/// student's theory/essay answers with per-question marks. Mirrors the portal.
class CbtTheoryScreen extends StatefulWidget {
  const CbtTheoryScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<CbtTheoryScreen> createState() => _CbtTheoryScreenState();
}

class _CbtTheoryScreenState extends State<CbtTheoryScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _exams = const [];
  dynamic _exam;
  List<dynamic> _attempts = const [];
  int _needMarking = 0;
  bool _attemptsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() { _loading = true; _error = null; });
    final res = await widget.api.get('/cbt/manage/exams');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        _exams = (res.data['exams'] as List?) ?? const [];
      } else {
        _error = res.friendlyError;
      }
    });
  }

  Future<void> _openExam(dynamic e) async {
    setState(() { _exam = e; _attemptsLoading = true; _attempts = const []; });
    final res = await widget.api.get('/cbt/manage/exams/${e['id']}/attempts');
    if (!mounted) return;
    setState(() {
      _attemptsLoading = false;
      if (res.success) {
        _attempts = (res.data['attempts'] as List?) ?? const [];
        _needMarking = (res.meta['need_marking'] as num?)?.toInt() ?? 0;
        // pending first
        _attempts = [..._attempts]..sort((a, b) =>
            ((b['pending_theory'] as num?) ?? 0).compareTo((a['pending_theory'] as num?) ?? 0));
      } else {
        _exam = null;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res.friendlyError)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline, size: 44, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(_error!, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
        ]),
      ));
    }
    if (_exam == null) return _examPicker();
    return _attemptList();
  }

  Widget _examPicker() {
    return ListView(padding: const EdgeInsets.all(14), children: [
      Text('PICK AN EXAM TO MARK',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              letterSpacing: 0.5, color: Colors.grey.shade600)),
      const SizedBox(height: 4),
      if (_exams.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text('No exams in your scope yet.',
              style: TextStyle(color: Colors.grey.shade600))),
        ),
      ..._exams.map((e) => Card(
            margin: const EdgeInsets.only(top: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              title: Text('${e['title']}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: Text(
                  '${e['subject_name']} · ${e['class_name']} · ${e['attempt_count'] ?? 0} attempt(s)',
                  style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openExam(e),
            ),
          )),
    ]);
  }

  Widget _attemptList() {
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Branding.primaryColor.withOpacity(0.06),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_exam['title']}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(_needMarking > 0
                    ? '$_needMarking attempt(s) still need marking'
                    : 'All attempts marked',
                style: TextStyle(fontSize: 12,
                    color: _needMarking > 0
                        ? const Color(0xFF8A6D00) : Branding.successColor)),
          ])),
          TextButton(onPressed: () => setState(() => _exam = null),
              child: const Text('Change')),
        ]),
      ),
      Expanded(
        child: _attemptsLoading
            ? const Center(child: CircularProgressIndicator())
            : _attempts.isEmpty
                ? Center(child: Text('No attempts yet for this exam.',
                    style: TextStyle(color: Colors.grey.shade600)))
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _attempts.length,
                    itemBuilder: (ctx, i) => _attemptCard(_attempts[i]),
                  ),
      ),
    ]);
  }

  Widget _attemptCard(dynamic a) {
    final pending = (a['pending_theory'] as num?)?.toInt() ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        title: Text('${a['student']}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(
            '${a['admission_number'] ?? ''} · score ${a['score'] ?? '—'} · ${a['review_status'] ?? a['status']}',
            style: const TextStyle(fontSize: 12)),
        trailing: pending > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4D6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$pending to mark',
                    style: const TextStyle(fontSize: 11.5,
                        fontWeight: FontWeight.w700, color: Color(0xFF8A6D00))),
              )
            : Icon(Icons.check_circle, color: Branding.successColor, size: 22),
        onTap: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => _GradeScreen(
                api: widget.api,
                examId: (_exam['id'] as num).toInt(),
                attemptId: (a['attempt_id'] as num).toInt())),
          );
          if (changed == true) _openExam(_exam);
        },
      ),
    );
  }
}

/// Mark one attempt: each theory/essay question with the student's answer
/// and a marks field capped at the question's maximum.
class _GradeScreen extends StatefulWidget {
  const _GradeScreen({required this.api, required this.examId, required this.attemptId});
  final ApiClient api;
  final int examId;
  final int attemptId;

  @override
  State<_GradeScreen> createState() => _GradeScreenState();
}

class _GradeScreenState extends State<_GradeScreen> {
  bool _loading = true;
  Map<String, dynamic> _d = const {};
  final Map<int, TextEditingController> _ctls = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await widget.api.get(
        '/cbt/manage/exams/${widget.examId}/attempts/${widget.attemptId}/grade');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        _d = res.data;
        for (final it in (_d['items'] as List? ?? const [])) {
          final lid = (it['link_id'] as num).toInt();
          final v = it['marks_awarded'];
          _ctls[lid] = TextEditingController(
              text: v == null ? '' : '${(v as num) == v.roundToDouble() ? v.toInt() : v}');
        }
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res.friendlyError)));
        Navigator.pop(context, false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final student = (_d['student'] as Map?) ?? const {};
    final attempt = (_d['attempt'] as Map?) ?? const {};
    final items = (_d['items'] as List?) ?? const [];
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Branding.primaryColor,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mark theory answers', style: TextStyle(fontSize: 16)),
          Text('${student['name'] ?? ''} · current score ${attempt['score'] ?? '—'}',
              style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 90), children: [
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 50),
                  child: Center(child: Text('This exam has no theory or essay questions.',
                      style: TextStyle(color: Colors.grey.shade600))),
                ),
              for (var i = 0; i < items.length; i++) _itemCard(items[i], i),
            ]),
      bottomNavigationBar: _loading || items.isEmpty ? null : SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Branding.successColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, size: 20),
            label: const Text('Save marks',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  Widget _itemCard(dynamic it, int i) {
    final lid = (it['link_id'] as num).toInt();
    final max = (it['max_marks'] as num?) ?? 0;
    final answer = it['answer_text'];
    final marked = it['already_marked'] == true;
    final ctl = _ctls[lid]!;
    final v = double.tryParse(ctl.text.trim());
    final over = v != null && v > max.toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Q${i + 1}. ${it['question']}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            if (marked)
              Icon(Icons.check_circle, size: 18, color: Branding.successColor),
          ]),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              answer == null || '$answer'.trim().isEmpty
                  ? '— no answer written —'
                  : '$answer',
              style: TextStyle(fontSize: 13.5,
                  fontStyle: answer == null || '$answer'.trim().isEmpty
                      ? FontStyle.italic : FontStyle.normal,
                  color: answer == null || '$answer'.trim().isEmpty
                      ? Colors.grey.shade500 : null),
            ),
          ),
          if ('${it['marking_guide'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Guide: ${it['marking_guide']}',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 10),
          Row(children: [
            SizedBox(
              width: 120,
              child: TextField(
                controller: ctl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'Marks',
                  errorText: over ? 'Max $max' : null,
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Text('/ $max', style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
          ]),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    final marks = <String, dynamic>{};
    _ctls.forEach((lid, ctl) {
      final t = ctl.text.trim();
      if (t.isNotEmpty) marks['$lid'] = t;
    });
    if (marks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter marks for at least one answer.')));
      return;
    }
    setState(() => _saving = true);
    final res = await widget.api.post(
        '/cbt/manage/exams/${widget.examId}/attempts/${widget.attemptId}/grade',
        body: {'marks': marks});
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.success) {
      final score = res.data['score'];
      final delta = res.data['delta'];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Saved. Score adjusted by $delta — new total $score.')));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.friendlyError)));
    }
  }

  @override
  void dispose() {
    for (final c in _ctls.values) {
      c.dispose();
    }
    super.dispose();
  }
}
