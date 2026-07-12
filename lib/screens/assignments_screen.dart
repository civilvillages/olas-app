import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';

/// My Assignments (read-only view of targeted assignments + my submission state).
class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = const [];
  List<dynamic> _sessions = const [];
  int? _sessionId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    var path = '/me/assignments';
    if (_sessionId != null) path += '?session_id=$_sessionId';
    final res = await widget.api.get(path);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        _items = (res.data['assignments'] as List?) ?? const [];
        _sessions = (res.data['sessions'] as List?) ?? const [];
        _sessionId ??= (res.meta['selected_session_id'] as num?)?.toInt();
      } else {
        _error = res.friendlyError;
      }
    });
  }

  (String, Color) _subTag(Map<String, dynamic>? sub) {
    if (sub == null) return ('Not submitted', Colors.grey.shade600);
    return switch ('${sub['status']}') {
      'graded' => ('Graded', Branding.successColor),
      'submitted' => ('Submitted', Branding.primaryColor),
      'returned' => ('Returned', const Color(0xFFB8860B)),
      'draft' => ('Draft saved', Colors.grey.shade600),
      _ => ('${sub['status']}', Colors.grey.shade600),
    };
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (_sessions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: DropdownButtonFormField<int>(
            value: _sessionId,
            isDense: true,
            decoration: InputDecoration(
              labelText: 'Session',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _sessions
                .map<DropdownMenuItem<int>>((s) => DropdownMenuItem(
                    value: (s['id'] as num).toInt(), child: Text('${s['name']}')))
                .toList(),
            onChanged: (v) { setState(() => _sessionId = v); _load(); },
          ),
        ),
      Expanded(child: _inner()),
    ]);
  }

  Widget _inner() {
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _items.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 110),
                      Icon(Icons.assignment_outlined, size: 52, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Center(child: Text('No assignments right now.',
                          style: TextStyle(color: Colors.grey.shade600))),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _card(_items[i]),
                    ),
    );
  }

  Widget _errorView() => ListView(children: [
        const SizedBox(height: 110),
        Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Center(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(_error!, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
        )),
        const SizedBox(height: 12),
        Center(child: OutlinedButton(onPressed: _load, child: const Text('Try again'))),
      ]);

  Widget _card(dynamic a) {
    final sub = (a['my_submission'] as Map?)?.cast<String, dynamic>();
    final (label, color) = _subTag(sub);
    final due = _fmtDate(a['due_at'] as String?);
    final score = sub?['score'];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        shape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text('${a['title']}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(
            '${a['subject'] ?? ''} · ${a['type'] ?? ''}${due.isNotEmpty ? ' · due $due' : ''}',
            style: const TextStyle(fontSize: 12.5)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(score != null ? '$label · $score' : label,
              style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ('${a['description'] ?? ''}'.trim().isNotEmpty) ...[
                Text('${a['description']}', style: const TextStyle(height: 1.4)),
                const SizedBox(height: 10),
              ],
              if ('${a['instructions'] ?? ''}'.trim().isNotEmpty) ...[
                const Text('Instructions',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                Text('${a['instructions']}',
                    style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
                const SizedBox(height: 10),
              ],
              Text('Total marks: ${a['total_marks']}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
              if (sub?['teacher_comment'] != null &&
                  '${sub!['teacher_comment']}'.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Branding.primaryColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text("Teacher: ${sub['teacher_comment']}",
                      style: const TextStyle(fontSize: 13, height: 1.35)),
                ),
              ],
              const SizedBox(height: 8),
              Text('Submitting from the app is coming soon — submit on the portal for now.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5)),
            ]),
          ),
        ],
      ),
    );
  }
}
