import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';
import 'result_detail_screen.dart';

/// Feature 5 — My Results (CBT history).
/// Session/term pickers ("current by default, history on demand"), then the
/// student's attempts with score and release status.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _sessions = const [];
  List<dynamic> _terms = const [];
  List<dynamic> _attempts = const [];
  int? _sessionId;
  int? _termId;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  Future<void> _load({bool initial = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    var path = '/cbt/history';
    final params = <String>[];
    if (_sessionId != null) params.add('session_id=$_sessionId');
    if (_termId != null) params.add('term_id=$_termId');
    if (params.isNotEmpty) path += '?${params.join('&')}';

    final res = await widget.api.get(path);
    if (!mounted) return;
    if (!res.success) {
      setState(() {
        _loading = false;
        _error = res.friendlyError;
      });
      return;
    }
    final d = res.data;
    _sessions = (d['sessions'] as List?) ?? const [];
    _terms = (d['terms'] as List?) ?? const [];
    _attempts = (d['attempts'] as List?) ?? const [];

    // First load with nothing selected: auto-pick the first session so the
    // student sees something immediately (server lists sessions it knows).
    if (initial && _sessionId == null && _attempts.isEmpty && _sessions.isNotEmpty) {
      _sessionId = (_sessions.first['id'] as num).toInt();
      return _load();
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: Column(
        children: [
          _pickers(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _pickers() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _sessionId,
            isDense: true,
            decoration: InputDecoration(
              labelText: 'Session',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _sessions
                .map<DropdownMenuItem<int>>((s) => DropdownMenuItem(
                      value: (s['id'] as num).toInt(),
                      child: Text('${s['name']}'),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() {
                _sessionId = v;
                _termId = null; // cascading: term resets with session
              });
              _load();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _termId,
            isDense: true,
            decoration: InputDecoration(
              labelText: 'Term',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              const DropdownMenuItem<int>(value: null, child: Text('All terms')),
              ..._terms.map<DropdownMenuItem<int>>((t) => DropdownMenuItem(
                    value: (t['id'] as num).toInt(),
                    child: Text('${t['name']}'),
                  )),
            ],
            onChanged: (v) {
              setState(() => _termId = v);
              _load();
            },
          ),
        ),
      ]),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(children: [
        const SizedBox(height: 100),
        Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Center(
            child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
        )),
        const SizedBox(height: 12),
        Center(
            child:
                OutlinedButton(onPressed: _load, child: const Text('Try again'))),
      ]);
    }
    if (_attempts.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 100),
        Icon(Icons.fact_check_outlined, size: 52, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Center(
            child: Text('No exam results here yet.',
                style: TextStyle(color: Colors.grey.shade600))),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _attempts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final a = _attempts[i];
        final visible = (a['result_visible'] as bool?) ?? false;
        final score = a['score'];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ResultDetailScreen(
                  api: widget.api,
                  attemptId: (a['attempt_id'] as num).toInt(),
                ),
              ),
            ),
            title: Text('${a['title']}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${a['subject']} · ${a['term']} · ${a['session']}',
                style: const TextStyle(fontSize: 12.5)),
            trailing: visible
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Branding.primaryColor.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${score ?? '—'}',
                        style: TextStyle(
                            color: Branding.primaryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4D6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Pending',
                        style: TextStyle(
                            color: Color(0xFF8A6D00),
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ),
          ),
        );
      },
    );
  }
}
