import 'package:flutter/material.dart';
import '../../config/branding.dart';
import '../../core/api_client.dart';
import 'cbt_exam_questions_screen.dart';

/// CBT Exams management — list (status-grouped), create/edit, publish/close/archive.
/// Endpoints: /cbt/manage/meta, /cbt/manage/exams (+/{id}, publish, close, archive).
class CbtExamsScreen extends StatefulWidget {
  const CbtExamsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<CbtExamsScreen> createState() => _CbtExamsScreenState();
}

class _CbtExamsScreenState extends State<CbtExamsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _classes = const [];
  List<dynamic> _subjects = const [];
  List<dynamic> _terms = const [];
  List<dynamic> _exams = const [];
  int? _classFilter;
  String _statusFilter = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() { _loading = true; _error = null; });
    final meta = await widget.api.get('/cbt/manage/meta');
    if (!mounted) return;
    if (!meta.success) {
      setState(() { _loading = false; _error = meta.friendlyError; });
      return;
    }
    _classes = (meta.data['classes'] as List?) ?? const [];
    _subjects = (meta.data['subjects'] as List?) ?? const [];
    _terms = (meta.data['terms'] as List?) ?? const [];
    await _loadExams();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadExams() async {
    var path = '/cbt/manage/exams';
    final q = <String>[];
    if (_classFilter != null) q.add('class_id=$_classFilter');
    if (_statusFilter.isNotEmpty) q.add('status=$_statusFilter');
    if (q.isNotEmpty) path += '?${q.join('&')}';
    final res = await widget.api.get(path);
    if (!mounted) return;
    setState(() {
      if (res.success) {
        _exams = (res.data['exams'] as List?) ?? const [];
      } else {
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

    final grouped = <String, List<dynamic>>{};
    for (final e in _exams) {
      grouped.putIfAbsent('${e['status']}', () => []).add(e);
    }
    const order = ['draft', 'published', 'closed', 'archived'];

    return Stack(children: [
      RefreshIndicator(
        onRefresh: () async { await _loadExams(); },
        child: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 80), children: [
          // filters
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                value: _classFilter,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Class',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All classes')),
                  ..._classes.map<DropdownMenuItem<int?>>((c) => DropdownMenuItem(
                        value: (c['id'] as num).toInt(),
                        child: Text('${c['name']}', overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (v) { setState(() => _classFilter = v); _loadExams(); },
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [
            for (final s in ['', 'draft', 'published', 'closed'])
              ChoiceChip(
                label: Text(s.isEmpty ? 'All' : s[0].toUpperCase() + s.substring(1),
                    style: const TextStyle(fontSize: 12)),
                selected: _statusFilter == s,
                onSelected: (_) { setState(() => _statusFilter = s); _loadExams(); },
              ),
          ]),
          const SizedBox(height: 8),
          if (_exams.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 50),
              child: Center(child: Text('No exams match these filters.',
                  style: TextStyle(color: Colors.grey.shade600))),
            ),
          for (final st in order)
            if (grouped.containsKey(st)) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Text(st.toUpperCase(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        letterSpacing: 0.6, color: Colors.grey.shade600)),
              ),
              ...grouped[st]!.map(_examCard),
            ],
        ]),
      ),
      Positioned(
        right: 16, bottom: 16,
        child: FloatingActionButton.extended(
          backgroundColor: Branding.primaryColor,
          foregroundColor: Colors.white,
          onPressed: () => _openForm(null),
          icon: const Icon(Icons.add),
          label: const Text('New exam'),
        ),
      ),
    ]);
  }

  Color _statusColor(String s) => switch (s) {
        'published' => Branding.successColor,
        'draft' => const Color(0xFFB8860B),
        'closed' => Colors.grey.shade600,
        _ => Colors.grey.shade400,
      };

  Widget _examCard(dynamic e) {
    final status = '${e['status']}';
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(e),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${e['title']}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(status,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700,
                        color: _statusColor(status))),
              ),
            ]),
            const SizedBox(height: 2),
            Text('${e['subject_name'] ?? ''} · ${e['class_name'] ?? ''} · ${e['term_name'] ?? ''} ${e['session_name'] ?? ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            Wrap(spacing: 10, children: [
              _fact(Icons.help_outline, '${e['question_count'] ?? 0} questions'),
              _fact(Icons.timer_outlined, '${e['duration_minutes']} min'),
              _fact(Icons.grade_outlined, '${e['total_marks']} marks'),
              _fact(Icons.people_outline, '${e['attempt_count'] ?? 0} attempts'),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _fact(IconData i, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 3),
        Text(t, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
      ]);

  void _openDetail(dynamic e) {
    final status = '${e['status']}';
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${e['title']}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('${e['subject_name']} · ${e['class_name']} · ${e['term_name']} ${e['session_name']}',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            const SizedBox(height: 10),
            Text('${e['question_count'] ?? 0} question(s) · ${e['duration_minutes']} min · '
                '${e['total_marks']} marks · pass ${e['pass_mark'] ?? '—'} · '
                'max ${e['max_attempts']} attempt(s)',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Branding.primaryColor,
                    foregroundColor: Colors.white),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => CbtExamQuestionsScreen(
                          api: widget.api, exam: e)));
                  _loadExams();
                },
                icon: const Icon(Icons.help_outline, size: 17),
                label: const Text('Questions'),
              ),
              OutlinedButton.icon(
                onPressed: () { Navigator.pop(ctx); _openForm(e); },
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Edit'),
              ),
              if (status == 'draft' || status == 'closed')
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Branding.successColor,
                      foregroundColor: Colors.white),
                  onPressed: () { Navigator.pop(ctx); _lifecycle(e, 'publish'); },
                  icon: const Icon(Icons.publish_outlined, size: 17),
                  label: Text(status == 'closed' ? 'Reopen (publish)' : 'Publish'),
                ),
              if (status == 'published')
                OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _lifecycle(e, 'close'); },
                  icon: const Icon(Icons.stop_circle_outlined, size: 17),
                  label: const Text('Close'),
                ),
              if (status != 'archived')
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                  onPressed: () { Navigator.pop(ctx); _lifecycle(e, 'archive'); },
                  icon: const Icon(Icons.archive_outlined, size: 17),
                  label: const Text('Archive'),
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _lifecycle(dynamic e, String action) async {
    final msgs = {
      'publish': 'Publish this exam so students can take it?',
      'close': 'Close this exam? Students can no longer start it.',
      'archive': 'Archive this exam? It disappears from normal lists.',
    };
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${e['title']}'),
        content: Text(msgs[action] ?? action),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    final res = await widget.api.post('/cbt/manage/exams/${e['id']}/$action', body: {});
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.success
            ? 'Done — exam ${action}d.'
            : res.friendlyError)));
    if (res.success) _loadExams();
  }

  Future<void> _openForm(dynamic existing) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ExamFormScreen(
          api: widget.api,
          classes: _classes,
          subjects: _subjects,
          terms: _terms,
          existing: existing,
        ),
      ),
    );
    if (saved == true) _loadExams();
  }
}

