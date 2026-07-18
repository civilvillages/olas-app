import 'package:flutter/material.dart';
import '../../config/branding.dart';
import '../../core/api_client.dart';

/// Communication Center C1 — Announcements: list, full compose (audience,
/// channels, schedule, poll), publish/archive/delete, analytics.
class CommAnnouncementsScreen extends StatefulWidget {
  const CommAnnouncementsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<CommAnnouncementsScreen> createState() => _CommAnnouncementsScreenState();
}

class _CommAnnouncementsScreenState extends State<CommAnnouncementsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = const [];
  Map<String, dynamic>? _meta;
  String _status = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final meta = await widget.api.get('/staff/announcements/meta');
    if (!mounted) return;
    if (!meta.success) {
      setState(() { _loading = false; _error = meta.friendlyError; });
      return;
    }
    _meta = meta.data;
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    var path = '/staff/announcements';
    if (_status.isNotEmpty) path += '?status=$_status';
    final res = await widget.api.get(path);
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

  Color _prioColor(String p) => switch (p) {
        'critical' => Colors.red.shade600,
        'high' => const Color(0xFFFD7E14),
        'low' => Colors.grey.shade500,
        _ => Branding.primaryColor,
      };

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
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

    return Stack(children: [
      RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 80), children: [
          Wrap(spacing: 6, children: [
            for (final s in ['', 'draft', 'scheduled', 'published', 'archived'])
              ChoiceChip(
                label: Text(s.isEmpty ? 'All' : s[0].toUpperCase() + s.substring(1),
                    style: const TextStyle(fontSize: 12)),
                selected: _status == s,
                onSelected: (_) { setState(() => _status = s); _load(); },
              ),
          ]),
          const SizedBox(height: 6),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 50),
              child: Center(child: Text('No announcements here yet.',
                  style: TextStyle(color: Colors.grey.shade600))),
            ),
          ..._items.map(_card),
        ]),
      ),
      Positioned(
        right: 16, bottom: 16,
        child: FloatingActionButton.extended(
          backgroundColor: Branding.primaryColor,
          foregroundColor: Colors.white,
          onPressed: () => _openForm(null),
          icon: const Icon(Icons.add),
          label: const Text('New'),
        ),
      ),
    ]);
  }

  Widget _card(dynamic a) {
    final status = '${a['status']}';
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _detail(a),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (a['is_pinned'] == true)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.push_pin, size: 16, color: Colors.orange.shade700),
                ),
              Expanded(child: Text('${a['title']}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: _prioColor('${a['priority']}'),
                  shape: BoxShape.circle,
                ),
              ),
            ]),
            const SizedBox(height: 3),
            Text('${a['category']} · to ${a['audience_type']}'
                '${status == 'published' ? ' · ${a['recipient_count']} recipient(s)' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: [
              _chip(status, status == 'published' ? Branding.successColor
                  : status == 'scheduled' ? const Color(0xFF0D6EFD)
                  : status == 'archived' ? Colors.grey.shade500
                  : const Color(0xFFB8860B)),
              if (a['channel_email'] == true) _chip('email', Colors.grey.shade600),
              if (a['channel_sms'] == true) _chip('sms', Colors.grey.shade600),
              if (a['require_ack'] == true) _chip('ack required', Colors.grey.shade600),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(t, style: TextStyle(fontSize: 10.5, color: c,
            fontWeight: FontWeight.w600)),
      );

  Future<void> _detail(dynamic a) async {
    final status = '${a['status']}';
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text('${a['title']}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${a['category']} · $status'),
          ),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(ctx, 'edit')),
          if (status == 'draft' || status == 'scheduled')
            ListTile(leading: Icon(Icons.campaign, color: Branding.successColor),
                title: const Text('Publish now'),
                onTap: () => Navigator.pop(ctx, 'publish')),
          if (status == 'published')
            ListTile(leading: const Icon(Icons.archive_outlined),
                title: const Text('Archive'),
                onTap: () => Navigator.pop(ctx, 'archive')),
          ListTile(leading: const Icon(Icons.insights_outlined),
              title: const Text('Analytics'),
              onTap: () => Navigator.pop(ctx, 'analytics')),
          ListTile(leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
              title: Text('Delete', style: TextStyle(color: Colors.red.shade700)),
              onTap: () => Navigator.pop(ctx, 'delete')),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit': _openForm(a); break;
      case 'publish': _lifecycle(a, 'publish',
          'Publish now? Recipients are resolved and email/SMS queued per its channels.'); break;
      case 'archive': _lifecycle(a, 'archive', 'Archive this announcement?'); break;
      case 'delete': _delete(a); break;
      case 'analytics': _analytics(a); break;
    }
  }

  Future<void> _lifecycle(dynamic a, String action, String msg) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${a['title']}'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    final res = await widget.api.post('/staff/announcements/${a['id']}/$action', body: {});
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.success
        ? (action == 'publish'
            ? 'Published to ${res.data['recipients'] ?? 0} recipient(s).'
            : 'Archived.')
        : res.friendlyError)));
    if (res.success) _load();
  }

  Future<void> _delete(dynamic a) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete announcement?'),
        content: Text('"${a['title']}" is removed permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final res = await widget.api.delete('/staff/announcements/${a['id']}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.success ? 'Deleted.' : res.friendlyError)));
    if (res.success) _load();
  }

  Future<void> _analytics(dynamic a) async {
    final res = await widget.api.get('/staff/announcements/${a['id']}/analytics');
    if (!mounted) return;
    if (!res.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.friendlyError)));
      return;
    }
    final data = res.data['analytics'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a['title']} — analytics',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 10),
            if (data is Map)
              ...data.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Expanded(child: Text('${e.key}'.replaceAll('_', ' '),
                          style: const TextStyle(fontSize: 13.5))),
                      Text('${e.value}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  ))
            else
              Text('No analytics yet.',
                  style: TextStyle(color: Colors.grey.shade600)),
          ]),
        ),
      ),
    );
  }

  Future<void> _openForm(dynamic existing) async {
    Map<String, dynamic>? full;
    if (existing != null) {
      final res = await widget.api.get('/staff/announcements/${existing['id']}');
      if (!mounted) return;
      if (!res.success) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res.friendlyError)));
        return;
      }
      full = (res.data['announcement'] as Map?)?.cast<String, dynamic>();
    }
    if (_meta == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _AnnouncementFormScreen(
          api: widget.api, meta: _meta!, existing: full)),
    );
    if (saved == true) _load();
  }
}

