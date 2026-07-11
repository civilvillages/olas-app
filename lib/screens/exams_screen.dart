import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';
import '../models/exam.dart';
import 'exam_detail_screen.dart';

/// Feature 2 — My Exams. One list; each exam tagged with its status.
class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  bool _loading = true;
  String? _error;
  List<Exam> _exams = [];
  String _className = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await widget.api.get('/cbt/exams');
    if (!mounted) return;
    if (!res.success) {
      setState(() {
        _loading = false;
        _error = res.friendlyError;
      });
      return;
    }
    final d = res.data;
    final student = (d['student'] as Map<String, dynamic>?) ?? const {};
    final list = <Exam>[];
    for (final bucket in ['available_now', 'upcoming', 'past']) {
      final arr = (d[bucket] as List?) ?? const [];
      for (final e in arr) {
        list.add(Exam.fromJson(e as Map<String, dynamic>, bucket));
      }
    }
    setState(() {
      _loading = false;
      _exams = list;
      _className = (student['class_name'] as String?) ?? '';
    });
  }

  Color _tagColor(String kind) {
    switch (kind) {
      case 'open':
        return Branding.successColor;
      case 'soon':
        return const Color(0xFFB8860B); // amber-ish
      case 'done':
        return Branding.primaryColor;
      default:
        return const Color(0xFF6B7280); // grey
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600)),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(onPressed: _load, child: const Text('Try again')),
          ),
        ],
      );
    }
    if (_exams.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.assignment_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Center(
            child: Text('No exams for $_className right now.',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('Pull down to refresh.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _exams.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final e = _exams[i];
        final (label, kind) = e.tag;
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExamDetailScreen(api: widget.api, exam: e),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(e.title,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _tagColor(kind).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(label,
                            style: TextStyle(
                                color: _tagColor(kind),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(e.subject,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _chip(Icons.help_outline, '${e.questionCount} Qs'),
                      const SizedBox(width: 14),
                      _chip(Icons.timer_outlined, '${e.durationMinutes} min'),
                      const SizedBox(width: 14),
                      _chip(Icons.star_outline, '${e.totalMarks}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5)),
      ],
    );
  }
}
