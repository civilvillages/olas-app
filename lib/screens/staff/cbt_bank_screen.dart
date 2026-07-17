import 'package:flutter/material.dart';
import '../../config/branding.dart';
import '../../core/api_client.dart';

/// Question Bank — browse by class/subject/bank-term, single add/edit/delete.
/// (Bulk import stays on the web, as agreed.)
class CbtBankScreen extends StatefulWidget {
  const CbtBankScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<CbtBankScreen> createState() => _CbtBankScreenState();
}

class _CbtBankScreenState extends State<CbtBankScreen> {
  bool _metaLoading = true;
  String? _error;
  List<dynamic> _classes = const [];
  List<dynamic> _subjects = const [];
  int? _classId;
  int? _subjectId;
  int _termNumber = 0;

  bool _listLoading = false;
  List<dynamic> _questions = const [];
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final meta = await widget.api.get('/cbt/manage/meta');
    if (!mounted) return;
    setState(() {
      _metaLoading = false;
      if (meta.success) {
        _classes = (meta.data['classes'] as List?) ?? const [];
        _subjects = (meta.data['subjects'] as List?) ?? const [];
      } else {
        _error = meta.friendlyError;
      }
    });
  }

  Future<void> _loadBank() async {
    if (_classId == null || _subjectId == null || _termNumber == 0) return;
    setState(() { _listLoading = true; _questions = const []; });
    final res = await widget.api.get(
        '/cbt/manage/bank?class_id=$_classId&term_number=$_termNumber&subject_id=$_subjectId');
    if (!mounted) return;
    setState(() {
      _listLoading = false;
      if (res.success) {
        _questions = (res.data['questions'] as List?) ?? const [];
        _count = (res.meta['count'] as num?)?.toInt() ?? _questions.length;
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res.friendlyError)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_metaLoading) return const Center(child: CircularProgressIndicator());
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

    final ready = _classId != null && _subjectId != null && _termNumber != 0;
    return Stack(children: [
      ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 80), children: [
      DropdownButtonFormField<int>(
        value: _classId,
        isExpanded: true,
        decoration: _dec('Class'),
        hint: const Text('Select class'),
        items: _classes.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(
              value: (c['id'] as num).toInt(),
              child: Text('${c['name']} (${c['level_name']})',
                  overflow: TextOverflow.ellipsis),
            )).toList(),
        onChanged: (v) { setState(() => _classId = v); _loadBank(); },
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<int>(
        value: _subjectId,
        isExpanded: true,
        decoration: _dec('Subject'),
        hint: const Text('Select subject'),
        items: _subjects.map<DropdownMenuItem<int>>((s) => DropdownMenuItem(
              value: (s['id'] as num).toInt(),
              child: Text('${s['name']}', overflow: TextOverflow.ellipsis),
            )).toList(),
        onChanged: (v) { setState(() => _subjectId = v); _loadBank(); },
      ),
      const SizedBox(height: 10),
      Row(children: [
        const Text('Bank term: ', style: TextStyle(fontSize: 13.5)),
        ...[1, 2, 3].map((t) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ChoiceChip(
                label: Text('Term $t', style: const TextStyle(fontSize: 12)),
                selected: _termNumber == t,
                onSelected: (_) { setState(() => _termNumber = t); _loadBank(); },
              ),
            )),
      ]),
      const SizedBox(height: 6),
      Text('Questions are stored per class, subject and term number, so a bank built once is reusable across sessions.',
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
      const SizedBox(height: 10),

      if (_listLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 50),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_classId != null && _subjectId != null && _termNumber != 0) ...[
        Text('$_count QUESTION(S) IN THIS BANK',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                letterSpacing: 0.5, color: Colors.grey.shade600)),
        if (_questions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(child: Text(
                'Empty bank. Tap + to add your first question.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          ),
        ..._questions.map(_qCard),
      ] else
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text('Pick class, subject and term to browse the bank.',
              style: TextStyle(color: Colors.grey.shade600))),
        ),
      ]),
      if (ready)
        Positioned(
          right: 16, bottom: 16,
          child: FloatingActionButton.extended(
            backgroundColor: Branding.primaryColor,
            foregroundColor: Colors.white,
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            label: const Text('Add question'),
          ),
        ),
    ]);
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  Widget _qCard(dynamic q) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _cardActions(q),
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${q['text']}', maxLines: 3, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: [
            _chip('${q['type']}'.replaceAll('_', ' '), Branding.primaryColor),
            _chip('${q['marks']} marks', const Color(0xFFB8860B)),
            _chip('${q['difficulty']}', Colors.grey.shade600),
            if ((q['option_count'] as num? ?? 0) > 0)
              _chip('${q['option_count']} options', Colors.grey.shade600),
          ]),
        ]),
        ),
      ),
    );
  }

  Future<void> _cardActions(dynamic q) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit question'),
            onTap: () => Navigator.pop(ctx, 'edit'),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
            title: Text('Delete question',
                style: TextStyle(color: Colors.red.shade700)),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      final res = await widget.api
          .get('/cbt/manage/bank/${q['question_id']}');
      if (!mounted) return;
      if (!res.success) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res.friendlyError)));
        return;
      }
      _openForm(existing: res.data['question']);
    } else if (action == 'delete') {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete this question?'),
          content: const Text(
              'It disappears from the bank. Exams that already attached it keep their own copy.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete')),
          ],
        ),
      );
      if (yes != true || !mounted) return;
      final res = await widget.api
          .delete('/cbt/manage/bank/${q['question_id']}');
      if (!mounted) return;
      if (res.success) {
        final inExams = (res.data['was_in_exams'] as num?)?.toInt() ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
            inExams > 0
                ? 'Deleted. $inExams exam(s) keep their attached copy.'
                : 'Question deleted.')));
        _loadBank();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res.friendlyError)));
      }
    }
  }

  Future<void> _openForm({dynamic existing}) async {
    if (_classId == null || _subjectId == null || _termNumber == 0) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _BankQuestionFormScreen(
          api: widget.api,
          classId: _classId!,
          subjectId: _subjectId!,
          termNumber: _termNumber,
          className: '${_classes.cast<Map>().firstWhere((c) => c['id'] == _classId, orElse: () => {'name': ''})['name']}',
          subjectName: '${_subjects.cast<Map>().firstWhere((s) => s['id'] == _subjectId, orElse: () => {'name': ''})['name']}',
          existing: existing,
        ),
      ),
    );
    if (saved == true) _loadBank();
  }

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(t, style: TextStyle(fontSize: 10.5, color: c,
            fontWeight: FontWeight.w600)),
      );
}

