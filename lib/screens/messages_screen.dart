import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';

/// Messages — shared by student and staff shells. Inbox, chat thread,
/// compose (policy-scoped recipients; staff can broadcast to a class/level).
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _threads = const [];
  bool _canStartNew = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await widget.api.get('/me/messages');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        _threads = (res.data['threads'] as List?) ?? const [];
        _canStartNew = res.data['can_start_new'] == true;
        _error = null;
      } else {
        _error = res.friendlyError;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.forum_outlined, size: 44, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(_error!, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: const Text('Try again')),
        ]),
      ));
    }
    return Stack(children: [
      RefreshIndicator(
        onRefresh: _load,
        child: _threads.isEmpty
            ? ListView(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 90),
                  child: Column(children: [
                    Icon(Icons.forum_outlined, size: 52, color: Colors.grey.shade300),
                    const SizedBox(height: 10),
                    Text('No conversations yet.',
                        style: TextStyle(color: Colors.grey.shade600)),
                    if (_canStartNew)
                      Text('Tap New message to start one.',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
                  ]),
                ),
              ])
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
                itemCount: _threads.length,
                itemBuilder: (ctx, i) => _threadCard(_threads[i]),
              ),
      ),
      if (_canStartNew)
        Positioned(
          right: 16, bottom: 16,
          child: FloatingActionButton.extended(
            backgroundColor: Branding.primaryColor,
            foregroundColor: Colors.white,
            onPressed: _compose,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('New message'),
          ),
        ),
    ]);
  }

  Widget _threadCard(dynamic t) {
    final unread = (t['unread'] as num?)?.toInt() ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: unread > 0
            ? Branding.primaryColor.withOpacity(0.4) : Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Branding.primaryColor.withOpacity(0.1),
          child: Text('${t['other_name']}'.isNotEmpty ? '${t['other_name']}'[0] : '?',
              style: TextStyle(color: Branding.primaryColor,
                  fontWeight: FontWeight.w800)),
        ),
        title: Row(children: [
          Expanded(child: Text('${t['other_name']}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14.5,
                  fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600))),
          Text('${t['other_role']}',
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ('${t['about_name'] ?? ''}'.isNotEmpty)
            Text('About ${t['about_name']}',
                style: TextStyle(fontSize: 11, color: Branding.primaryColor)),
          Text('${t['last_body']}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5,
                  fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400)),
        ]),
        trailing: unread > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Branding.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$unread',
                    style: const TextStyle(color: Colors.white, fontSize: 11.5,
                        fontWeight: FontWeight.w800)),
              )
            : null,
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(
              builder: (_) => _ThreadScreen(api: widget.api,
                  conversationId: (t['id'] as num).toInt())));
          _load();
        },
      ),
    );
  }

  Future<void> _compose() async {
    final sent = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => _ComposeScreen(api: widget.api)));
    if (sent == true) _load();
  }
}

/// One conversation — chat bubbles + reply box.
class _ThreadScreen extends StatefulWidget {
  const _ThreadScreen({required this.api, required this.conversationId});
  final ApiClient api;
  final int conversationId;

  @override
  State<_ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<_ThreadScreen> {
  bool _loading = true;
  Map<String, dynamic> _conv = const {};
  List<dynamic> _messages = const [];
  final _replyCtl = TextEditingController();
  final _scrollCtl = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await widget.api.get('/me/messages/${widget.conversationId}');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        _conv = (res.data['conversation'] as Map?)?.cast<String, dynamic>() ?? const {};
        _messages = (res.data['messages'] as List?) ?? const [];
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res.friendlyError)));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtl.hasClients) {
        _scrollCtl.jumpTo(_scrollCtl.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final oversight = _conv['oversight_only'] == true;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Branding.primaryColor,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_conv['other_name'] ?? 'Conversation'}',
              style: const TextStyle(fontSize: 16)),
          Text('${_conv['other_role'] ?? ''}'
              '${'${_conv['about_name'] ?? ''}'.isNotEmpty ? ' · about ${_conv['about_name']}' : ''}',
              style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              if (oversight)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  color: const Color(0xFFFFF4D6),
                  child: const Text(
                      'Oversight view — you are reading as an administrator and cannot reply.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF8A6D00))),
                ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtl,
                  padding: const EdgeInsets.all(14),
                  itemCount: _messages.length,
                  itemBuilder: (ctx, i) => _bubble(_messages[i]),
                ),
              ),
              if (!oversight)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                    child: Row(children: [
                      Expanded(child: TextField(
                        controller: _replyCtl,
                        minLines: 1, maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Write a message…',
                          filled: true, fillColor: Colors.white,
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                        ),
                      )),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Branding.primaryColor,
                        child: _sending
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : IconButton(
                                icon: const Icon(Icons.send, size: 18, color: Colors.white),
                                onPressed: _send,
                              ),
                      ),
                    ]),
                  ),
                ),
            ]),
    );
  }

  Widget _bubble(dynamic m) {
    final mine = m['mine'] == true;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: mine ? Branding.primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 3),
            bottomRight: Radius.circular(mine ? 3 : 14),
          ),
          border: mine ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${m['body']}',
                style: TextStyle(fontSize: 14,
                    color: mine ? Colors.white : Colors.black87)),
            const SizedBox(height: 2),
            Text('${m['created_at'] ?? ''}',
                style: TextStyle(fontSize: 9.5,
                    color: mine ? Colors.white70 : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _replyCtl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final res = await widget.api.post(
        '/me/messages/${widget.conversationId}/reply', body: {'body': text});
    if (!mounted) return;
    setState(() => _sending = false);
    if (res.success) {
      _replyCtl.clear();
      _load();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.friendlyError)));
    }
  }

  @override
  void dispose() {
    _replyCtl.dispose();
    _scrollCtl.dispose();
    super.dispose();
  }
}

