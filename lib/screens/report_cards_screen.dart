import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';
import 'report_card_detail_screen.dart';

/// Report Card list — session-anchored, gated exactly like the portal.
class ReportCardsScreen extends StatefulWidget {
  const ReportCardsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<ReportCardsScreen> createState() => _ReportCardsScreenState();
}

class _ReportCardsScreenState extends State<ReportCardsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _cards = const [];
  List<dynamic> _sessions = const [];
  int? _sessionId; // null until first response tells us the default

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    var path = '/me/report-cards';
    if (_sessionId != null) path += '?session_id=$_sessionId';
    final res = await widget.api.get(path);
    if (!mounted) return;
    if (!res.success) {
      setState(() { _loading = false; _error = res.friendlyError; });
      return;
    }
    setState(() {
      _loading = false;
      _cards = (res.data['report_cards'] as List?) ?? const [];
      _sessions = (res.data['sessions'] as List?) ?? const [];
      _sessionId ??= (res.meta['selected_session_id'] as num?)?.toInt();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: Column(children: [
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
    if (_cards.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 90),
        Icon(Icons.assessment_outlined, size: 52, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Center(child: Text('No published report card in this session yet.',
            style: TextStyle(color: Colors.grey.shade600))),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _cards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = _cards[i];
        final ok = (c['accessible'] as bool?) ?? false;
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            onTap: ok
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportCardDetailScreen(
                          api: widget.api,
                          termId: (c['term_id'] as num).toInt())),
                  )
                : () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${c['withheld_reason']}'))),
            title: Text('${c['term']} · ${c['session']}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${c['class']}', style: const TextStyle(fontSize: 12.5)),
            trailing: ok
                ? Column(mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${(c['average'] as num?)?.toStringAsFixed(1) ?? ''}%',
                          style: TextStyle(
                              color: Branding.primaryColor,
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      Text('Grade ${c['grade'] ?? ''} · ${_ord((c['position'] as num?)?.toInt() ?? 0)}',
                          style: const TextStyle(fontSize: 11.5)),
                    ])
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4D6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Withheld',
                        style: TextStyle(
                            color: Color(0xFF8A6D00),
                            fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
          ),
        );
      },
    );
  }

  String _ord(int n) {
    if (n <= 0) return '';
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' };
  }
}
