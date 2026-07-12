import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';

/// Feature 7 — the student's own profile (read-only).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _user = const {};
  Map<String, dynamic> _student = const {};
  Map<String, dynamic> _parent = const {};
  Map<String, dynamic> _emergency = const {};
  List<dynamic> _guardians = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await widget.api.get('/me/profile');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        Map<String, dynamic> m(String k) =>
            (res.data[k] as Map?)?.cast<String, dynamic>() ?? {};
        _user = m('user');
        _student = m('student');
        _parent = m('parent_contact');
        _emergency = m('emergency_contact');
        _guardians = (res.data['guardians'] as List?) ?? const [];
      } else {
        _error = res.friendlyError;
      }
    });
  }

  String _initials() {
    final f = '${_user['first_name'] ?? ''}';
    final l = '${_user['last_name'] ?? ''}';
    final i =
        '${f.isNotEmpty ? f[0] : ''}${l.isNotEmpty ? l[0] : ''}'.toUpperCase();
    return i.isEmpty ? '?' : i;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(_error!, textAlign: TextAlign.center),
      ));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: Branding.primaryColor,
            child: Text(_initials(),
                style: const TextStyle(
                    fontSize: 30,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text('${_user['full_name'] ?? ''}',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        Center(
          child: Text(
              '${_student['admission_number'] ?? ''} · ${_student['class'] ?? ''}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5)),
        ),
        const SizedBox(height: 20),

        _card('PERSONAL DETAILS', [
          _row('Gender', _cap('${_user['gender'] ?? ''}')),
          _row('Date of birth', '${_user['date_of_birth'] ?? ''}'),
          _row('Religion', '${_student['religion'] ?? ''}'),
          _row('Blood group', '${_student['blood_group'] ?? ''}'),
          _row('Nationality', '${_student['nationality'] ?? ''}'),
          _row('State of origin', '${_student['state_of_origin'] ?? ''}'),
          _row('LGA', '${_student['lga'] ?? ''}'),
        ]),
        const SizedBox(height: 12),

        _card('SCHOOL', [
          _row('Admission number', '${_student['admission_number'] ?? ''}'),
          _row('Admission date', '${_student['admission_date'] ?? ''}'),
          _row('Class', '${_student['class'] ?? ''}'),
          _row('Club / society', '${_student['club_society'] ?? ''}'),
          _row('Previous school', '${_student['previous_school'] ?? ''}'),
        ]),
        const SizedBox(height: 12),

        _card('PARENT / GUARDIAN', [
          _row('Name', '${_parent['name'] ?? ''}'),
          _row('Phone', '${_parent['phone'] ?? ''}'),
          _row('Email', '${_parent['email'] ?? ''}'),
          ..._guardians.map((g) => _row(
              'Linked account',
              '${g['name']} (${g['relationship']}${(g['is_primary'] as bool? ?? false) ? ', primary' : ''})')),
        ]),
        const SizedBox(height: 12),

        if ('${_emergency['name'] ?? ''}'.isNotEmpty ||
            '${_emergency['phone'] ?? ''}'.isNotEmpty)
          _card('EMERGENCY CONTACT', [
            _row('Name', '${_emergency['name'] ?? ''}'),
            _row('Phone', '${_emergency['phone'] ?? ''}'),
          ]),
      ]),
    );
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _card(String title, List<Widget> rows) {
    final visible = rows.whereType<Widget>().toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Colors.grey.shade500)),
        const SizedBox(height: 6),
        ...visible,
      ]),
    );
  }

  Widget _row(String k, String v) {
    if (v.trim().isEmpty || v == 'null') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 130,
            child: Text(k, style: TextStyle(color: Colors.grey.shade600))),
        Expanded(
            child:
                Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
