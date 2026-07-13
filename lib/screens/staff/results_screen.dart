import 'package:flutter/material.dart';
import '../../config/branding.dart';
import '../../core/api_client.dart';

/// Staff Results — compiled class table, missing-score indicators,
/// Compile (ResultEngine) and Publish/Pending/Unpublish actions.
class StaffResultsScreen extends StatefulWidget {
  const StaffResultsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<StaffResultsScreen> createState() => _StaffResultsScreenState();
}

class _StaffResultsScreenState extends State<StaffResultsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _classes = const [];
  List<dynamic> _terms = const [];
  bool _canPublish = false;
  int? _classId;
  int? _termId;

  bool _tableLoading = false;
  Map<String, dynamic>? _table;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  Future<void> _loadTargets() async {
    setState(() { _loading = true; _error = null; });
    final res = await widget.api.get('/staff/results/targets');
    if (!mounted) return;
    if (!res.success) {
      setState(() { _loading = false; _error = res.friendlyError; });
      return;
    }
    setState(() {
      _loading = false;
      _classes = (res.data['classes'] as List?) ?? const [];
      _terms = (res.data['terms'] as List?) ?? const [];
      _canPublish = (res.data['can_publish'] as bool?) ?? false;
      final cur = _terms.cast<Map>().where((t) => t['is_current'] == true);
      if (_termId == null && cur.isNotEmpty) {
        _termId = (cur.first['term_id'] as num).toInt();
      }
    });
  }

  Future<void> _loadTable() async {
    if (_classId == null || _termId == null) return;
    setState(() { _tableLoading = true; _table = null; });
    final res = await widget.api
        .get('/staff/results/class?class_id=$_classId&term_id=$_termId');
    if (!mounted) return;
    setState(() {
      _tableLoading = false;
      if (res.success) {
        _table = res.data;
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res.friendlyError)));
      }
    });
  }

  Future<void> _compile() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Compile results?'),
        content: const Text(
            'This computes totals, grades and positions from the entered scores '
            'for every student in this class. Existing compiled figures are recalculated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Compile')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    final res = await widget.api.post('/staff/results/process',
        body: {'class_id': _classId, 'term_id': _termId});
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success) {
      final s = (res.data['summary'] as Map?) ?? const {};
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Compiled: ${s['students_processed'] ?? 0} student(s), '
              '${s['subjects_processed'] ?? 0} subject(s). '
              'Class average ${(s['class_average'] as num?)?.toStringAsFixed(2) ?? '—'}%.')));
      _loadTable();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.friendlyError)));
    }
  }

  Future<void> _publishAction(String action) async {
    final labels = {
      'publish': 'Publish results to students and parents?',
      'pending': 'Mark results as pending (hide while under review)?',
      'unpublish': 'Unpublish results (return to draft)?',
    };
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(labels[action] ?? action),
        content: const Text('This affects every student in the class for this term.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    final res = await widget.api.post('/staff/results/publish',
        body: {'class_id': _classId, 'term_id': _termId, 'action': action});
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.success
            ? 'Done — results ${action == 'publish' ? 'published' : action == 'pending' ? 'marked pending' : 'unpublished'}. '
              '${action == 'publish' ? 'To notify parents by email, use the portal.' : ''}'
            : res.friendlyError)));
    if (res.success) _loadTable();
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
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _loadTargets, child: const Text('Try again')),
        ]),
      ));
    }

    return ListView(padding: const EdgeInsets.all(14), children: [
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _classId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Class',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: _classes.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(
                  value: (c['class_id'] as num).toInt(),
                  child: Text('${c['class']}', overflow: TextOverflow.ellipsis),
                )).toList(),
            onChanged: (v) { setState(() => _classId = v); _loadTable(); },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _termId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Term',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: _terms.map<DropdownMenuItem<int>>((t) => DropdownMenuItem(
                  value: (t['term_id'] as num).toInt(),
                  child: Text('${t['term']}${t['is_current'] == true ? ' (current)' : ''}',
                      overflow: TextOverflow.ellipsis),
                )).toList(),
            onChanged: (v) { setState(() => _termId = v); _loadTable(); },
          ),
        ),
      ]),
      const SizedBox(height: 12),

      if (_tableLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator()),
        ),

      if (_table != null) ..._tableWidgets(),
      if (_table == null && !_tableLoading)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Center(child: Text('Pick a class and term to view results.',
              style: TextStyle(color: Colors.grey.shade600))),
        ),
    ]);
  }

  List<Widget> _tableWidgets() {
    final t = _table!;
    final summary = (t['summary'] as Map?) ?? const {};
    final students = (t['students'] as List?) ?? const [];
    final totalSubjects = (t['class_subjects'] as num?)?.toInt() ?? 0;

    return [
      // summary strip
      Row(children: [
        _mini('Students', '${summary['total_students'] ?? 0}'),
        const SizedBox(width: 8),
        _mini('Compiled', '${summary['compiled'] ?? 0}'),
        const SizedBox(width: 8),
        _mini('Published', '${summary['published'] ?? 0}'),
      ]),
      const SizedBox(height: 10),

      // actions
      Row(children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Branding.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _busy ? null : _compile,
            icon: _busy
                ? const SizedBox(width: 15, height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.calculate_outlined, size: 19),
            label: const Text('Compile', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        if (_canPublish) ...[
          const SizedBox(width: 10),
          Expanded(
            child: PopupMenuButton<String>(
              enabled: !_busy,
              onSelected: _publishAction,
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'publish', child: Text('Publish')),
                PopupMenuItem(value: 'pending', child: Text('Mark pending')),
                PopupMenuItem(value: 'unpublish', child: Text('Unpublish')),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Branding.successColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.publish_outlined, size: 19, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Publish ▾',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 12),

      Text('STUDENTS · $totalSubjects class subject(s)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              letterSpacing: 0.5, color: Colors.grey.shade600)),
      const SizedBox(height: 4),
      ...students.map((s) => _studentRow(s)),
    ];
  }

  Widget _studentRow(dynamic s) {
    final compiled = (s['compiled'] as bool?) ?? false;
    final published = (s['is_published'] as bool?) ?? false;
    final missing = (s['missing_subjects'] as num?)?.toInt() ?? 0;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              Text('${s['admission_number'] ?? ''}',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (missing > 0)
                  _chip('$missing missing', const Color(0xFFB8860B), const Color(0xFFFFF4D6)),
                if (missing == 0)
                  _chip('all scored', Branding.successColor,
                      Branding.successColor.withOpacity(0.1)),
                if (published)
                  _chip('published', Colors.white, Branding.successColor),
                if (compiled && !published)
                  _chip('compiled', Branding.primaryColor,
                      Branding.primaryColor.withOpacity(0.1)),
              ]),
            ]),
          ),
          if (compiled)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${(s['average'] as num?)?.toStringAsFixed(1) ?? ''}%',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                      color: Branding.primaryColor)),
              Text('Grade ${s['grade'] ?? ''} · ${_ord((s['position'] as num?)?.toInt() ?? 0)}',
                  style: const TextStyle(fontSize: 11.5)),
            ])
          else
            Text('not compiled',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ]),
      ),
    );
  }

  Widget _chip(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: TextStyle(fontSize: 10.5, color: fg, fontWeight: FontWeight.w600)),
      );

  Widget _mini(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
          ]),
        ),
      );

  String _ord(int n) {
    if (n <= 0) return '';
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' };
  }
}
