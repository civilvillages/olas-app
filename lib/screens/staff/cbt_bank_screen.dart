import 'package:flutter/material.dart';
import '../../config/branding.dart';
import '../../core/api_client.dart';

/// Question Bank — browse by class/subject/bank-term.
/// (Single add/edit/delete arrives once the bank-write API lands; bulk
/// import stays on the web, as agreed.)
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

    return ListView(padding: const EdgeInsets.all(14), children: [
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
                'Empty bank. Add questions on the web (single add in-app is coming next build).',
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
    );
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
