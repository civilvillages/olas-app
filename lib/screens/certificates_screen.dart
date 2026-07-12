import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = const [];
  List<dynamic> _sessions = const [];
  int? _sessionId;
  bool _all = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    var path = '/me/certificates';
    if (_all) {
      path += '?session_id=0';
    } else if (_sessionId != null) {
      path += '?session_id=$_sessionId';
    }
    final res = await widget.api.get(path);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        _items = (res.data['certificates'] as List?) ?? const [];
        _sessions = (res.data['sessions'] as List?) ?? const [];
        _sessionId ??= (res.meta['selected_session_id'] as num?)?.toInt();
      } else { _error = res.friendlyError; }
    });
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
    return RefreshIndicator(
      onRefresh: _load,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: DropdownButtonFormField<int>(
            value: _all ? -1 : _sessionId,
            isDense: true,
            decoration: InputDecoration(
              labelText: 'Session',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              const DropdownMenuItem<int>(value: -1, child: Text('All sessions')),
              ..._sessions.map<DropdownMenuItem<int>>((s) => DropdownMenuItem(
                  value: (s['id'] as num).toInt(), child: Text('${s['name']}'))),
            ],
            onChanged: (v) {
              setState(() { _all = v == -1; if (v != -1) _sessionId = v; });
              _load();
            },
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(children: [
                      const SizedBox(height: 90),
                      Center(child: Text(_error!, style: TextStyle(color: Colors.grey.shade600))),
                      const SizedBox(height: 12),
                      Center(child: OutlinedButton(onPressed: _load, child: const Text('Try again'))),
                    ])
                  : _items.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 90),
                          Icon(Icons.workspace_premium_outlined,
                              size: 52, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Center(child: Text('No certificates here yet.',
                              style: TextStyle(color: Colors.grey.shade600))),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final c = _items[i];
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                leading: Icon(Icons.workspace_premium,
                                    color: const Color(0xFFB8860B), size: 30),
                                title: Text('${c['title']}',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    'Serial: ${c['serial']}\n${c['session'] ?? ''} ${c['term'] ?? ''} · issued ${_fmtDate(c['issued_at'] as String?)}',
                                    style: const TextStyle(fontSize: 12)),
                                isThreeLine: true,
                                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text(
                                        'View or print this certificate on the portal.'))),
                              ),
                            );
                          },
                        ),
        ),
      ]),
    );
  }
}
