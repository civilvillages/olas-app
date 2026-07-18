import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/branding.dart';
import '../../core/api_client.dart';

/// Student Management — search-as-you-type, class/status filters, rich profile.
class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _students = const [];
  List<dynamic> _classes = const [];
  int _total = 0;
  int _page = 0;
  String _search = '';
  int? _classId;
  String _status = '';
  Timer? _debounce;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (more) {
      setState(() => _loadingMore = true);
    } else {
      _page = 0;
      setState(() { _loading = true; _error = null; });
    }
    final q = <String>['page=$_page'];
    if (_search.isNotEmpty) q.add('search=${Uri.encodeComponent(_search)}');
    if (_classId != null) q.add('class_id=$_classId');
    if (_status.isNotEmpty) q.add('status=$_status');
    final res = await widget.api.get('/staff/students?${q.join('&')}');
    if (!mounted) return;
    setState(() {
      _loading = false;
      _loadingMore = false;
      if (res.success) {
        final fresh = (res.data['students'] as List?) ?? const [];
        _students = more ? [..._students, ...fresh] : fresh;
        _total = (res.meta['total'] as num?)?.toInt() ?? _students.length;
        final cls = (res.data['classes'] as List?) ?? const [];
        if (cls.isNotEmpty) _classes = cls;
      } else {
        _error = res.friendlyError;
      }
    });
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _search = v.trim();
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
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
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search name, admission no, phone, parent…',
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true, fillColor: Colors.white,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: _onSearch,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: Row(children: [
          Expanded(
            child: DropdownButtonFormField<int?>(
              value: _classId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Class',
                filled: true, fillColor: Colors.white, isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('All')),
                ..._classes.map<DropdownMenuItem<int?>>((c) => DropdownMenuItem(
                      value: (c['id'] as num).toInt(),
                      child: Text('${c['name']}', overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: (v) { _classId = v; _load(); },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _status,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Status',
                filled: true, fillColor: Colors.white, isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('Active')),
                DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                DropdownMenuItem(value: 'graduated', child: Text('Graduated')),
                DropdownMenuItem(value: 'transferred', child: Text('Transferred')),
                DropdownMenuItem(value: 'withdrawn', child: Text('Withdrawn')),
              ],
              onChanged: (v) { _status = v ?? ''; _load(); },
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('$_total student(s)',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
        ),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _students.isEmpty
                ? Center(child: Text('No students match.',
                    style: TextStyle(color: Colors.grey.shade600)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                    itemCount: _students.length + (_students.length < _total ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _students.length) {
                        return Padding(
                          padding: const EdgeInsets.all(10),
                          child: Center(child: _loadingMore
                              ? const CircularProgressIndicator()
                              : OutlinedButton(
                                  onPressed: () { _page++; _load(more: true); },
                                  child: const Text('Load more'))),
                        );
                      }
                      return _card(_students[i]);
                    },
                  ),
      ),
    ]);
  }

  Widget _card(dynamic s) {
    final status = '${s['status']}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Branding.primaryColor.withOpacity(0.1),
          child: Text('${s['name']}'.isNotEmpty ? '${s['name']}'[0] : '?',
              style: TextStyle(color: Branding.primaryColor,
                  fontWeight: FontWeight.w800)),
        ),
        title: Text('${s['name']}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text('${s['admission_number'] ?? ''} · ${s['class'] ?? '—'}',
            style: const TextStyle(fontSize: 12)),
        trailing: status != 'active'
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(status,
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
              )
            : const Icon(Icons.chevron_right, size: 20),
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => _StudentProfileScreen(api: widget.api,
                studentId: (s['student_id'] as num).toInt()))),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

/// The profile a teacher opens mid-conversation with a parent.
class _StudentProfileScreen extends StatefulWidget {
  const _StudentProfileScreen({required this.api, required this.studentId});
  final ApiClient api;
  final int studentId;