/// Create / edit an exam — mirrors the portal form fields and defaults.
class _ExamFormScreen extends StatefulWidget {
  const _ExamFormScreen({required this.api, required this.classes,
      required this.subjects, required this.terms, this.existing});
  final ApiClient api;
  final List<dynamic> classes;
  final List<dynamic> subjects;
  final List<dynamic> terms;
  final dynamic existing;

  @override
  State<_ExamFormScreen> createState() => _ExamFormScreenState();
}

class _ExamFormScreenState extends State<_ExamFormScreen> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _instr;
  late final TextEditingController _duration;
  late final TextEditingController _marks;
  late final TextEditingController _pass;
  late final TextEditingController _attempts;
  late final TextEditingController _password;
  int? _classId;
  int? _subjectId;
  int? _termId;
  bool _randQ = false, _randO = false, _showNow = true, _showAns = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?['title'] ?? '');
    _desc = TextEditingController(text: e?['description'] ?? '');
    _instr = TextEditingController(text: e?['instructions'] ?? '');
    _duration = TextEditingController(text: '${e?['duration_minutes'] ?? 60}');
    _marks = TextEditingController(text: '${e?['total_marks'] ?? 100}');
    _pass = TextEditingController(text: '${e?['pass_mark'] ?? 50}');
    _attempts = TextEditingController(text: '${e?['max_attempts'] ?? 1}');
    _password = TextEditingController();
    if (e != null) {
      _classId = (e['class_id'] as num?)?.toInt();
      _subjectId = (e['subject_id'] as num?)?.toInt();
      _termId = (e['term_id'] as num?)?.toInt();
      _randQ = e['randomize_questions'] == true;
      _randO = e['randomize_options'] == true;
      _showNow = e['show_result_immediately'] == true;
      _showAns = e['show_correct_answers'] == true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Branding.primaryColor,
        foregroundColor: Colors.white,
        title: Text(isEdit ? 'Edit exam' : 'New exam'),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _field(_title, 'Exam title *'),
        DropdownButtonFormField<int>(
          value: _classId,
          isExpanded: true,
          decoration: _dec('Class *'),
          items: widget.classes.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(
                value: (c['id'] as num).toInt(),
                child: Text('${c['name']} (${c['level_name']})',
                    overflow: TextOverflow.ellipsis),
              )).toList(),
          onChanged: (v) => setState(() => _classId = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: _subjectId,
          isExpanded: true,
          decoration: _dec('Subject *'),
          items: widget.subjects.map<DropdownMenuItem<int>>((s) => DropdownMenuItem(
                value: (s['id'] as num).toInt(),
                child: Text('${s['name']}', overflow: TextOverflow.ellipsis),
              )).toList(),
          onChanged: (v) => setState(() => _subjectId = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: _termId,
          isExpanded: true,
          decoration: _dec('Term *'),
          items: widget.terms.map<DropdownMenuItem<int>>((t) => DropdownMenuItem(
                value: (t['id'] as num).toInt(),
                child: Text('${t['name']} — ${t['session_name'] ?? ''}',
                    overflow: TextOverflow.ellipsis),
              )).toList(),
          onChanged: (v) => setState(() => _termId = v),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _field(_duration, 'Duration (min)', number: true)),
          const SizedBox(width: 10),
          Expanded(child: _field(_attempts, 'Max attempts', number: true)),
        ]),
        Row(children: [
          Expanded(child: _field(_marks, 'Total marks', number: true)),
          const SizedBox(width: 10),
          Expanded(child: _field(_pass, 'Pass mark', number: true)),
        ]),
        _field(_desc, 'Description (optional)', lines: 2),
        _field(_instr, 'Instructions shown to students', lines: 3),
        _field(_password, isEdit
            ? 'Exam password (leave empty to remove)'
            : 'Exam password (optional)'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _randQ,
          onChanged: (v) => setState(() => _randQ = v),
          title: const Text('Randomize question order', style: TextStyle(fontSize: 14)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _randO,
          onChanged: (v) => setState(() => _randO = v),
          title: const Text('Randomize option order', style: TextStyle(fontSize: 14)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _showNow,
          onChanged: (v) => setState(() => _showNow = v),
          title: const Text('Show result immediately after submit',
              style: TextStyle(fontSize: 14)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _showAns,
          onChanged: (v) => setState(() => _showAns = v),
          title: const Text('Show correct answers in review',
              style: TextStyle(fontSize: 14)),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Branding.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : (isEdit ? 'Save changes' : 'Create draft exam'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        if (!isEdit)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('New exams start as drafts. Add questions on the web (or in the next build), then Publish.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
          ),
      ]),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  Widget _field(TextEditingController c, String label,
      {bool number = false, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: lines,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: _dec(label),
      ),
    );
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _classId == null ||
        _subjectId == null || _termId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Title, class, subject and term are required.')));
      return;
    }
    setState(() => _saving = true);
    final body = {
      'title': _title.text.trim(),
      'description': _desc.text.trim(),
      'instructions': _instr.text.trim(),
      'class_id': _classId,
      'subject_id': _subjectId,
      'term_id': _termId,
      'duration_minutes': int.tryParse(_duration.text) ?? 60,
      'total_marks': double.tryParse(_marks.text) ?? 100,
      'pass_mark': double.tryParse(_pass.text) ?? 50,
      'max_attempts': int.tryParse(_attempts.text) ?? 1,
      'randomize_questions': _randQ,
      'randomize_options': _randO,
      'show_result_immediately': _showNow,
      'show_correct_answers': _showAns,
      if (_password.text.trim().isNotEmpty) 'exam_password': _password.text.trim(),
    };
    final isEdit = widget.existing != null;
    final res = isEdit
        ? await widget.api.put('/cbt/manage/exams/${widget.existing['id']}', body: body)
        : await widget.api.post('/cbt/manage/exams', body: body);
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.friendlyError)));
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _desc, _instr, _duration, _marks, _pass, _attempts, _password]) {
      c.dispose();
    }
    super.dispose();
  }
}
