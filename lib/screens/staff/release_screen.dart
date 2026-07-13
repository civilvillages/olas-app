import 'package:flutter/material.dart';
import '../../config/branding.dart';
import '../../core/api_client.dart';

/// Result Release — global fee-gate default + per-term policies,
/// mirroring the portal's Release center.
class ReleaseScreen extends StatefulWidget {
  const ReleaseScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<ReleaseScreen> createState() => _ReleaseScreenState();
}

class _ReleaseScreenState extends State<ReleaseScreen> {
  bool _loading = true;
  String? _error;
  bool _gateOn = false;
  final _msgCtl = TextEditingController();
  List<dynamic> _terms = const [];
  List<dynamic> _sessions = const [];
  int? _sessionId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    var path = '/staff/release';
    if (_sessionId != null) path += '?session_id=$_sessionId';
    final res = await widget.api.get(path);
    if (!mounted) return;
    if (!res.success) {
      setState(() { _loading = false; _error = res.friendlyError; });
      return;
    }
    final st = (res.data['settings'] as Map?) ?? const {};
    setState(() {
      _loading = false;
      _gateOn = (st['fee_gate_enabled'] as bool?) ?? false;
      _msgCtl.text = '${st['withhold_message'] ?? ''}';
      _terms = (res.data['terms'] as List?) ?? const [];
      _sessions = (res.data['sessions'] as List?) ?? const [];
      _sessionId ??= (res.meta['selected_session_id'] as num?)?.toInt();
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    final res = await widget.api.post('/staff/release/settings', body: {
      'fee_gate_enabled': _gateOn,
      'withhold_message': _msgCtl.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.success ? 'Defaults saved.' : res.friendlyError)));
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
    return ListView(padding: const EdgeInsets.all(14), children: [
      // Global default card
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Global default',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _gateOn,
            onChanged: (v) => setState(() => _gateOn = v),
            title: const Text('Withhold results from students who owe fees',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            subtitle: const Text(
                "A student with an outstanding balance on a term's invoice can't see that term's result until it's cleared. Each term can override this below.",
                style: TextStyle(fontSize: 11.5)),
          ),
          const Text('Message shown to a withheld student',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _msgCtl,
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(10),
              helperText: 'Include {balance} to show the student’s outstanding amount.',
              helperStyle: const TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Branding.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: _saving ? null : _saveSettings,
              child: Text(_saving ? 'Saving…' : 'Save defaults'),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 14),

      // Per-term policies
      Row(children: [
        const Expanded(child: Text('Per-term policies',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
        DropdownButton<int>(
          value: _sessionId,
          underline: const SizedBox.shrink(),
          items: [
            const DropdownMenuItem<int>(value: 0, child: Text('All sessions')),
            ..._sessions.map<DropdownMenuItem<int>>((s) => DropdownMenuItem(
                value: (s['id'] as num).toInt(), child: Text('${s['name']}'))),
          ],
          onChanged: (v) { setState(() => _sessionId = v); _load(); },
        ),
      ]),
      const SizedBox(height: 4),
      ..._terms.map(_termRow),
    ]);
  }

  Widget _termRow(dynamic t) {
    final gate = '${t['fee_gate_mode'] ?? 'default'}';
    final scope = '${t['release_scope'] ?? 'all'}';
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        title: Text('${t['session']} · ${t['term']}',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                color: (t['is_current'] as bool? ?? false) ? Branding.primaryColor : null)),
        subtitle: Text('Fee gate: $gate · Release: $scope',
            style: const TextStyle(fontSize: 12)),
        trailing: OutlinedButton(
          onPressed: () => _configure((t['term_id'] as num).toInt(),
              '${t['session']} · ${t['term']}'),
          child: const Text('Configure', style: TextStyle(fontSize: 12.5)),
        ),
      ),
    );
  }

  Future<void> _configure(int termId, String label) async {
    final res = await widget.api.get('/staff/release/term/$termId');
    if (!mounted) return;
    if (!res.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.friendlyError)));
      return;
    }
    final policy = (res.data['policy'] as Map?) ?? const {};
    var mode = '${policy['fee_gate_mode'] ?? 'default'}';
    var scope = '${policy['release_scope'] ?? 'all'}';
    final classes = ((res.data['classes'] as List?) ?? const [])
        .map((c) => Map<String, dynamic>.from(c)).toList();
    final levels = ((res.data['levels'] as List?) ?? const [])
        .map((l) => Map<String, dynamic>.from(l)).toList();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              const Text('Fee gate for this term',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ...['default', 'on', 'off'].map((m) => RadioListTile<String>(
                    dense: true, contentPadding: EdgeInsets.zero,
                    value: m, groupValue: mode,
                    onChanged: (v) => setSt(() => mode = v!),
                    title: Text(switch (m) {
                      'default' => 'Use the global default',
                      'on' => 'Always withhold if owing (this term)',
                      _ => 'Never withhold (this term)',
                    }, style: const TextStyle(fontSize: 13.5)),
                  )),
              const SizedBox(height: 6),
              const Text('Release scope',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              RadioListTile<String>(
                dense: true, contentPadding: EdgeInsets.zero,
                value: 'all', groupValue: scope,
                onChanged: (v) => setSt(() => scope = v!),
                title: const Text('All classes', style: TextStyle(fontSize: 13.5)),
              ),
              RadioListTile<String>(
                dense: true, contentPadding: EdgeInsets.zero,
                value: 'selected', groupValue: scope,
                onChanged: (v) => setSt(() => scope = v!),
                title: const Text('Only selected classes / levels',
                    style: TextStyle(fontSize: 13.5)),
              ),
              if (scope == 'selected') ...[
                const SizedBox(height: 4),
                const Text('Levels', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                Wrap(spacing: 6, children: levels.map((l) => FilterChip(
                      label: Text('${l['name']}', style: const TextStyle(fontSize: 12)),
                      selected: (l['selected'] as bool?) ?? false,
                      onSelected: (v) => setSt(() => l['selected'] = v),
                    )).toList()),
                const SizedBox(height: 6),
                const Text('Classes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                Wrap(spacing: 6, children: classes.map((c) => FilterChip(
                      label: Text('${c['name']}', style: const TextStyle(fontSize: 12)),
                      selected: (c['selected'] as bool?) ?? false,
                      onSelected: (v) => setSt(() => c['selected'] = v),
                    )).toList()),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Branding.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    final r = await widget.api.post('/staff/release/term/$termId', body: {
                      'fee_gate_mode': mode,
                      'release_scope': scope,
                      'classes': classes.where((c) => c['selected'] == true)
                          .map((c) => c['id']).toList(),
                      'levels': levels.where((l) => l['selected'] == true)
                          .map((l) => l['id']).toList(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx, r.success);
                  },
                  child: const Text('Save policy',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Term release policy saved.')));
      _load();
    }
  }

  @override
  void dispose() {
    _msgCtl.dispose();
    super.dispose();
  }
}