  @override
  State<_StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<_StudentProfileScreen> {
  bool _loading = true;
  Map<String, dynamic> _s = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await widget.api.get('/staff/students/${widget.studentId}');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        _s = (res.data['student'] as Map?)?.cast<String, dynamic>() ?? const {};
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res.friendlyError)));
      }
    });
  }

  String _v(String k) => '${_s[k] ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Branding.primaryColor,
        foregroundColor: Colors.white,
        title: Text(_v('name').isEmpty ? 'Student' : _v('name'),
            style: const TextStyle(fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(14), children: [
              // header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Branding.primaryColor.withOpacity(0.1),
                    child: Text(_v('name').isNotEmpty ? _v('name')[0] : '?',
                        style: TextStyle(fontSize: 24,
                            color: Branding.primaryColor,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_v('name'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('${_v('admission_number')} · ${_v('class')} (${_v('level')})',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, children: [
                      _chip(_v('status'), _v('status') == 'active'
                          ? Branding.successColor : Colors.grey.shade600),
                      if (_v('gender').isNotEmpty)
                        _chip(_v('gender'), Branding.primaryColor),
                      if (_v('blood_group').isNotEmpty)
                        _chip(_v('blood_group'), Colors.red.shade400),
                    ]),
                  ])),
                ]),
              ),

              if (_v('medical_conditions').isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4D6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.medical_information_outlined,
                        size: 20, color: Color(0xFF8A6D00)),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Medical: ${_v('medical_conditions')}',
                        style: const TextStyle(fontSize: 12.5,
                            color: Color(0xFF8A6D00)))),
                  ]),
                ),
              ],

              _section('CONTACT', [
                _row('Student phone', _v('phone')),
                _row('Email', _v('email')),
                _row('Username', _v('username')),
                _row('Address', _v('address')),
              ]),
              _section('PARENT / GUARDIAN', [
                _row('Parent name', _v('parent_name')),
                _row('Parent phone', _v('parent_phone')),
                _row('Parent email', _v('parent_email')),
                for (final g in (_s['guardians'] as List? ?? const []))
                  _row('${g['relationship'] ?? 'Guardian'}',
                      '${g['name']}${'${g['phone'] ?? ''}'.isNotEmpty ? ' · ${g['phone']}' : ''}'),
              ]),
              _section('EMERGENCY', [
                _row('Contact', _v('emergency_contact_name')),
                _row('Phone', _v('emergency_contact_phone')),
              ]),
              _section('BACKGROUND', [
                _row('Date of birth', _v('date_of_birth')),
                _row('Religion', _v('religion')),
                _row('Nationality', _v('nationality')),
                _row('State of origin', _v('state_of_origin')),
                _row('LGA', _v('lga')),
                _row('Club / society', _v('club_society')),
                _row('Previous school', _v('previous_school')),
                _row('Admitted', _v('admission_date')),
              ]),

              if ((_s['class_history'] as List? ?? const []).isNotEmpty)
                _section('CLASS HISTORY', [
                  for (final h in (_s['class_history'] as List))
                    _row('${h['session']}',
                        '${h['class']}${'${h['section'] ?? ''}'.isNotEmpty ? ' · ${h['section']}' : ''}'),
                ]),

              if ((_s['academic_records'] as List? ?? const []).isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('ACADEMIC RECORDS', style: _h()),
                const SizedBox(height: 4),
                for (final r in (_s['academic_records'] as List))
                  Card(
                    margin: const EdgeInsets.only(top: 6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text('${r['session']} · ${r['term']} · ${r['class']}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          'Avg ${(r['average'] as num?)?.toStringAsFixed(1) ?? '—'}% · '
                          'Grade ${r['grade'] ?? '—'} · '
                          '${r['position'] ?? '—'} of ${r['class_size'] ?? '—'}',
                          style: const TextStyle(fontSize: 12)),
                      trailing: r['published'] == true
                          ? Icon(Icons.check_circle,
                              size: 18, color: Branding.successColor)
                          : Icon(Icons.hourglass_empty,
                              size: 16, color: Colors.grey.shade400),
                    ),
                  ),
              ],
            ]),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    final visible = rows.whereType<Widget>().toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 12),
      Text(title, style: _h()),
      const SizedBox(height: 4),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(children: visible),
      ),
    ]);
  }

  Widget _row(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
        Expanded(child: SelectableText(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(t, style: TextStyle(fontSize: 10.5, color: c,
            fontWeight: FontWeight.w700)),
      );

  TextStyle _h() => TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
      letterSpacing: 0.5, color: Colors.grey.shade600);
}
