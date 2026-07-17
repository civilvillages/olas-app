import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/branding.dart';
import '../../core/api_client.dart';

/// CBT Reports — analytics figures + download-only CSVs (results per exam,
/// participation per term) via signed links.
class CbtReportsScreen extends StatefulWidget {
  const CbtReportsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<CbtReportsScreen> createState() => _CbtReportsScreenState();
}

class _CbtReportsScreenState extends State<CbtReportsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _summary = const {};
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
    var path = '/cbt/manage/analytics';
    if (_termId != null) path += '?term_id=$_termId';
    final res = await widget.api.get(path);
    if (!mounted) return;
    if (!res.success) {
      setState(() { _loading = false; _error = res.friendlyError; });
      return;
    }
    setState(() {
      _loading = false;
      _summary = (res.data['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
      _exams = (res.data['exams'] as List?) ?? const [];
      _terms = (res.data['terms'] as List?) ?? const [];
      _termId ??= (res.meta['selected_term_id'] as num?)?.toInt();
    });
  }

  Future<void> _copyLink(String path, String what) async {
    setState(() => _busy = true);
    final res = await widget.api.get(path);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success) {
      await Clipboard.setData(ClipboardData(text: '${res.data['url'] ?? ''}'));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$what link copied — paste it in your browser to download. Valid today only.'),
          duration: const Duration(seconds: 5)));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.friendlyError)));
    }
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
        const SizedBox(height: 12),

        Row(children: [
          _mini('Exams', '${_summary['exams'] ?? 0}'),
          const SizedBox(width: 8),
          _mini('Attempts', '${_summary['attempts'] ?? 0}'),
          const SizedBox(width: 8),
          _mini('Avg %', _summary['avg_pct'] != null ? '${_summary['avg_pct']}' : '—'),
          const SizedBox(width: 8),
          _mini('Pass rate', _summary['pass_rate'] != null ? '${_summary['pass_rate']}%' : '—'),
        ]),
        const SizedBox(height: 10),

        OutlinedButton.icon(
          onPressed: _busy || _termId == null
              ? null
              : () => _copyLink('/cbt/manage/reports/link?term_id=$_termId',
                  'Participation report'),
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Download participation CSV (this term)'),
        ),
        const SizedBox(height: 10),

        Text('EXAMS THIS TERM',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                letterSpacing: 0.5, color: Colors.grey.shade600)),
        if (_exams.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('No published or closed exams in this term.',
                style: TextStyle(color: Colors.grey.shade600))),
          ),
        ..._exams.map(_examCard),
      ]),
    );
  }

  Widget _examCard(dynamic e) {
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
          Row(children: [
            Expanded(child: Text('${e['title']}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            IconButton(
              icon: Icon(Icons.download, size: 20, color: Branding.primaryColor),
              tooltip: 'Download results CSV',
              onPressed: _busy ? null
                  : () => _copyLink('/cbt/manage/results/link?exam_id=${e['exam_id']}',
                      'Results'),
            ),
          ]),
          Text('${e['subject']} · ${e['class']}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Wrap(spacing: 10, runSpacing: 4, children: [
            _fact('${e['attempted']}/${e['expected']} took it'),
            if (e['participation_pct'] != null)
              _fact('${e['participation_pct']}% participation'),
            if (e['avg_pct'] != null) _fact('avg ${e['avg_pct']}%'),
            if (e['pass_rate'] != null) _fact('${e['pass_rate']}% passed'),
          ]),
        ]),
      ),
    );
  }

  Widget _fact(String t) => Text(t,
      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600));

  Widget _mini(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(label, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
          ]),
        ),
      );
}
