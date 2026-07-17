import 'package:flutter/material.dart';
import '../../config/branding.dart';
import '../../core/api_client.dart';

/// CBT Publish Results — the Publishing Center: per-term exam list with
/// ready/pending counts, publish per exam or the whole term.
class CbtPublishScreen extends StatefulWidget {
  const CbtPublishScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<CbtPublishScreen> createState() => _CbtPublishScreenState();
}

class _CbtPublishScreenState extends State<CbtPublishScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _exams = const [];
  List<dynamic> _terms = const [];
  int? _termId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    var path = '/cbt/manage/publish-center';
    if (_termId != null) path += '?term_id=$_termId';
    final res = await widget.api.get(path);
    if (!mounted) return;
    if (!res.success) {
      setState(() { _loading = false; _error = res.friendlyError; });
      return;
    }
    setState(() {
      _loading = false;
      _exams = (res.data['exams'] as List?) ?? const [];
      _terms = (res.data['terms'] as List?) ?? const [];
      _termId ??= (res.meta['selected_term_id'] as num?)?.toInt();
    });
  }

  int get _totalReady => _exams.fold(0,
      (n, e) => n + (((e['has_distribution'] == true) ? (e['ready'] as num?)?.toInt() : 0) ?? 0));

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

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        DropdownButtonFormField<int>(
          value: _termId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Term',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: _terms.map<DropdownMenuItem<int>>((t) => DropdownMenuItem(
                value: (t['id'] as num).toInt(),
                child: Text('${t['name']}', overflow: TextOverflow.ellipsis),
              )).toList(),
          onChanged: (v) { setState(() => _termId = v); _load(); },
        ),
        const SizedBox(height: 10),
        Text('Publishing pushes each graded CBT attempt into the term score components '
            '(CA/Exam) using the exam\u2019s score distribution — the same numbers Score Entry writes.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
        const SizedBox(height: 10),
        if (_totalReady > 0)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Branding.successColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _busy ? null : () => _publish(scope: 'term'),
              icon: const Icon(Icons.publish, size: 20),
              label: Text('Publish all ready in this term ($_totalReady)',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        const SizedBox(height: 8),
        if (_exams.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 50),
            child: Center(child: Text('No published or closed exams in this term.',
                style: TextStyle(color: Colors.grey.shade600))),
          ),
        ..._exams.map(_examCard),
      ]),
    );
  }

  Widget _examCard(dynamic e) {
    final ready = (e['ready'] as num?)?.toInt() ?? 0;
    final pending = (e['pending'] as num?)?.toInt() ?? 0;
    final hasDist = e['has_distribution'] == true;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${e['title']}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          Text('${e['subject']} · ${e['class']}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                if (!hasDist)
                  _chip('no score distribution', Colors.white, Colors.red.shade400)
                else ...[
                  _chip('$ready ready', Colors.white,
                      ready > 0 ? Branding.successColor : Colors.grey.shade400),
                  if (pending > 0)
                    _chip('$pending pending marking', const Color(0xFF8A6D00),
                        const Color(0xFFFFF4D6)),
                ],
              ]),
            ),
            if (hasDist && ready > 0)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Branding.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: _busy ? null
                    : () => _publish(scope: 'exam',
                        examId: (e['id'] as num).toInt(), title: '${e['title']}'),
                child: const Text('Publish', style: TextStyle(fontSize: 12.5)),
              ),
          ]),
          if (!hasDist)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Set this exam\u2019s score distribution on the web before publishing.',
                  style: TextStyle(fontSize: 11, color: Colors.red.shade400)),
            ),
        ]),
      ),
    );
  }

  Widget _chip(String t, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(t, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w700)),
      );

  Future<void> _publish({required String scope, int? examId, String? title}) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(scope == 'term'
            ? 'Publish every ready attempt in this term?'
            : 'Publish "$title"?'),
        content: const Text(
            'Graded attempts become component scores on the students\u2019 term records. '
            'Attempts still pending theory marking are skipped and can be published later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Publish')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    final res = await widget.api.post('/cbt/manage/publish-run', body: {
      'term_id': _termId,
      'scope': scope,
      if (examId != null) 'exam_id': examId,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success) {
      final d = res.data;
      var msg = 'Published ${d['published'] ?? 0} attempt(s) across ${d['exams'] ?? 0} exam(s).';
      final pending = (d['pending'] as num?)?.toInt() ?? 0;
      final failed = (d['failed'] as num?)?.toInt() ?? 0;
      final noDist = (d['no_distribution'] as List?) ?? const [];
      if (pending > 0) msg += ' $pending still pending marking.';
      if (failed > 0) msg += ' $failed failed.';
      if (noDist.isNotEmpty) msg += ' Skipped (no distribution): ${noDist.take(3).join(', ')}.';
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 5)));
      _load();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.friendlyError)));
    }
  }
}