/// Add / edit one bank question — mirrors the portal form.
class _BankQuestionFormScreen extends StatefulWidget {
  const _BankQuestionFormScreen({required this.api, required this.classId,
      required this.subjectId, required this.termNumber,
      required this.className, required this.subjectName, this.existing});
  final ApiClient api;
  final int classId;
  final int subjectId;
  final int termNumber;
  final String className;
  final String subjectName;
  final dynamic existing;

  @override
  State<_BankQuestionFormScreen> createState() => _BankQuestionFormScreenState();
}

class _BankQuestionFormScreenState extends State<_BankQuestionFormScreen> {
  late final TextEditingController _text;
  late final TextEditingController _marks;
  late final TextEditingController _explanation;
  late final TextEditingController _correctAnswer;
  String _type = 'multiple_choice';
  String _difficulty = 'medium';
  final List<TextEditingController> _optCtls = [];
  final Set<int> _correct = {};
  bool _saving = false;

  static const _types = {
    'multiple_choice': 'Multiple choice (one correct)',
    'multi_select': 'Multi-select (several correct)',
    'true_false': 'True / False',
    'fill_gap': 'Fill the gap',
    'theory': 'Theory (marked by teacher)',
    'essay': 'Essay (marked by teacher)',
  };

  bool get _isChoice =>
      _type == 'multiple_choice' || _type == 'multi_select' || _type == 'true_false';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _text = TextEditingController(text: e?['question_text'] ?? '');
    _marks = TextEditingController(text: '${e?['marks'] ?? 1}');
    _explanation = TextEditingController(text: e?['explanation'] ?? '');
    _correctAnswer = TextEditingController(text: e?['correct_answer'] ?? '');
    if (e != null) {
      _type = '${e['question_type'] ?? 'multiple_choice'}';
      _difficulty = '${e['difficulty'] ?? 'medium'}';
      final opts = (e['options'] as List?) ?? const [];
      for (var i = 0; i < opts.length; i++) {
        _optCtls.add(TextEditingController(text: '${opts[i]['text']}'));
        if (opts[i]['is_correct'] == true) _correct.add(i);
      }
    }
    _ensureOptionRows();
  }

  void _ensureOptionRows() {
    if (_type == 'true_false') {
      while (_optCtls.length < 2) {
        _optCtls.add(TextEditingController());
      }
      while (_optCtls.length > 2) {
        _optCtls.removeLast().dispose();
      }
      if (_optCtls[0].text.isEmpty) _optCtls[0].text = 'True';
      if (_optCtls[1].text.isEmpty) _optCtls[1].text = 'False';
    } else if (_isChoice) {
      while (_optCtls.length < 4) {
        _optCtls.add(TextEditingController());
      }
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
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isEdit ? 'Edit question' : 'Add question',
              style: const TextStyle(fontSize: 16)),
          Text('${widget.subjectName} · ${widget.className} · Term ${widget.termNumber}',
              style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
        ]),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String>(
          value: _type,
          isExpanded: true,
          decoration: _dec('Question type'),
          items: _types.entries.map((e) => DropdownMenuItem(
                value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13.5)),
              )).toList(),
          onChanged: (v) => setState(() {
            _type = v ?? 'multiple_choice';
            _correct.clear();
            _ensureOptionRows();
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _text,
          maxLines: 4,
          decoration: _dec('Question text *'),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(
            controller: _marks,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec('Marks'),
          )),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(
            value: _difficulty,
            decoration: _dec('Difficulty'),
            items: const [
              DropdownMenuItem(value: 'easy', child: Text('Easy')),
              DropdownMenuItem(value: 'medium', child: Text('Medium')),
              DropdownMenuItem(value: 'hard', child: Text('Hard')),
            ],
            onChanged: (v) => setState(() => _difficulty = v ?? 'medium'),
          )),
        ]),
        const SizedBox(height: 12),

        if (_isChoice) ...[
          Text(_type == 'multi_select'
                  ? 'OPTIONS — tick every correct one'
                  : 'OPTIONS — tick the correct one',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  letterSpacing: 0.5, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          for (var i = 0; i < _optCtls.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Checkbox(
                  value: _correct.contains(i),
                  onChanged: (v) => setState(() {
                    if (_type == 'multiple_choice' || _type == 'true_false') {
                      _correct.clear();
                    }
                    if (v == true) {
                      _correct.add(i);
                    } else {
                      _correct.remove(i);
                    }
                  }),
                ),
                Expanded(child: TextField(
                  controller: _optCtls[i],
                  readOnly: _type == 'true_false',
                  decoration: _dec('Option ${String.fromCharCode(65 + i)}'),
                )),
                if (_type != 'true_false')
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
                    onPressed: _optCtls.length <= 2
                        ? null
                        : () => setState(() {
                              _optCtls.removeAt(i).dispose();
                              final nc = <int>{};
                              for (final c in _correct) {
                                if (c < i) nc.add(c);
                                if (c > i) nc.add(c - 1);
                              }
                              _correct
                                ..clear()
                                ..addAll(nc);
                            }),
                  ),
              ]),
            ),
          if (_type != 'true_false')
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _optCtls.add(TextEditingController())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add option'),
              ),
            ),
        ] else ...[
          TextField(
            controller: _correctAnswer,
            maxLines: _type == 'fill_gap' ? 1 : 3,
            decoration: _dec(_type == 'fill_gap'
                ? 'Correct answer (auto-marked)'
                : 'Marking guide (optional, shown to the marker)'),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _explanation,
          maxLines: 2,
          decoration: _dec('Explanation shown in review (optional)'),
        ),
        const SizedBox(height: 16),
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
            child: Text(_saving ? 'Saving…' : (isEdit ? 'Save changes' : 'Add to bank'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Future<void> _save() async {
    if (_text.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question text is required.')));
      return;
    }
    if (_isChoice) {
      final filled = _optCtls.where((c) => c.text.trim().isNotEmpty).length;
      if (filled < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('At least two options are required.')));
        return;
      }
      if (_correct.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tick the correct option(s).')));
        return;
      }
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      if (widget.existing != null) 'id': widget.existing['id'],
      'class_id': widget.classId,
      'term_number': widget.termNumber,
      'subject_id': widget.subjectId,
      'question_type': _type,
      'question_text': _text.text.trim(),
      'marks': double.tryParse(_marks.text) ?? 1,
      'difficulty': _difficulty,
      'explanation': _explanation.text.trim(),
      'correct_answer': _correctAnswer.text.trim(),
      if (_isChoice) 'options': _optCtls.map((c) => c.text.trim()).toList(),
      if (_isChoice) 'correct_indices': _correct.toList(),
    };
    final res = await widget.api.post('/cbt/manage/bank', body: body);
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
    _text.dispose();
    _marks.dispose();
    _explanation.dispose();
    _correctAnswer.dispose();
    for (final c in _optCtls) {
      c.dispose();
    }
    super.dispose();
  }
}
