import 'package:flutter/material.dart';
import '../../config/branding.dart';
import '../../core/api_client.dart';
import '../../core/score_cache.dart';

/// Offline-first score entry: student-by-student, big fields, auto-save.
/// Submitting freezes the batch (THE LOCK) until the server confirms the sync.
class ScoreEntryScreen extends StatefulWidget {
  const ScoreEntryScreen({super.key, required this.api, required this.cacheKey});
  final ApiClient api;
  final String cacheKey;

  @override
  State<ScoreEntryScreen> createState() => _ScoreEntryScreenState();
}

class _ScoreEntryScreenState extends State<ScoreEntryScreen> {
  Map<String, dynamic> _bundle = const {};
  Map<String, String> _draft = {};
  bool _locked = false; // pending batch exists
  bool _loading = true;
  bool _syncing = false;
  int _index = 0;
  final _pageCtl = PageController();
  final Map<String, TextEditingController> _ctls = {};

  List<dynamic> get _students => (_bundle['students'] as List?) ?? const [];
  List<dynamic> get _components => (_bundle['components'] as List?) ?? const [];

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    _bundle = await ScoreCache.bundle(widget.cacheKey) ?? const {};
    _draft = await ScoreCache.draft(widget.cacheKey);
    _locked = (await ScoreCache.pending(widget.cacheKey)) != null;
    if (_locked) _trySync(auto: true);
    setState(() => _loading = false);
  }

  String _dk(int studentId, int componentId) => '$studentId:$componentId';

  /// Effective value: draft first, else the server's existing score.
  String _valueFor(int studentId, int componentId) {
    final d = _draft[_dk(studentId, componentId)];
    if (d != null) return d;
    final st = _students.cast<Map>().where((s) => s['student_id'] == studentId);
    if (st.isEmpty) return '';
    final scores = st.first['scores'];
    if (scores is Map) {
      final v = scores['$componentId'];
      if (v != null) return '${v is num && v == v.roundToDouble() ? v.toInt() : v}';
    }
    return '';
  }

  int get _enteredCount {
    var n = 0;
    for (final s in _students) {
      final sid = (s['student_id'] as num).toInt();
      final complete = _components.every((c) =>
          _valueFor(sid, (c['id'] as num).toInt()).trim().isNotEmpty);
      if (complete) n++;
    }
    return n;
  }

  Future<void> _saveDraft() async => ScoreCache.saveDraft(widget.cacheKey, _draft);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Branding.primaryColor,
            foregroundColor: Colors.white, title: const Text('Score Entry')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final cls = (_bundle['class'] as Map?) ?? const {};
    final subj = (_bundle['subject'] as Map?) ?? const {};
    final term = (_bundle['term'] as Map?) ?? const {};

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Branding.primaryColor,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${subj['name'] ?? 'Score Entry'}',
              style: const TextStyle(fontSize: 16)),
          Text('${cls['name'] ?? ''} · ${term['name'] ?? ''}',
              style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_view),
            tooltip: 'Overview',
            onPressed: _overview,
          ),
        ],
      ),
      body: Column(children: [
        // progress
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _students.isEmpty ? 0 : _enteredCount / _students.length,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  color: Branding.successColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('$_enteredCount of ${_students.length}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
        if (_locked) _lockBanner(),
        Expanded(
          child: PageView.builder(
            controller: _pageCtl,
            physics: _locked ? const NeverScrollableScrollPhysics() : null,
            itemCount: _students.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _studentPage(_students[i]),
          ),
        ),
        _bottomBar(),
      ]),
    );
  }

  Widget _lockBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.lock_clock, size: 20, color: Color(0xFF8A6D00)),
        const SizedBox(width: 10),
        Expanded(child: Text(
          _syncing
              ? 'Syncing to the school server…'
              : 'This batch was submitted and is waiting to sync. Entry is locked to prevent duplicates — tap Sync now when you have network.',
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A6D00)),
        )),
      ]),
    );
  }

  Widget _studentPage(dynamic s) {
    final sid = (s['student_id'] as num).toInt();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Center(child: CircleAvatar(
        radius: 30,
        backgroundColor: Branding.primaryColor.withOpacity(0.1),
        child: Text('${s['name']}'.isNotEmpty ? '${s['name']}'[0] : '?',
            style: TextStyle(fontSize: 24, color: Branding.primaryColor,
                fontWeight: FontWeight.w800)),
      )),
      const SizedBox(height: 8),
      Center(child: Text('${s['name']}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
      Center(child: Text('${s['admission_number'] ?? ''}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5))),
      const SizedBox(height: 18),
      ..._components.map((c) => _componentField(sid, c)),
    ]);
  }

  Widget _componentField(int sid, dynamic c) {
    final cid = (c['id'] as num).toInt();
    final max = (c['max_score'] as num?) ?? 0;
    final key = _dk(sid, cid);
    final ctl = _ctls.putIfAbsent(key, () {
      final t = TextEditingController(text: _valueFor(sid, cid));
      return t;
    });
    // Keep controller in sync if draft was updated elsewhere
    final want = _valueFor(sid, cid);
    if (ctl.text != want && !_ctls.containsKey('$key:touched')) {
      ctl.text = want;
    }

    final v = double.tryParse(ctl.text.trim());
    final over = v != null && max > 0 && v > max.toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctl,
        enabled: !_locked,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          labelText: '${c['label']} (max ${max == max.roundToDouble() ? max.toInt() : max})',
          helperText: '${c['full_name'] ?? ''}',
          errorText: over ? 'Above the maximum of $max' : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.all(16),
        ),
        onChanged: (t) {
          _ctls['$key:touched'] = ctl;
          _draft[key] = t.trim();
          _saveDraft();
          setState(() {});
        },
      ),
    );
  }

  Widget _bottomBar() {
    final last = _index >= _students.length - 1;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Row(children: [
          OutlinedButton(
            onPressed: _index == 0 || _locked
                ? null
                : () => _pageCtl.previousPage(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut),
            child: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _locked
                ? ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Branding.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _syncing ? null : () => _trySync(),
                    icon: _syncing
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.sync, size: 20),
                    label: const Text('Sync now',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  )
                : last
                    ? ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Branding.successColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _submit,
                        icon: const Icon(Icons.cloud_upload, size: 20),
                        label: const Text('Submit all scores',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Branding.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _pageCtl.nextPage(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut),
                        child: const Text('Next student',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: last || _locked
                ? null
                : () => _pageCtl.nextPage(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut),
            child: const Icon(Icons.chevron_right),
          ),
        ]),
      ),
    );
  }

  void _overview() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _students.length,
        itemBuilder: (ctx, i) {
          final s = _students[i];
          final sid = (s['student_id'] as num).toInt();
          final complete = _components.every((c) =>
              _valueFor(sid, (c['id'] as num).toInt()).trim().isNotEmpty);
          final partial = !complete && _components.any((c) =>
              _valueFor(sid, (c['id'] as num).toInt()).trim().isNotEmpty);
          return ListTile(
            dense: true,
            leading: Icon(
              complete ? Icons.check_circle
                  : partial ? Icons.timelapse : Icons.radio_button_unchecked,
              color: complete ? Branding.successColor
                  : partial ? const Color(0xFFB8860B) : Colors.grey.shade400,
              size: 20,
            ),
            title: Text('${s['name']}', style: const TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pop(ctx);
              _pageCtl.jumpToPage(i);
            },
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    final entered = _enteredCount;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit scores?'),
        content: Text(
            '$entered of ${_students.length} students are fully entered. '
            'After submitting, entry locks until the scores reach the school server. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep editing')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit')),
        ],
      ),
    );
    if (yes != true || !mounted) return;

    // Build the batch from every non-empty value (draft over existing).
    final term = (_bundle['term'] as Map?) ?? const {};
    final cls = (_bundle['class'] as Map?) ?? const {};
    final subj = (_bundle['subject'] as Map?) ?? const {};
    final items = <Map<String, dynamic>>[];
    for (final s in _students) {
      final sid = (s['student_id'] as num).toInt();
      for (final c in _components) {
        final cid = (c['id'] as num).toInt();
        final v = _valueFor(sid, cid).trim();
        if (v.isEmpty) continue;
        items.add({'student_id': sid, 'component_id': cid, 'score': v});
      }
    }
    final batch = {
      'class_id': (cls['id'] as num?)?.toInt(),
      'subject_id': (subj['id'] as num?)?.toInt(),
      'term_id': (term['id'] as num?)?.toInt(),
      'session_id': (term['session_id'] as num?)?.toInt(),
      'batch_id': '${widget.cacheKey}:${DateTime.now().millisecondsSinceEpoch}',
      'scores': items,
    };
    await ScoreCache.savePending(widget.cacheKey, batch);
    setState(() => _locked = true);
    _trySync();
  }

  Future<void> _trySync({bool auto = false}) async {
    final batch = await ScoreCache.pending(widget.cacheKey);
    if (batch == null) return;
    setState(() => _syncing = true);
    final res = await widget.api.post('/staff/scores/sync', body: batch);
    if (!mounted) return;
    setState(() => _syncing = false);

    if (res.success) {
      await ScoreCache.clearPending(widget.cacheKey);
      await ScoreCache.clearDraft(widget.cacheKey);
      final saved = (res.data['saved'] as num?)?.toInt() ?? 0;
      final rejected = ((res.data['verdicts'] as List?) ?? const [])
          .where((v) => v['status'] == 'rejected').toList();
      setState(() => _locked = false);
      // Refresh the bundle so fields show the server's truth.
      final fresh = await widget.api.get(
          '/staff/scores/bundle?class_id=${batch['class_id']}&subject_id=${batch['subject_id']}&term_id=${batch['term_id']}');
      if (fresh.success) {
        await ScoreCache.saveBundle(widget.cacheKey, fresh.data);
        _bundle = fresh.data;
        _ctls.clear();
        setState(() {});
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(rejected.isEmpty
            ? '$saved score(s) synced to the school server.'
            : '$saved saved; ${rejected.length} rejected (out of range or invalid). Fix and resubmit.'),
        duration: const Duration(seconds: 4),
      ));
    } else if (!auto) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.friendlyError.contains('connect') ||
                res.friendlyError.contains('internet')
            ? 'Still offline — the batch is safe on this phone. Sync when you have network.'
            : res.friendlyError),
        duration: const Duration(seconds: 4),
      ));
    }
  }

  @override
  void dispose() {
    _pageCtl.dispose();
    for (final c in _ctls.values) {
      c.dispose();
    }
    super.dispose();
  }
}
