import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/branding.dart';
import '../../core/api_client.dart';

/// Reports & Analytics — school figures + broadsheet CSV downloads (no preview).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _d = const {};
  List<dynamic> _classes = const [];
  List<dynamic> _terms = const [];
  int? _dlClassId;
  int? _dlTermId;
  bool _linkBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final res = await widget.api.get('/staff/analytics');
    final tg = await widget.api.get('/staff/results/targets');
    if (!mounted) return;
    if (!res.success) {
      setState(() { _loading = false; _error = res.friendlyError; });
      return;
    }
    setState(() {
      _loading = false;
      _d = res.data;
      if (tg.success) {
        _classes = (tg.data['classes'] as List?) ?? const [];
        _terms = (tg.data['terms'] as List?) ?? const [];
        final cur = _terms.cast<Map>().where((t) => t['is_current'] == true);
        if (_dlTermId == null && cur.isNotEmpty) {
          _dlTermId = (cur.first['term_id'] as num).toInt();
        }
      }
    });
  }

  Future<void> _getLink() async {
    if (_dlClassId == null || _dlTermId == null) return;
    setState(() => _linkBusy = true);
    final res = await widget.api.get(
        '/staff/broadsheet/link?class_id=$_dlClassId&term_id=$_dlTermId');
    if (!mounted) return;
    setState(() => _linkBusy = false);
    if (res.success) {
      final url = '${res.data['url'] ?? ''}';
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Download link copied — paste it in your browser and the '
            'broadsheet CSV will download. Valid today only.'),
        duration: Duration(seconds: 5),
      ));
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
    final enr = asMap(_d['enrolment']);
    final perf = asMap(_d['performance']);
    final totals = asMap(enr['totals']);
    final gender = asMap(enr['by_gender']);
    final summary = asMap(perf['summary']);
    final grades = asEntries(perf['grades']); // Map or List — both safe
    final byClass = asList(perf['by_class']);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        // download card first — the reason this screen exists
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Branding.primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Branding.primaryColor.withOpacity(0.25)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Download broadsheet (CSV)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 4),
            Text('One row per student, one column per subject — opens in Excel.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _dlClassId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Class',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                  ),
                  items: _classes.map<DropdownMenuItem<int>>((c) =>
                      DropdownMenuItem(
                        value: (c['class_id'] as num).toInt(),
                        child: Text('${c['class']}',
                            overflow: TextOverflow.ellipsis),
                      )).toList(),
                  onChanged: (v) => setState(() => _dlClassId = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _dlTermId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Term',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                  ),
                  items: _terms.map<DropdownMenuItem<int>>((t) =>
                      DropdownMenuItem(
                        value: (t['term_id'] as num).toInt(),
                        child: Text('${t['term']}',
                            overflow: TextOverflow.ellipsis),
                      )).toList(),
                  onChanged: (v) => setState(() => _dlTermId = v),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Branding.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _linkBusy || _dlClassId == null ? null : _getLink,
                icon: _linkBusy
                    ? const SizedBox(width: 15, height: 15,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download, size: 19),
                label: const Text('Get download link',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        Text('ENROLMENT', style: _h()),
        const SizedBox(height: 6),
        Row(children: [
          _mini('On roll', '${totals['on_roll'] ?? totals['total'] ?? '—'}'),
          const SizedBox(width: 8),
          _mini('Male', '${gender['male'] ?? '—'}'),
          const SizedBox(width: 8),
          _mini('Female', '${gender['female'] ?? '—'}'),
        ]),
        const SizedBox(height: 16),

        Text('PERFORMANCE (current term)', style: _h()),
        const SizedBox(height: 6),
        Row(children: [
          _mini('Pass rate', summary['pass_rate'] != null
              ? '${(summary['pass_rate'] as num).toStringAsFixed(1)}%' : '—'),
          const SizedBox(width: 8),
          _mini('Avg %', summary['average'] != null
              ? '${(summary['average'] as num).toStringAsFixed(1)}' : '—'),
          const SizedBox(width: 8),
          _mini('Graded', '${summary['students_graded'] ?? summary['graded'] ?? '—'}'),
        ]),
        const SizedBox(height: 12),

        if (grades.isNotEmpty) ...[
          Text('GRADE DISTRIBUTION', style: _h()),
          const SizedBox(height: 6),
         Wrap(spacing: 8, runSpacing: 8, children: grades.map((e) =>
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text('${e.key}: ${e.value}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              )).toList()),
          const SizedBox(height: 12),
        ],

        if (byClass.isNotEmpty) ...[
          Text('BY CLASS', style: _h()),
          const SizedBox(height: 4),
          ...byClass.map((c) => Card(
                margin: const EdgeInsets.only(top: 6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  dense: true,
                  title: Text('${c['class'] ?? c['class_name'] ?? ''}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13.5)),
                  trailing: Text(
                      c['average'] != null
                          ? '${(c['average'] as num).toStringAsFixed(1)}%'
                          : '—',
                      style: TextStyle(fontWeight: FontWeight.w800,
                          color: Branding.primaryColor, fontSize: 14)),
                ),
              )),
        ],
      ]),
    );
  }

  TextStyle _h() => TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
      letterSpacing: 0.5, color: Colors.grey.shade600);

  Widget _mini(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: [
            Text(value, style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16)),
            Text(label, style: TextStyle(
                fontSize: 11.5, color: Colors.grey.shade600)),
          ]),
        ),
      );
}
