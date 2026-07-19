import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/branding.dart';
import '../../state/auth_state.dart';
import 'score_picker_screen.dart';
import 'results_screen.dart';
import 'release_screen.dart';
import 'reports_screen.dart';
import 'traits_screen.dart';
import 'cbt_exams_screen.dart';
import 'cbt_bank_screen.dart';
import 'cbt_theory_screen.dart';
import 'cbt_publish_screen.dart';
import 'cbt_reports_screen.dart';
import 'comm_announcements_screen.dart';
import '../messages_screen.dart';
import 'students_screen.dart';
import 'attendance_entry_screen.dart';
import 'finance_screen.dart';

/// Staff shell — Phase A: Dashboard welcome + Score Entry live.
class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  String _section = 'dashboard';
  final List<String> _back = [];
  final List<String> _fwd = [];

  void _go(String s) {
    if (s == _section) return;
    setState(() {
      _back.add(_section);
      _fwd.clear();
      _section = s;
    });
  }

  void _goBack() {
    setState(() {
      if (_back.isNotEmpty) {
        _fwd.add(_section);
        _section = _back.removeLast();
      } else if (_section != 'dashboard') {
        _fwd.add(_section);
        _section = 'dashboard';
      }
    });
  }

  void _goForward() {
    if (_fwd.isEmpty) return;
    setState(() {
      _back.add(_section);
      _section = _fwd.removeLast();
    });
  }

  void _goHome() {
    if (_section == 'dashboard') return;
    setState(() {
      _back.add(_section);
      _fwd.clear();
      _section = 'dashboard';
    });
  }

  void _onPop(bool didPop, Object? result) {
    if (didPop) return;
    if (_section != 'dashboard' || _back.isNotEmpty) {
      _goBack();
    } else {
      SystemNavigator.pop();
    }
  }

  Widget _bottomNav() {
    final canBack = _back.isNotEmpty || _section != 'dashboard';
    return SafeArea(
      top: false,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          IconButton(
            tooltip: 'Back',
            onPressed: canBack ? _goBack : null,
            icon: Icon(Icons.arrow_back_ios_new, size: 20,
                color: canBack ? Colors.grey.shade800 : Colors.grey.shade300),
          ),
          IconButton(
            tooltip: 'Home',
            onPressed: _section == 'dashboard' ? null : _goHome,
            icon: Icon(Icons.home_outlined, size: 24,
                color: _section == 'dashboard'
                    ? Branding.primaryColor
                    : Colors.grey.shade800),
          ),
          IconButton(
            tooltip: 'Forward',
            onPressed: _fwd.isEmpty ? null : _goForward,
            icon: Icon(Icons.arrow_forward_ios, size: 20,
                color: _fwd.isEmpty ? Colors.grey.shade300 : Colors.grey.shade800),
          ),
        ]),
      ),
    );
  }

  static const _titles = {
    'dashboard': 'Staff Dashboard',
    'scores': 'Score Entry',
    'results': 'Results',
    'release': 'Result Release',
    'reports': 'Reports & Analytics',
    'traits': 'Trait Ratings',
    'cbt_exams': 'CBT Exams',
    'cbt_bank': 'Question Bank',
    'cbt_theory': 'Theory Marking',
    'cbt_publish': 'Publish Results',
    'cbt_reports': 'CBT Reports',
    'comm': 'Communication',
    'messages': 'Messages',
    'students': 'Student Management',
    'attendance': 'Attendance',
    'finance': 'Finance',
  };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.user;

    final body = switch (_section) {
      'scores' => ScorePickerScreen(api: auth.api),
      'results' => StaffResultsScreen(api: auth.api),
      'release' => ReleaseScreen(api: auth.api),
      'reports' => ReportsScreen(api: auth.api),
      'traits' => TraitsScreen(api: auth.api),
      'cbt_exams' => CbtExamsScreen(api: auth.api),
      'cbt_bank' => CbtBankScreen(api: auth.api),
      'cbt_theory' => CbtTheoryScreen(api: auth.api),
      'cbt_publish' => CbtPublishScreen(api: auth.api),
      'cbt_reports' => CbtReportsScreen(api: auth.api),
      'comm' => CommAnnouncementsScreen(api: auth.api),
      'messages' => MessagesScreen(api: auth.api),
      'students' => StudentsScreen(api: auth.api),
      'attendance' => AttendanceEntryScreen(api: auth.api),
      'finance' => FinanceScreen(api: auth.api),
      _ => _dashboard(user),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          backgroundColor: Branding.primaryColor,
          foregroundColor: Colors.white,
          title: Text(_titles[_section] ?? Branding.schoolName),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
              onPressed: () => _confirmLogout(context),
            ),
          ],
        ),
        drawer: _drawer(user),
        body: body,
        bottomNavigationBar: _bottomNav(),
      ),
    );
  }

  Drawer _drawer(user) {
    return Drawer(
      child: SafeArea(
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Branding.primaryColor,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                child: Text(user?.initials ?? '?',
                    style: TextStyle(
                        color: Branding.primaryColor,
                        fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              const SizedBox(height: 10),
              Text(user?.fullName ?? '',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              Text(user?.roleName ?? 'Staff',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
            ]),
          ),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              _item(Icons.dashboard_outlined, 'Dashboard', 'dashboard'),
              _header('ASSESSMENT & EXAMINATIONS'),
              _item(Icons.edit_note, 'Score Entry', 'scores'),
              _item(Icons.assessment_outlined, 'Results', 'results'),
              _item(Icons.lock_open_outlined, 'Result Release', 'release'),
              _item(Icons.analytics_outlined, 'Reports & Analytics', 'reports'),
              _item(Icons.badge_outlined, 'Trait Ratings', 'traits'),
              _header('CBT'),
              _item(Icons.quiz_outlined, 'Question Bank', 'cbt_bank'),
              _item(Icons.edit_document, 'Exams', 'cbt_exams'),
              _item(Icons.publish_outlined, 'Publish Results', 'cbt_publish'),
              _item(Icons.rate_review_outlined, 'Theory Marking', 'cbt_theory'),
              _item(Icons.bar_chart_outlined, 'CBT Reports', 'cbt_reports'),
              _header('MORE'),
              _item(Icons.campaign_outlined, 'Communication Center', 'comm'),
              _item(Icons.forum_outlined, 'Messages', 'messages'),
              _item(Icons.groups_outlined, 'Student Management', 'students'),
              _item(Icons.event_available_outlined, 'Attendance', 'attendance'),
              _item(Icons.account_balance_wallet_outlined, 'Finance', 'finance'),
            ]),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, size: 20),
            title: const Text('Sign out'),
            onTap: () {
              Navigator.pop(context);
              _confirmLogout(context);
            },
          ),
        ]),
      ),
    );
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(t,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                letterSpacing: 0.8, color: Colors.grey.shade500)),
      );

  Widget _item(IconData icon, String label, String section) {
    final sel = _section == section;
    return ListTile(
      dense: true,
      selected: sel,
      selectedTileColor: Branding.primaryColor.withOpacity(0.08),
      leading: Icon(icon, size: 20,
          color: sel ? Branding.primaryColor : Colors.grey.shade700),
      title: Text(label,
          style: TextStyle(fontSize: 14,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
      onTap: () {
        _go(section);
        Navigator.pop(context);
      },
    );
  }

  Widget _dashboard(user) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Welcome, ${user?.fullName ?? ''}!',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      Text('Staff portal', style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
      const SizedBox(height: 16),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
        children: [
          _tile('Score Entry', Icons.edit_note, const Color(0xFF198754),
              live: true, section: 'scores'),
          _tile('Results', Icons.assessment_outlined, const Color(0xFF0D6EFD),
              live: true, section: 'results'),
          _tile('Result Release', Icons.lock_open_outlined, const Color(0xFF6F42C1),
              live: true, section: 'release'),
          _tile('Reports & Analytics', Icons.analytics_outlined, const Color(0xFF0DCAF0),
              live: true, section: 'reports'),
          _tile('Trait Ratings', Icons.badge_outlined, const Color(0xFF6C757D),
              live: true, section: 'traits'),
          _tile('Question Bank', Icons.quiz_outlined, const Color(0xFFD63384),
              live: true, section: 'cbt_bank'),
          _tile('CBT Exams', Icons.edit_document, const Color(0xFFFD7E14),
              live: true, section: 'cbt_exams'),
          _tile('Publish Results', Icons.publish_outlined, const Color(0xFF20C997),
              live: true, section: 'cbt_publish'),
          _tile('Theory Marking', Icons.rate_review_outlined, const Color(0xFFB8860B),
              live: true, section: 'cbt_theory'),
          _tile('CBT Reports', Icons.bar_chart_outlined, const Color(0xFF17A2B8),
              live: true, section: 'cbt_reports'),
          _tile('Communication', Icons.campaign_outlined, const Color(0xFFDC3545),
              live: true, section: 'comm'),
          _tile('Messages', Icons.forum_outlined, const Color(0xFF0D6EFD),
              live: true, section: 'messages'),
          _tile('Students', Icons.groups_outlined, const Color(0xFF6610F2),
              live: true, section: 'students'),
          _tile('Attendance', Icons.event_available_outlined, const Color(0xFFFFC107),
              live: true, section: 'attendance'),
          _tile('Finance', Icons.payments_outlined, const Color(0xFF198754),
              live: true, section: 'finance'),
        ],
      ),
    ]);
  }

  Widget _tile(String label, IconData icon, Color color,
      {bool live = false, String? section}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: live && section != null
            ? () => _go(section)
            : () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label is coming in an upcoming build.'))),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 32, color: live ? color : color.withOpacity(0.45)),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: live ? null : Colors.grey.shade500)),
            if (!live)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('soon',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ),
          ]),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to use the app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (yes == true && context.mounted) {
      await context.read<AuthState>().logout();
    }
  }
}