/// The full compose form — everything the portal's form carries.
class _AnnouncementFormScreen extends StatefulWidget {
  const _AnnouncementFormScreen({required this.api, required this.meta, this.existing});
  final ApiClient api;
  final Map<String, dynamic> meta;
  final Map<String, dynamic>? existing;

  @override
  State<_AnnouncementFormScreen> createState() => _AnnouncementFormScreenState();
}

class _AnnouncementFormScreenState extends State<_AnnouncementFormScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _publishAt;
  late final TextEditingController _expiresAt;
  late final TextEditingController _pollQ;
  late final TextEditingController _pollCloses;
  String _category = 'General';
  String _priority = 'medium';
  String _audience = 'all';
  bool _email = false, _sms = false, _ack = false, _pin = false;
  bool _reactions = true, _comments = true;
  final Set<String> _roles = {};
  final Set<int> _classes = {};
  final Set<int> _arms = {};
  final Set<int> _levels = {};
  final Set<int> _users = {};
  final List<TextEditingController> _pollOpts = [];
  bool _pollMulti = false;
  bool _hadPoll = false;
  bool _clearPoll = false;
  bool _saving = false;
  String _staffSearch = '';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?['title'] ?? '');
    _body = TextEditingController(text: e?['body'] ?? '');
    _publishAt = TextEditingController(text: e?['publish_at'] ?? '');
    _expiresAt = TextEditingController(text: e?['expires_at'] ?? '');
    final poll = e?['poll'] as Map?;
    _pollQ = TextEditingController(text: poll?['question'] ?? '');
    _pollCloses = TextEditingController(text: poll?['closes_at'] ?? '');
    if (e != null) {
      _category = '${e['category'] ?? 'General'}';
      _priority = '${e['priority'] ?? 'medium'}';
      _audience = '${e['audience_type'] ?? 'all'}';
      _email = e['channel_email'] == true;
      _sms = e['channel_sms'] == true;
      _ack = e['require_ack'] == true;
      _pin = e['is_pinned'] == true;
      _reactions = e['allow_reactions'] == true;
      _comments = e['allow_comments'] == true;
      final t = (e['targets'] as Map?) ?? const {};
      for (final v in (t['role'] as List? ?? const [])) _roles.add('$v');
      for (final v in (t['class'] as List? ?? const [])) _classes.add(int.tryParse('$v') ?? 0);
      for (final v in (t['arm'] as List? ?? const [])) _arms.add(int.tryParse('$v') ?? 0);
      for (final v in (t['level'] as List? ?? const [])) _levels.add(int.tryParse('$v') ?? 0);
      for (final v in (t['user'] as List? ?? const [])) _users.add(int.tryParse('$v') ?? 0);
      if (poll != null) {
        _hadPoll = true;
        _pollMulti = poll['multi'] == true;
        for (final o in (poll['options'] as List? ?? const [])) {
          _pollOpts.add(TextEditingController(text: '$o'));
        }
      }
    }
    final cats = (widget.meta['categories'] as List?) ?? const [];
    if (!cats.contains(_category)) _category = cats.isNotEmpty ? '${cats.first}' : 'General';
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.meta;
    final isEdit = widget.existing != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Branding.primaryColor,
        foregroundColor: Colors.white,
        title: Text(isEdit ? 'Edit announcement' : 'New announcement'),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _title, decoration: _dec('Title *')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            value: _category,
            isExpanded: true,
            decoration: _dec('Category'),
            items: ((meta['categories'] as List?) ?? const ['General'])
                .map<DropdownMenuItem<String>>((c) =>
                    DropdownMenuItem(value: '$c', child: Text('$c'))).toList(),
            onChanged: (v) => setState(() => _category = v ?? 'General'),
          )),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(
            value: _priority,
            decoration: _dec('Priority'),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Low')),
              DropdownMenuItem(value: 'medium', child: Text('Medium')),
              DropdownMenuItem(value: 'high', child: Text('High')),
              DropdownMenuItem(value: 'critical', child: Text('Critical')),
            ],
            onChanged: (v) => setState(() => _priority = v ?? 'medium'),
          )),
        ]),
        const SizedBox(height: 12),
        TextField(controller: _body, maxLines: 6,
            decoration: _dec('Message body *')),
        const SizedBox(height: 14),

        Text('AUDIENCE', style: _h()),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _audience,
          decoration: _dec('Send to'),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Everyone')),
            DropdownMenuItem(value: 'role', child: Text('Selected roles')),
            DropdownMenuItem(value: 'level', child: Text('Selected levels')),
            DropdownMenuItem(value: 'class', child: Text('Selected classes')),
            DropdownMenuItem(value: 'arm', child: Text('Selected arms')),
            DropdownMenuItem(value: 'individual', child: Text('Individual staff')),
          ],
          onChanged: (v) => setState(() => _audience = v ?? 'all'),
        ),
        const SizedBox(height: 8),
        if (_audience == 'role')
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final r in (meta['roles'] as List? ?? const []))
              FilterChip(
                label: Text('${r['name']}', style: const TextStyle(fontSize: 12)),
                selected: _roles.contains('${r['slug']}'),
                onSelected: (v) => setState(() =>
                    v ? _roles.add('${r['slug']}') : _roles.remove('${r['slug']}')),
              ),
          ]),
        if (_audience == 'level') _idChips(meta['levels'], _levels),
        if (_audience == 'class') _idChips(meta['classes'], _classes),
        if (_audience == 'arm') _idChips(meta['arms'], _arms),
        if (_audience == 'individual') ...[
          TextField(
            decoration: _dec('Search staff'),
            onChanged: (v) => setState(() => _staffSearch = v.toLowerCase()),
          ),
          const SizedBox(height: 6),
          ...((meta['staff'] as List? ?? const [])
              .where((s) => _staffSearch.isEmpty ||
                  '${s['name']}'.toLowerCase().contains(_staffSearch))
              .take(30)
              .map((s) {
            final id = (s['id'] as num).toInt();
            return CheckboxListTile(
              dense: true,
              value: _users.contains(id),
              onChanged: (v) => setState(() =>
                  v == true ? _users.add(id) : _users.remove(id)),
              title: Text('${s['name']}', style: const TextStyle(fontSize: 13)),
            );
          })),
        ],
        const SizedBox(height: 12),

        Text('DELIVERY & BEHAVIOUR', style: _h()),
        _toggle('Also send by email', _email, (v) => _email = v),
        _toggle('Also send by SMS', _sms, (v) => _sms = v),
        _toggle('Require acknowledgement', _ack, (v) => _ack = v),
        _toggle('Pin to the top', _pin, (v) => _pin = v),
        _toggle('Allow reactions', _reactions, (v) => _reactions = v),
        _toggle('Allow comments', _comments, (v) => _comments = v),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: _publishAt,
              decoration: _dec('Publish at (optional)', hint: 'YYYY-MM-DD HH:MM'))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _expiresAt,
              decoration: _dec('Expires at (optional)', hint: 'YYYY-MM-DD HH:MM'))),
        ]),
        const SizedBox(height: 14),

        Text('POLL (OPTIONAL)', style: _h()),
        const SizedBox(height: 6),
        TextField(controller: _pollQ, decoration: _dec('Poll question')),
        const SizedBox(height: 6),
        for (var i = 0; i < _pollOpts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Expanded(child: TextField(controller: _pollOpts[i],
                  decoration: _dec('Option ${i + 1}'))),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
                onPressed: () => setState(() => _pollOpts.removeAt(i).dispose()),
              ),
            ]),
          ),
        Row(children: [
          TextButton.icon(
            onPressed: () => setState(() => _pollOpts.add(TextEditingController())),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add option'),
          ),
          const Spacer(),
          const Text('Multiple votes', style: TextStyle(fontSize: 12.5)),
          Switch(value: _pollMulti, onChanged: (v) => setState(() => _pollMulti = v)),
        ]),
        TextField(controller: _pollCloses,
            decoration: _dec('Poll closes at (optional)', hint: 'YYYY-MM-DD HH:MM')),
        if (_hadPoll)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _clearPoll,
            onChanged: (v) => setState(() => _clearPoll = v ?? false),
            title: const Text('Remove the existing poll',
                style: TextStyle(fontSize: 13)),
          ),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: _saving ? null : () => _save('draft'),
            child: const Text('Save draft'),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(
            onPressed: _saving ? null : () => _save('schedule'),
            child: const Text('Schedule'),
          )),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Branding.successColor,
              foregroundColor: Colors.white,
            ),
            onPressed: _saving ? null : () => _save('publish'),
            child: Text(_saving ? '…' : 'Publish'),
          )),
        ]),
        const SizedBox(height: 8),
        Text('Attachments are added on the web portal for now.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ]),
    );
  }

  Widget _idChips(dynamic list, Set<int> sel) => Wrap(spacing: 6, runSpacing: 6, children: [
        for (final x in (list as List? ?? const []))
          FilterChip(
            label: Text('${x['name']}', style: const TextStyle(fontSize: 12)),
            selected: sel.contains((x['id'] as num).toInt()),
            onSelected: (v) => setState(() {
              final id = (x['id'] as num).toInt();
              v ? sel.add(id) : sel.remove(id);
            }),
          ),
      ]);

  Widget _toggle(String label, bool v, void Function(bool) set) => SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        value: v,
        onChanged: (x) => setState(() => set(x)),
        title: Text(label, style: const TextStyle(fontSize: 13.5)),
      );

  TextStyle _h() => TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
      letterSpacing: 0.5, color: Colors.grey.shade600);

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Future<void> _save(String action) async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title and message body are required.')));
      return;
    }
    if (action == 'publish') {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Publish this announcement?'),
          content: Text('Audience: ${_audienceSummary()}. '
              '${_email || _sms ? 'Email/SMS will be queued per the toggles.' : ''}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Publish')),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'body': _body.text.trim(),
      'category': _category,
      'priority': _priority,
      'audience_type': _audience,
      'channel_email': _email,
      'channel_sms': _sms,
      'require_ack': _ack,
      'is_pinned': _pin,
      'allow_reactions': _reactions,
      'allow_comments': _comments,
      'publish_at': _publishAt.text.trim(),
      'expires_at': _expiresAt.text.trim(),
      'roles': _roles.toList(),
      'classes': _classes.toList(),
      'arms': _arms.toList(),
      'levels': _levels.toList(),
      'users': _users.toList(),
      'poll_question': _clearPoll ? '' : _pollQ.text.trim(),
      'poll_options': _clearPoll
          ? []
          : _pollOpts.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList(),
      'poll_multi': _pollMulti,
      'poll_closes_at': _pollCloses.text.trim(),
      if (_clearPoll) 'poll_clear': true,
      'action': action,
    };
    final e = widget.existing;
    final res = e == null
        ? await widget.api.post('/staff/announcements', body: body)
        : await widget.api.put('/staff/announcements/${e['id']}', body: body);
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.success) {
      if (action == 'publish') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
            'Published to ${res.data['recipients'] ?? 0} recipient(s).')));
      }
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.friendlyError)));
    }
  }

  String _audienceSummary() => switch (_audience) {
        'all' => 'everyone',
        'role' => '${_roles.length} role(s)',
        'level' => '${_levels.length} level(s)',
        'class' => '${_classes.length} class(es)',
        'arm' => '${_arms.length} arm(s)',
        _ => '${_users.length} individual(s)',
      };

  @override
  void dispose() {
    for (final c in [_title, _body, _publishAt, _expiresAt, _pollQ, _pollCloses, ..._pollOpts]) {
      c.dispose();
    }
    super.dispose();
  }
}