/// Compose — policy-scoped recipient picker; staff get class/level broadcast.
class _ComposeScreen extends StatefulWidget {
  const _ComposeScreen({required this.api});
  final ApiClient api;

  @override
  State<_ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<_ComposeScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _recipients = const [];
  Map<String, dynamic> _groups = const {};
  List<dynamic> _children = const [];
  String _mode = 'single'; // single | broadcast
  int? _toUserId;
  String? _toGroup;
  int? _aboutStudentId;
  String _search = '';
  final _subject = TextEditingController();
  final _body = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final res = await widget.api.get('/me/messages/meta');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        _recipients = (res.data['recipients'] as List?) ?? const [];
        _groups = (res.data['groups'] as Map?)?.cast<String, dynamic>() ?? const {};
        _children = (res.data['children'] as List?) ?? const [];
        if (res.data['can_start_new'] != true) {
          _error = 'Starting new conversations is currently disabled.';
        }
      } else {
        _error = res.friendlyError;
      }
    });
  }

  bool get _hasGroups =>
      ((_groups['classes'] as List?)?.isNotEmpty ?? false) ||
      ((_groups['levels'] as List?)?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Branding.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('New message'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(_error!, textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600))))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  if (_hasGroups) ...[
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'single', label: Text('One person')),
                        ButtonSegment(value: 'broadcast', label: Text('Whole class/level')),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) => setState(() => _mode = s.first),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_mode == 'single') ..._singleFields(),
                  if (_mode == 'broadcast') ..._broadcastFields(),
                  const SizedBox(height: 12),
                  TextField(controller: _subject,
                      decoration: _dec('Subject (optional)')),
                  const SizedBox(height: 10),
                  TextField(controller: _body, maxLines: 5,
                      decoration: _dec('Message *')),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Branding.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send, size: 18),
                      label: const Text('Send',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
    );
  }

  List<Widget> _singleFields() {
    final filtered = _recipients.where((r) =>
        _search.isEmpty ||
        '${r['name']}'.toLowerCase().contains(_search) ||
        '${r['role']}'.toLowerCase().contains(_search)).toList();
    return [
      TextField(
        decoration: _dec('Search people'),
        onChanged: (v) => setState(() => _search = v.toLowerCase()),
      ),
      const SizedBox(height: 6),
      ...filtered.take(25).map((r) {
        final id = (r['id'] as num).toInt();
        final label = [
          '${r['role']}',
          if ('${r['class_name'] ?? ''}'.isNotEmpty) '${r['class_name']}',
        ].join(' · ');
        return RadioListTile<int>(
          dense: true,
          value: id,
          groupValue: _toUserId,
          onChanged: (v) => setState(() => _toUserId = v),
          title: Text('${r['name']}', style: const TextStyle(fontSize: 13.5)),
          subtitle: Text(label, style: const TextStyle(fontSize: 11.5)),
        );
      }),
      if (filtered.length > 25)
        Text('Showing 25 of ${filtered.length} — refine the search.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
      if (_children.isNotEmpty) ...[
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: _aboutStudentId,
          decoration: _dec('About which child? (optional)'),
          items: [
            const DropdownMenuItem<int>(value: 0, child: Text('— none —')),
            ..._children.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(
                  value: (c['student_id'] as num).toInt(),
                  child: Text('${c['name']}'),
                )),
          ],
          onChanged: (v) => setState(() => _aboutStudentId = (v == 0) ? null : v),
        ),
      ],
    ];
  }

  List<Widget> _broadcastFields() {
    return [
      Text('Each student gets their own private conversation with you — replies stay one-to-one.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      const SizedBox(height: 8),
      if (((_groups['classes'] as List?) ?? const []).isNotEmpty) ...[
        const Text('Classes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final c in (_groups['classes'] as List))
            ChoiceChip(
              label: Text('${c['name']}', style: const TextStyle(fontSize: 12)),
              selected: _toGroup == 'class:${c['id']}',
              onSelected: (_) => setState(() => _toGroup = 'class:${c['id']}'),
            ),
        ]),
      ],
      if (((_groups['levels'] as List?) ?? const []).isNotEmpty) ...[
        const SizedBox(height: 6),
        const Text('Levels', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final l in (_groups['levels'] as List))
            ChoiceChip(
              label: Text('${l['name']}', style: const TextStyle(fontSize: 12)),
              selected: _toGroup == 'level:${l['id']}',
              onSelected: (_) => setState(() => _toGroup = 'level:${l['id']}'),
            ),
        ]),
      ],
    ];
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Future<void> _send() async {
    if (_body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Write a message first.')));
      return;
    }
    if (_mode == 'single' && _toUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick a recipient.')));
      return;
    }
    if (_mode == 'broadcast' && _toGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick a class or level.')));
      return;
    }
    setState(() => _sending = true);
    final res = await widget.api.post('/me/messages', body: {
      if (_mode == 'single') 'to_user_id': _toUserId,
      if (_mode == 'broadcast') 'to_group': _toGroup,
      if (_aboutStudentId != null) 'about_student_id': _aboutStudentId,
      'subject': _subject.text.trim(),
      'body': _body.text.trim(),
    });
    if (!mounted) return;
    setState(() => _sending = false);
    if (res.success) {
      final sent = (res.data['sent'] as num?)?.toInt();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          sent != null ? 'Sent to $sent student(s).' : 'Message sent.')));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.friendlyError)));
    }
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }
}
