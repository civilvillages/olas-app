import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _summary = const {};
  Map<String, dynamic>? _termSummary;
  List<dynamic> _days = const [];
  List<dynamic> _terms = const [];
  int? _termId;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    var path = '/me/attendance';
    if (_termId != null) path += '?term_id=$_termId';
    final res = await widget.api.get(path);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        _summary = (res.data['summary'] as Map?)?.cast<String, dynamic>() ?? {};
        _termSummary = (res.data['term_summary'] as Map?)?.cast<String, dynamic>();
        _days = (res.data['days'] as List?) ?? const [];
        _terms = (res.data['terms'] as List?) ?? const [];
        _termId ??= (res.meta['selected_term_id'] as num?)?.toInt();
      } else { _error = res.friendlyError; }
    });
  }

  (Color, IconData) _style(String s) => switch (s) {
        'present' => (Branding.successColor, Icons.check_circle),
        'absent' => (Colors.red.shade700, Icons.cancel),
        'late' => (const Color(0xFFB8860B), Icons.schedule),
        'excused' => (Colors.grey.shade600, Icons.info),
        _ => (Colors.grey.shade600, Icons.help_outline),
      };

  String _fmtDate(String d) {
    try {
      final x = DateTime.parse(d);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      const wd = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return '${wd[x.weekday - 1]}, ${x.day} ${m[x.month - 1]} ${x.year}';
    } catch (_) { return d; }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: DropdownButtonFormField<int>(
            value: _termId,
            isDense: true,
            decoration: InputDecoration(
              labelText: 'Term',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _terms
                .map<DropdownMenuItem<int>>((t) => DropdownMenuItem(
                    value: (t['id'] as num).toInt(),
                    child: Text('${t['session']} · ${t['name']}',
                        overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) { setState(() => _termId = v); _load(); },
          ),
        ),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(children: [
        const SizedBox(height: 90),
        Center(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(_error!, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
        )),
        const SizedBox(height: 12),
        Center(child: OutlinedButton(onPressed: _load, child: const Text('Try again'))),
      ]);
    }
    final children = <Widget>[
      Row(children: [
        _stat('Present', (_summary['present'] as num?)?.toInt() ?? 0, Branding.successColor),
        const SizedBox(width: 8),
        _stat('Absent', (_summary['absent'] as num?)?.toInt() ?? 0, Colors.red.shade700),
        const SizedBox(width: 8),
        _stat('Late', (_summary['late'] as num?)?.toInt() ?? 0, const Color(0xFFB8860B)),
      ]),
      const SizedBox(height: 8),
    ];
    final opened = _summary['times_school_opened'];
    if (opened != null) {
      children.add(Center(child: Text('School opened $opened time(s) this term',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5))));
      children.add(const SizedBox(height: 8));
    }
    if (_days.isEmpty && _termSummary != null) {
      final ts = _termSummary!;
      children.addAll([
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Branding.primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Branding.primaryColor.withOpacity(0.2)),
          ),
          child: Column(children: [
            Row(children: [
              _stat('Opened', (ts['opened'] as num?)?.toInt() ?? 0,
                  Branding.primaryColor),
              const SizedBox(width: 8),
              _stat('Present', (ts['present'] as num?)?.toInt() ?? 0,
                  Branding.successColor),
              const SizedBox(width: 8),
              _stat('Absent', (ts['absent'] as num?)?.toInt() ?? 0,
                  Colors.red.shade700),
            ]),
            const SizedBox(height: 8),
            Text('From your term report — the daily register was not marked this term.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
          ]),
        ),
      ]);
    } else if (_days.isEmpty) {
      children.addAll([
        const SizedBox(height: 60),
        Icon(Icons.event_available_outlined, size: 52, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Center(child: Text('No attendance recorded for this term yet.',
            style: TextStyle(color: Colors.grey.shade600))),
      ]);
    } else {
      children.addAll(_days.map((d) {
        final (color, icon) = _style('${d['status']}');
        return Card(
          margin: const EdgeInsets.only(top: 6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            dense: true,
            leading: Icon(icon, color: color, size: 22),
            title: Text(_fmtDate('${d['date']}'),
                style: const TextStyle(fontSize: 14)),
            trailing: Text('${d['status']}'.toUpperCase(),
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11.5)),
            subtitle: '${d['remarks'] ?? ''}'.trim().isEmpty
                ? null
                : Text('${d['remarks']}', style: const TextStyle(fontSize: 12)),
          ),
        );
      }));
    }
    return ListView(padding: const EdgeInsets.all(12), children: children);
  }

  Widget _stat(String label, int v, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text('$v', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ]),
      ),
    );
  }
}
