import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';

/// Landing dashboard — greeting, session chip, admission card, tile grid.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.api, required this.onNavigate});
  final ApiClient api;
  final void Function(String section) onNavigate;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _d = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await widget.api.get('/me/dashboard');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) _d = res.data;
    });
  }

  String _naira(num n) {
    final w = n.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '₦$w';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final user = (_d['user'] as Map?) ?? const {};
    final student = (_d['student'] as Map?) ?? const {};
    final cur = (_d['current'] as Map?) ?? const {};
    final counts = (_d['counts'] as Map?) ?? const {};
    final feesOut = (counts['fees_outstanding'] as num?) ?? 0;
    final unread = (counts['unread_announcements'] as num?)?.toInt() ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        // session chip
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Branding.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calendar_month, size: 16, color: Branding.primaryColor),
              const SizedBox(width: 6),
              Text('${cur['session_name'] ?? ''} · ${cur['term_name'] ?? ''}',
                  style: TextStyle(
                      color: Branding.primaryColor,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Text('Hi, ${user['first_name'] ?? ''}!',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        Text('Your student portal',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
        const SizedBox(height: 16),

        // admission card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Admission Number',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            Text('${student['admission_number'] ?? ''}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Current Class',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            Text('${student['class'] ?? ''}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(height: 14),

        // tiles
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            _tile('Report Card', Icons.assessment_outlined, const Color(0xFF0D6EFD), 'reportcards'),
            _tile('CBT / Exams', Icons.edit_note, const Color(0xFF198754), 'exams'),
            _tile('CBT Results', Icons.fact_check_outlined, const Color(0xFF6F42C1), 'results'),
            _tile('My Subjects', Icons.menu_book_outlined, const Color(0xFF0DCAF0), 'subjects'),
            _tile('Attendance', Icons.event_available_outlined, const Color(0xFFFFC107), 'attendance'),
            _tile('Assignments', Icons.assignment_ind_outlined, const Color(0xFFD63384), 'assignments'),
            _tile('School Fees', Icons.payments_outlined, const Color(0xFFDC3545), 'fees',
                sub: feesOut > 0 ? '${_naira(feesOut)} due' : null),
            _tile('Announcements', Icons.campaign_outlined, const Color(0xFFFD7E14), 'announcements',
                sub: unread > 0 ? '$unread new' : null),
            _tile('Events', Icons.event_outlined, const Color(0xFF20C997), 'events'),
            _tile('Resources', Icons.collections_bookmark_outlined, const Color(0xFF6610F2), 'resources'),
            _tile('Certificates', Icons.workspace_premium_outlined, const Color(0xFFB8860B), 'certificates'),
            _tile('Character & Skills', Icons.badge_outlined, const Color(0xFF6C757D), 'character'),
          ],
        ),
      ]),
    );
  }

  Widget _tile(String label, IconData icon, Color color, String section, {String? sub}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => widget.onNavigate(section),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            if (sub != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(sub,
                    style: TextStyle(
                        color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
      ),
    );
  }
}
