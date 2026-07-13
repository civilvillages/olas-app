import 'package:flutter/material.dart';
import '../../config/branding.dart';
import '../../core/api_client.dart';

/// Trait Ratings — pick class+term, then student-by-student star ratings
/// across affective + psychomotor domains, using the school's own scale.
class TraitsScreen extends StatefulWidget {
  const TraitsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<TraitsScreen> createState() => _TraitsScreenState();
}

class _TraitsScreenState extends State<TraitsScreen> {
  bool _loadingTargets = true;
  String? _error;
  List<dynamic> _classes = const [];
  List<dynamic> _terms = const [];
  int? _classId;
  int? _termId;

  bool _bundleLoading = false;
  Map<String, dynamic>? _bundle;
  // draft: "student:trait" -> rating string
  final Map<String, String> _draft = {};
  bool _saving = false;
  int _index = 0;
  final _pageCtl = PageController();

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  Future<void> _loadTargets() async {
    setState(() { _loadingTargets = true; _error = null; });
    final res = await widget.api.get('/staff/results/targets');
    if (!mounted) return;
    if (!res.success) {
      setState(() { _loadingTargets = false; _error = res.friendlyError; });
      return;
    }
    setState(() {
      _loadingTargets = false;
      _classes = (res.data['classes'] as List?) ?? const [];
      _terms = (res.data['terms'] as List?) ?? const [];
      final cur = _terms.cast<Map>().where((t) => t['is_current'] == true);
      if (_termId == null && cur.isNotEmpty) {
        _termId = (cur.first['term_id'] as num).toInt();
      }
    });
  }

