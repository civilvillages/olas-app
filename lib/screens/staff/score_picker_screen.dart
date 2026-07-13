import 'package:flutter/material.dart';
import '../../config/branding.dart';
import '../../core/api_client.dart';
import '../../core/score_cache.dart';
import 'score_entry_screen.dart';

/// Pick class -> subject -> term, see lock states, then open the entry screen
/// (downloads the bundle when online; reuses the cached one offline).
class ScorePickerScreen extends StatefulWidget {
  const ScorePickerScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<ScorePickerScreen> createState() => _ScorePickerScreenState();
}

class _ScorePickerScreenState extends State<ScorePickerScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _classes = const [];
  List<dynamic> _terms = const [];
  int? _classId;
  int? _subjectId;
  int? _termId;
  List<String> _pendingKeys = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    _pendingKeys = await ScoreCache.pendingKeys();
    final res = await widget.api.get('/staff/score-targets');
    if (!mounted) return;
    if (!res.success) {
      setState(() { _loading = false; _error = res.friendlyError; });
      return;
    }
    setState(() {
      _loading = false;
      _classes = (res.data['classes'] as List?) ?? const [];
      _terms = (res.data['terms'] as List?) ?? const [];
      // default to the current open term
      final cur = _terms.cast<Map>().where((t) => t['is_current'] == true);
      if (_termId == null && cur.isNotEmpty) {
        _termId = (cur.first['term_id'] as num).toInt();
      }
    });
  }

  List<dynamic> get _subjects {
    final c = _classes.cast<Map>().where((c) => c['class_id'] == _classId);
    return c.isEmpty ? const [] : (c.first['subjects'] as List? ?? const []);
  }

  Map? get _term {
    final t = _terms.cast<Map>().where((t) => t['term_id'] == _termId);
    return t.isEmpty ? null : t.first;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: const Text('Try again')),
        ]),
      ));
    }

    final term = _term;
    final lockOpen = term == null || (term['lock_open'] as bool? ?? true);
    final ready = _classId != null && _subjectId != null && _termId != null;
    final pendingHere = ready &&
        _pendingKeys.contains(ScoreCache.key(_classId!, _subjectId!, _termId!));

    return ListView(padding: const EdgeInsets.all(16), children: [
      if (_pendingKeys.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4D6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(Icons.sync, size: 18, color: Color(0xFF8A6D00)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              '${_pendingKeys.length} score batch(es) waiting to sync. Open the class to sync now.',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A6D00)),
            )),
          ]),
        ),

      const Text('Class', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      DropdownButtonFormField<int>(
        value: _classId,
        isExpanded: true,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        hint: const Text('Select class'),
        items: _classes.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(
              value: (c['class_id'] as num).toInt(),
              child: Text('${c['class']} (${c['level']})'),
            )).toList(),
        onChanged: (v) => setState(() { _classId = v; _subjectId = null; }),
      ),
      const SizedBox(height: 14),

      const Text('Subject', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      DropdownButtonFormField<int>(
        value: _subjectId,
        isExpanded: true,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        hint: const Text('Select subject'),
        items: _subjects.map<DropdownMenuItem<int>>((s) => DropdownMenuItem(
              value: (s['subject_id'] as num).toInt(),
              child: Text('${s['subject']}'),
            )).toList(),
        onChanged: (v) => setState(() => _subjectId = v),
      ),
      const SizedBox(height: 14),

      const Text('Term', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      ..._terms.map((t) {
        final id = (t['term_id'] as num).toInt();
        final open = (t['lock_open'] as bool?) ?? true;
        return RadioListTile<int>(
          dense: true,
          value: id,
          groupValue: _termId,
          onChanged: open ? (v) => setState(() => _termId = v) : null,
          title: Row(children: [
            Text('${t['term']}',
                style: TextStyle(
                    fontWeight: (t['is_current'] as bool? ?? false)
                        ? FontWeight.w700 : FontWeight.w500)),
            if (t['is_current'] as bool? ?? false)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Branding.successColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('current',
                    style: TextStyle(fontSize: 10.5, color: Branding.successColor)),
              ),
            if (!open)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('locked',
                    style: TextStyle(fontSize: 10.5, color: Colors.red.shade700)),
              ),
          ]),
          subtitle: !open && '${t['lock_reason'] ?? ''}'.isNotEmpty
              ? Text('${t['lock_reason']}', style: const TextStyle(fontSize: 11.5))
              : null,
        );
      }),
      const SizedBox(height: 18),

      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Branding.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: ready && (lockOpen || pendingHere) ? _open : null,
          icon: Icon(pendingHere ? Icons.sync : Icons.download, size: 20),
          label: Text(
              pendingHere ? 'Open (batch waiting to sync)' : 'Open for entry',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
      if (ready && !lockOpen && !pendingHere)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('${term?['lock_reason'] ?? 'This term is locked.'}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
        ),
    ]);
  }

  Future<void> _open() async {
    final k = ScoreCache.key(_classId!, _subjectId!, _termId!);
    // Try fresh bundle; fall back to cache when offline.
    final res = await widget.api.get(
        '/staff/scores/bundle?class_id=$_classId&subject_id=$_subjectId&term_id=$_termId');
    Map<String, dynamic>? bundle;
    if (res.success) {
      bundle = res.data;
      await ScoreCache.saveBundle(k, bundle!);
    } else {
      bundle = await ScoreCache.bundle(k);
      if (bundle == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(res.friendlyError.contains('internet') ||
                    res.friendlyError.contains('connect')
                ? 'You are offline and this class has not been downloaded yet.'
                : res.friendlyError)));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Offline — using the downloaded copy.')));
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScoreEntryScreen(api: widget.api, cacheKey: k),
      ),
    );
    _load(); // refresh pending badges on return
  }
}
