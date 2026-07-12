import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';

/// School events — upcoming first, then past (collapsed).
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _upcoming = const [];
  List<dynamic> _past = const [];
  bool _showPast = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final res = await widget.api.get('/me/events');
    if (!mounted) return;
    if (!res.success) {
      setState(() { _loading = false; _error = res.friendlyError; });
      return;
    }
    final all = (res.data['events'] as List?) ?? const [];
    final today = DateTime.now();
    final td = DateTime(today.year, today.month, today.day);
    final up = <dynamic>[];
    final past = <dynamic>[];
    for (final e in all) {
      DateTime? end;
      try {
        end = DateTime.parse('${e['end_date'] ?? e['start_date']}');
      } catch (_) {}
      if (end != null && end.isBefore(td)) {
        past.add(e);
      } else {
        up.add(e);
      }
    }
    up.sort((a, b) => '${a['start_date']}'.compareTo('${b['start_date']}'));
    setState(() { _loading = false; _upcoming = up; _past = past; });
  }

  String _fmtDate(String? d) {
    if (d == null || d.isEmpty) return '';
    try {
      final x = DateTime.parse(d);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${x.day} ${m[x.month - 1]} ${x.year}';
    } catch (_) { return d; }
  }

  String _fmtTime(String? t) {
    if (t == null || t.isEmpty) return '';
    final p = t.split(':');
    if (p.length < 2) return t;
    var h = int.tryParse(p[0]) ?? 0;
    final ap = h >= 12 ? 'PM' : 'AM';
    h = h % 12 == 0 ? 12 : h % 12;
    return '$h:${p[1]} $ap';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ListView(children: [
                  const SizedBox(height: 110),
                  Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Center(child: Text(_error!, style: TextStyle(color: Colors.grey.shade600))),
                  const SizedBox(height: 12),
                  Center(child: OutlinedButton(onPressed: _load, child: const Text('Try again'))),
                ])
              : _body(),
    );
  }

  Widget _body() {
    final children = <Widget>[];
    if (_upcoming.isEmpty && _past.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 110),
        Icon(Icons.event_outlined, size: 52, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Center(child: Text('No events scheduled.',
            style: TextStyle(color: Colors.grey.shade600))),
      ]);
    }
    if (_upcoming.isNotEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
        child: Text('UPCOMING',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                letterSpacing: 0.5, color: Colors.grey.shade600)),
      ));
      children.addAll(_upcoming.map((e) => _card(e, past: false)));
    }
    if (_past.isNotEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 2),
        child: Material(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _showPast = !_showPast),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(Icons.history, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 10),
                Expanded(child: Text('Past events (${_past.length})',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800))),
                Icon(_showPast ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade500),
              ]),
            ),
          ),
        ),
      ));
      if (_showPast) children.addAll(_past.map((e) => _card(e, past: true)));
    }
    return ListView(padding: const EdgeInsets.all(12), children: children);
  }

  Widget _card(dynamic e, {required bool past}) {
    final featured = (e['is_featured'] as bool?) ?? false;
    final sameDay = '${e['start_date']}' == '${e['end_date']}' ||
        '${e['end_date'] ?? ''}'.isEmpty;
    final dateText = sameDay
        ? _fmtDate('${e['start_date']}')
        : '${_fmtDate('${e['start_date']}')} — ${_fmtDate('${e['end_date']}')}';
    final timeText = [
      _fmtTime(e['start_time'] as String?),
      _fmtTime(e['end_time'] as String?)
    ].where((s) => s.isNotEmpty).join(' — ');

    return Opacity(
      opacity: past ? 0.7 : 1,
      child: Card(
        margin: const EdgeInsets.only(top: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: featured && !past
                  ? Branding.primaryColor.withOpacity(0.4)
                  : Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text('${e['title']}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
              ),
              if (featured)
                Icon(Icons.star, size: 18, color: const Color(0xFFB8860B)),
            ]),
            if ('${e['type'] ?? ''}'.isNotEmpty)
              Text('${e['type']}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(dateText, style: const TextStyle(fontSize: 13)),
              if (timeText.isNotEmpty) ...[
                const SizedBox(width: 12),
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(timeText, style: const TextStyle(fontSize: 13)),
              ],
            ]),
            if ('${e['venue'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 5),
              Row(children: [
                Icon(Icons.place_outlined, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Expanded(child: Text('${e['venue']}', style: const TextStyle(fontSize: 13))),
              ]),
            ],
            if ('${e['description'] ?? ''}'.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${e['description']}',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4, fontSize: 13.5)),
            ],
          ]),
        ),
      ),
    );
  }
}