  Future<void> _open() async {
    if (_classId == null || _termId == null) return;
    setState(() { _bundleLoading = true; _bundle = null; _draft.clear(); _index = 0; });
    final res = await widget.api.get(
        '/staff/traits/bundle?class_id=$_classId&term_id=$_termId');
    if (!mounted) return;
    setState(() {
      _bundleLoading = false;
      if (res.success) {
        _bundle = res.data;
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res.friendlyError)));
      }
    });
  }

  List<dynamic> get _students => (_bundle?['students'] as List?) ?? const [];
  List<dynamic> get _affective => (_bundle?['affective'] as List?) ?? const [];
  List<dynamic> get _psychomotor => (_bundle?['psychomotor'] as List?) ?? const [];
  List<dynamic> get _scale => (_bundle?['scale'] as List?) ?? const [];
  int get _maxRating => _scale.isEmpty ? 5
      : _scale.map((s) => (s['rating'] as num).toInt()).reduce((a, b) => a > b ? a : b);

  String _dk(int sid, int tid) => '$sid:$tid';

  int _valueFor(int sid, int tid) {
    final d = _draft[_dk(sid, tid)];
    if (d != null) return int.tryParse(d) ?? 0;
    final st = _students.cast<Map>().where((s) => s['student_id'] == sid);
    if (st.isEmpty) return 0;
    final r = st.first['ratings'];
    if (r is Map && r['$tid'] != null) return (r['$tid'] as num).toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingTargets) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline, size: 44, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(_error!, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _loadTargets, child: const Text('Try again')),
        ]),
      ));
    }
    if (_bundle == null) return _pickerView();
    return _entryView();
  }

  Widget _pickerView() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Rate a class', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(
        value: _classId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Class',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        hint: const Text('Select class'),
        items: _classes.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(
              value: (c['class_id'] as num).toInt(),
              child: Text('${c['class']} (${c['level']})'),
            )).toList(),
        onChanged: (v) => setState(() => _classId = v),
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<int>(
        value: _termId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Term',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: _terms.map<DropdownMenuItem<int>>((t) => DropdownMenuItem(
              value: (t['term_id'] as num).toInt(),
              child: Text('${t['term']}${t['is_current'] == true ? ' (current)' : ''}'),
            )).toList(),
        onChanged: (v) => setState(() => _termId = v),
      ),
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Branding.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _bundleLoading || _classId == null ? null : _open,
          icon: _bundleLoading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.star_outline, size: 20),
          label: const Text('Open for rating',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }

  Widget _entryView() {
    final cls = (_bundle!['class'] as Map?) ?? const {};
    final term = (_bundle!['term'] as Map?) ?? const {};
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Branding.primaryColor.withOpacity(0.06),
        child: Row(children: [
          Expanded(child: Text('${cls['name'] ?? ''} · ${term['name'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w700))),
          TextButton(onPressed: () => setState(() => _bundle = null),
              child: const Text('Change')),
        ]),
      ),
      Expanded(
        child: PageView.builder(
          controller: _pageCtl,
          itemCount: _students.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) => _studentPage(_students[i]),
        ),
      ),
      _bottomBar(),
    ]);
  }

  Widget _studentPage(dynamic s) {
    final sid = (s['student_id'] as num).toInt();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Center(child: Text('${s['name']}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
      Center(child: Text('Student ${_index + 1} of ${_students.length}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5))),
      const SizedBox(height: 16),
      if (_affective.isNotEmpty) ...[
        _domainHeader('AFFECTIVE'),
        ..._affective.map((t) => _traitRow(sid, t)),
        const SizedBox(height: 12),
      ],
      if (_psychomotor.isNotEmpty) ...[
        _domainHeader('PSYCHOMOTOR'),
        ..._psychomotor.map((t) => _traitRow(sid, t)),
      ],
      const SizedBox(height: 8),
      if (_scale.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: _scale.map((sc) => Text(
                  '${sc['rating']} — ${sc['description']}',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600))).toList()),
        ),
    ]);
  }

  Widget _domainHeader(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            letterSpacing: 0.5, color: Colors.grey.shade600)),
      );

  Widget _traitRow(int sid, dynamic t) {
    final tid = (t['id'] as num).toInt();
    final val = _valueFor(sid, tid);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${t['name']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 2),
        Row(children: [
          ...List.generate(_maxRating, (i) {
            final star = i + 1;
            return IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              constraints: const BoxConstraints(),
              icon: Icon(star <= val ? Icons.star : Icons.star_border,
                  size: 30,
                  color: star <= val ? const Color(0xFFB8860B) : Colors.grey.shade400),
              onPressed: () {
                setState(() {
                  // tap the current value again to clear it
                  _draft[_dk(sid, tid)] = (val == star) ? '' : '$star';
                });
              },
            );
          }),
          const SizedBox(width: 6),
          if (val > 0)
            Text('$val', style: TextStyle(
                fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
        ]),
      ]),
    );
  }

  Widget _bottomBar() {
    final last = _index >= _students.length - 1;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Row(children: [
          OutlinedButton(
            onPressed: _index == 0 ? null : () => _pageCtl.previousPage(
                duration: const Duration(milliseconds: 200), curve: Curves.easeOut),
            child: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: last ? Branding.successColor : Branding.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saving ? null : (last ? _save : () => _pageCtl.nextPage(
                  duration: const Duration(milliseconds: 200), curve: Curves.easeOut)),
              icon: _saving
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(last ? Icons.save : Icons.chevron_right, size: 20),
              label: Text(last ? 'Save ratings' : 'Next student',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: last ? null : () => _pageCtl.nextPage(
                duration: const Duration(milliseconds: 200), curve: Curves.easeOut),
            child: const Icon(Icons.chevron_right),
          ),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (_draft.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No changes to save.')));
      return;
    }
    setState(() => _saving = true);
    final items = _draft.entries.map((e) {
      final parts = e.key.split(':');
      return {
        'student_id': int.parse(parts[0]),
        'trait_id': int.parse(parts[1]),
        'rating': e.value,
      };
    }).toList();
    final res = await widget.api.post('/staff/traits/save', body: {
      'class_id': _classId, 'term_id': _termId, 'ratings': items,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Saved ${res.data['saved'] ?? 0} rating(s).')));
      _open(); // reload the server truth
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.friendlyError)));
    }
  }

  @override
  void dispose() {
    _pageCtl.dispose();
    super.dispose();
  }
}
