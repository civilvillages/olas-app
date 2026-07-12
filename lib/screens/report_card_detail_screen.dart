import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';

/// One term's report card — summary, subject table, attendance, comments.
class ReportCardDetailScreen extends StatefulWidget {
  const ReportCardDetailScreen(
      {super.key, required this.api, required this.termId});
  final ApiClient api;
  final int termId;

  @override
  State<ReportCardDetailScreen> createState() => _ReportCardDetailScreenState();
}

class _ReportCardDetailScreenState extends State<ReportCardDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _summary = const {};
  Map<String, dynamic> _att = const {};
  Map<String, dynamic> _comments = const {};
  List<dynamic> _subjects = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await widget.api.get('/me/report-cards/${widget.termId}');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        Map<String, dynamic> m(String k) =>
            (res.data[k] as Map?)?.cast<String, dynamic>() ?? {};
        _summary = m('summary');
        _att = m('attendance');
        _comments = m('comments');
        _subjects = (res.data['subjects'] as List?) ?? const [];
      } else {
        _error = res.friendlyError;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Branding.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Report Card'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(_error!, textAlign: TextAlign.center)))
              : _body(),
    );
  }

  Widget _body() {
    final avg = (_summary['average'] as num?) ?? 0;
    final promo = '${_summary['promotion_status'] ?? ''}';
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('${_summary['term'] ?? ''} · ${_summary['session'] ?? ''}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Text('${_summary['class'] ?? ''}',
          style: TextStyle(color: Colors.grey.shade600)),
      const SizedBox(height: 14),

      // summary hero
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Branding.primaryColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Branding.primaryColor.withOpacity(0.25)),
        ),
        child: Column(children: [
          Text('${avg.toStringAsFixed(2)}%',
              style: TextStyle(
                  fontSize: 36, fontWeight: FontWeight.w800,
                  color: Branding.primaryColor)),
          Text('Grade ${_summary['grade'] ?? ''} · ${_summary['remark'] ?? ''}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(children: [
            _mini('Position', _ord((_summary['position'] as num?)?.toInt() ?? 0)
                + ' of ${_summary['class_size'] ?? ''}'),
            const SizedBox(width: 8),
            _mini('Obtained', '${_trim((_summary['total_obtained'] as num?) ?? 0)}'
                '/${_trim((_summary['total_obtainable'] as num?) ?? 0)}'),
            const SizedBox(width: 8),
            _mini('Class avg', '${_trim((_summary['class_average'] as num?) ?? 0)}%'),
          ]),
          if (promo.isNotEmpty && promo != 'pending') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: promo == 'promoted'
                    ? Branding.successColor
                    : Colors.red.shade700,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(promo.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700,
                      fontSize: 12.5)),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 16),

      // subjects
      Text('SUBJECTS (${_subjects.length})',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              letterSpacing: 0.5, color: Colors.grey.shade600)),
      const SizedBox(height: 6),
      ..._subjects.map(_subjectCard),
      const SizedBox(height: 16),

      // attendance
      if (((_att['opened'] as num?) ?? 0) > 0) ...[
        Text('ATTENDANCE',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                letterSpacing: 0.5, color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        Row(children: [
          _mini('Opened', '${_att['opened']}'),
          const SizedBox(width: 8),
          _mini('Present', '${_att['present']}'),
          const SizedBox(width: 8),
          _mini('Absent', '${_att['absent']}'),
        ]),
        const SizedBox(height: 16),
      ],

      // comments
      if ('${_comments['class_teacher'] ?? ''}'.trim().isNotEmpty)
        _comment("Class Teacher", '${_comments['class_teacher']}'),
      if ('${_comments['head_teacher'] ?? ''}'.trim().isNotEmpty)
        _comment("Head Teacher", '${_comments['head_teacher']}'),
    ]);
  }

  Widget _subjectCard(dynamic s) {
    final name = '${s['subject'] ?? ''}';
    // known score keys, displayed when present
    final entries = <MapEntry<String, String>>[];
    for (final k in s.keys) {
      if (k == 'subject') continue;
      final v = s[k];
      if (v == null || '$v'.isEmpty) continue;
      entries.add(MapEntry(_label('$k'), v is num ? _trim(v) : '$v'));
    }
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
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 14, runSpacing: 4, children: [
            for (final e in entries)
              Text('${e.key}: ${e.value}',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
          ]),
        ]),
      ),
    );
  }

  String _label(String k) => k
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : (w == 'ca' ? 'CA' : w[0].toUpperCase() + w.substring(1)))
      .join(' ');

  Widget _comment(String who, String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Branding.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(who, style: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 12.5)),
        const SizedBox(height: 4),
        Text(text, style: const TextStyle(height: 1.4)),
      ]),
    );
  }

  Widget _mini(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(value, textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      ),
    );
  }

  String _trim(num n) =>
      n == n.roundToDouble() ? '${n.toInt()}' : n.toStringAsFixed(2);

  String _ord(int n) {
    if (n <= 0) return '';
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' };
  }
}
