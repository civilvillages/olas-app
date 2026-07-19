import 'package:flutter/material.dart';
import '../../config/branding.dart';
import '../../core/api_client.dart';

/// Attendance — term summary: times school opened + days present per student.
class AttendanceEntryScreen extends StatefulWidget {
  const AttendanceEntryScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<AttendanceEntryScreen> createState() => _AttendanceEntryScreenState();
}

class _AttendanceEntryScreenState extends State<AttendanceEntryScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _classes = const [];
  List<dynamic> _terms = const [];
  int? _classId;
  int? _termId;

  bool _bundleLoading = false;
  Map<String, dynamic>? _bundle;
  final _openedCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  final Map<int, TextEditingController> _presentCtls = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final res = await widget.api.get('/staff/attendance/targets');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        _classes = (res.data['classes'] as List?) ?? const [];
        _terms = (res.data['terms'] as List?) ?? const [];
        for (final t in _terms) {
          if (t['is_current'] == true) _termId = (t['term_id'] as num).toInt();
        }
      } else {
        _error = res.friendlyError;
      }
    });
  }

  Future<void> _loadBundle() async {
    if (_classId == null || _termId == null) return;
    setState(() { _bundleLoading = true; _bundle = null; });
    final res = await widget.api
        .get('/staff/attendance/bundle?class_id=$_classId&term_id=$_termId');
    if (!mounted) return;
    setState(() {
      _bundleLoading = false;
      if (res.success) {
        _bundle = res.data;
        _openedCtl.text = '${res.data['times_school_opened'] ?? 0}';
        _notesCtl.text = '${res.data['notes'] ?? ''}';
        for (final c in _presentCtls.values) {
          c.dispose();
        }
        _presentCtls.clear();
        for (final s in (res.data['students'] as List? ?? const [])) {
          final id = (s['student_id'] as num).toInt();
          final v = s['times_present'];
          _presentCtls[id] = TextEditingController(text: v == null ? '' : '$v');
        }
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

    final opened = int.tryParse(_openedCtl.text) ?? 0;
    final students = (_bundle?['students'] as List?) ?? const [];
    final filled = _presentCtls.values.where((c) => c.text.trim().isNotEmpty).length;

    return ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 90), children: [
      DropdownButtonFormField<int>(
        value: _classId,
        isExpanded: true,
        decoration: _dec('Class'),
        hint: const Text('Select class'),
        items: _classes.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(
              value: (c['class_id'] as num).toInt(),
              child: Text('${c['class']} (${c['level']})',
                  overflow: TextOverflow.ellipsis),
            )).toList(),
        onChanged: (v) { setState(() => _classId = v); _loadBundle(); },
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 6, children: [
        for (final t in _terms)
          ChoiceChip(
            label: Text('${t['term']}', style: const TextStyle(fontSize: 12)),
            selected: _termId == (t['term_id'] as num).toInt(),
            onSelected: (_) {
              setState(() => _termId = (t['term_id'] as num).toInt());
              _loadBundle();
            },
          ),
      ]),
      const SizedBox(height: 8),

      if (_bundleLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 50),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_bundle != null) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_bundle!['class']?['name']} · ${_bundle!['term']?['name']} '
                 '(${_bundle!['term']?['session']})',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(children: [
              SizedBox(width: 140, child: TextField(
                controller: _openedCtl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                decoration: _dec('Times opened'),
                onChanged: (_) => setState(() {}),
              )),
              const SizedBox(width: 10),
              Expanded(child: Text(
                  'School-wide for this term — changing it recomputes every student\u2019s absences.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
            ]),
            const SizedBox(height: 8),
            TextField(controller: _notesCtl, decoration: _dec('Notes (optional)')),
          ]),
        ),
        const SizedBox(height: 10),
        Text('DAYS PRESENT — $filled of ${students.length} filled',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                letterSpacing: 0.5, color: Colors.grey.shade600)),
        ...students.map((s) {
          final id = (s['student_id'] as num).toInt();
          final ctl = _presentCtls[id]!;
          final v = int.tryParse(ctl.text.trim());
          final over = v != null && opened > 0 && v > opened;
          return Card(
            margin: const EdgeInsets.only(top: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s['name']}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  Text('${s['admission_number'] ?? ''}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ])),
                SizedBox(width: 92, child: TextField(
                  controller: ctl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    hintText: '—',
                    errorText: over ? '≤ $opened' : null,
                    isDense: true,
                    filled: true, fillColor: const Color(0xFFF8F9FB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                )),
                const SizedBox(width: 6),
                Text('/ $opened',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              ]),
            ),
          );
        }),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
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
            label: const Text('Save attendance',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ] else
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text('Pick class and term to load the register.',
              style: TextStyle(color: Colors.grey.shade600))),
        ),
    ]);
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
    final present = <String, dynamic>{};
    _presentCtls.forEach((id, ctl) {
      final t = ctl.text.trim();
      if (t.isNotEmpty) present['$id'] = t;
    });
    setState(() => _saving = true);
    final res = await widget.api.post('/staff/attendance/save', body: {
      'class_id': _classId,
      'term_id': _termId,
      'times_school_opened': int.tryParse(_openedCtl.text) ?? 0,
      'notes': _notesCtl.text.trim(),
      'present': present,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          'Saved — ${res.data['updated'] ?? 0} student(s) updated'
          '${((res.data['skipped'] as num?) ?? 0) > 0 ? ', ${res.data['skipped']} blank skipped' : ''}.')));
      _loadBundle();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.friendlyError)));
    }
  }

  @override
  void dispose() {
    _openedCtl.dispose();
    _notesCtl.dispose();
    for (final c in _presentCtls.values) {
      c.dispose();
    }
    super.dispose();
  }
}
