import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';
import '../core/sync_service.dart';
import '../models/exam.dart';
import 'exam_detail_screen.dart';

/// Feature 2 — My Exams.
/// Open-now exams are shown as active cards. Upcoming and Past are tucked into
/// collapsible sections so the screen leads with what the student can do now.
class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  bool _loading = true;
  String? _error;
  List<Exam> _open = [];
  List<Exam> _upcoming = [];
  List<Exam> _past = [];
  String _className = '';

  bool _showUpcoming = false;
  bool _showPast = false;
  List<int> _pendingSync = const [];
  String? _syncNote;

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
    // Feature 4: push any offline-queued submissions before listing exams,
    // so attempts/counters on the server are up to date.
    final sync = SyncService(widget.api);
    final (synced, failed) = await sync.flush();
    _pendingSync = await SyncService.pendingIds();
    _syncNote = synced > 0
        ? '$synced offline submission${synced == 1 ? '' : 's'} synced.'
        : null;
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
    List<Exam> parse(String bucket) => ((d[bucket] as List?) ?? const [])
        .map((e) => Exam.fromJson(e as Map<String, dynamic>, bucket))
        .toList();
    setState(() {
      _loading = false;
      _open = parse('available_now');
      _upcoming = parse('upcoming');
      _past = parse('past');
      _className = (student['class_name'] as String?) ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(onRefresh: _load, child: _body());
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return ListView(children: [
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
        Center(child: OutlinedButton(onPressed: _load, child: const Text('Try again'))),
      ]);
    }

    final children = <Widget>[];

    if (_syncNote != null) {
      children.add(Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE2F3E9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(Icons.cloud_done, size: 18, color: Branding.successColor),
          const SizedBox(width: 8),
          Expanded(child: Text(_syncNote!,
              style: const TextStyle(fontSize: 13))),
        ]),
      ));
    }
    if (_pendingSync.isNotEmpty) {
      children.add(Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4D6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.cloud_upload_outlined,
              size: 18, color: Color(0xFF8A6D00)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_pendingSync.length} exam submission${_pendingSync.length == 1 ? '' : 's'} waiting to sync — will send automatically when online.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ]),
      ));
    }

    // --- OPEN NOW ---
    if (_open.isNotEmpty) {
      children.add(_sectionLabel('Open now', _open.length, Branding.successColor));
      children.addAll(_open.map((e) => _examCard(e, active: true)));
    } else {
      children.add(_emptyOpen());
    }

    // --- UPCOMING (collapsible) ---
    if (_upcoming.isNotEmpty) {
      children.add(_collapseHeader(
        icon: Icons.schedule,
        text: '${_upcoming.length} exam${_upcoming.length == 1 ? '' : 's'} coming soon',
        expanded: _showUpcoming,
        onTap: () => setState(() => _showUpcoming = !_showUpcoming),
      ));
      if (_showUpcoming) {
        children.addAll(_upcoming.map((e) => _examCard(e, active: false)));
      }
    }

    // --- PAST (collapsible) ---
    if (_past.isNotEmpty) {
      children.add(_collapseHeader(
        icon: Icons.history,
        text: 'Past exams (${_past.length})',
        expanded: _showPast,
        onTap: () => setState(() => _showPast = !_showPast),
      ));
      if (_showPast) {
        children.addAll(_past.map((e) => _examCard(e, active: false)));
      }
    }

    return ListView(padding: const EdgeInsets.all(12), children: children);
  }

  Widget _emptyOpen() {
    return Container(
      margin: const EdgeInsets.only(top: 40, bottom: 8),
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Icon(Icons.check_circle_outline, size: 52, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('No exams open right now',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700)),
        const SizedBox(height: 4),
        Text(
          _className.isEmpty
              ? 'Pull down to refresh.'
              : 'Nothing to take for $_className at the moment.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String text, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Colors.grey.shade600)),
      ]),
    );
  }

  Widget _collapseHeader({
    required IconData icon,
    required String text,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: Material(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(icon, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800)),
              ),
              Icon(expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey.shade500),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _examCard(Exam e, {required bool active}) {
    final (label, kind) = e.tag;
    final tagColor = switch (kind) {
      'open' => Branding.successColor,
      'soon' => const Color(0xFFB8860B),
      'done' => Branding.primaryColor,
      _ => const Color(0xFF6B7280),
    };
    return Opacity(
      opacity: active ? 1.0 : 0.72,
      child: Card(
        margin: const EdgeInsets.only(top: 10),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: active ? Branding.successColor.withOpacity(0.35) : Colors.grey.shade200),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ExamDetailScreen(api: widget.api, exam: e)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(e.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tagColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(label,
                      style: TextStyle(color: tagColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(e.subject, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 10),
              Row(children: [
                _chip(Icons.help_outline, '${e.questionCount} Qs'),
                const SizedBox(width: 14),
                _chip(Icons.timer_outlined, '${e.durationMinutes} min'),
                const SizedBox(width: 14),
                _chip(Icons.star_outline, '${e.totalMarks}'),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: Colors.grey.shade500),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5)),
    ]);
  }
}
