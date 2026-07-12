import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';

/// Announcements — pinned first, priority badges, unread markers.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final res = await widget.api.get('/me/announcements');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        _items = (res.data['announcements'] as List?) ?? const [];
      } else {
        _error = res.friendlyError;
      }
    });
  }

  Color _prio(String p) => switch (p) {
        'critical' => Colors.red.shade700,
        'high' => const Color(0xFFD35400),
        'medium' => Branding.primaryColor,
        _ => Colors.grey.shade600,
      };

  String _strip(String html) => html
      .replaceAll(RegExp(r'<br\s*/?>'), '\n')
      .replaceAll(RegExp(r'</(div|p|tr)>'), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .trim();

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
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ListView(children: [
                  const SizedBox(height: 110),
                  Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Center(child: Text(_error!, textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600))),
                  const SizedBox(height: 12),
                  Center(child: OutlinedButton(onPressed: _load, child: const Text('Try again'))),
                ])
              : _items.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 110),
                      Icon(Icons.campaign_outlined, size: 52, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Center(child: Text('No announcements right now.',
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

  Widget _card(dynamic a) {
    final pinned = (a['is_pinned'] as bool?) ?? false;
    final read = (a['read'] as bool?) ?? false;
    final prio = '${a['priority'] ?? 'low'}';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: pinned ? Branding.primaryColor.withOpacity(0.4) : Colors.grey.shade200),
      ),
      child: ExpansionTile(
        shape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: read
            ? null
            : Container(
                width: 9, height: 9,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                    color: Branding.primaryColor, shape: BoxShape.circle)),
        title: Row(children: [
          if (pinned)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.push_pin, size: 15, color: Branding.primaryColor),
            ),
          Expanded(
            child: Text('${a['title']}',
                style: TextStyle(
                    fontWeight: read ? FontWeight.w500 : FontWeight.w700,
                    fontSize: 15)),
          ),
        ]),
        subtitle: Text(
            '${a['category'] ?? ''} · ${_fmtDate(a['published_at'] as String?)}',
            style: const TextStyle(fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _prio(prio).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(prio,
              style: TextStyle(
                  color: _prio(prio), fontSize: 11, fontWeight: FontWeight.w600)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_strip('${a['body_html'] ?? ''}'),
                  style: const TextStyle(height: 1.45)),
            ),
          ),
        ],
      ),
    );
  }
}
