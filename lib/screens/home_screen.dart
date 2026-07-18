import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/branding.dart';
import '../state/auth_state.dart';
import 'dashboard_screen.dart';
import 'exams_screen.dart';
import 'results_screen.dart';
import 'report_cards_screen.dart';
import 'fees_screen.dart';
import 'profile_screen.dart';
import 'assignments_screen.dart';
import 'announcements_screen.dart';
import 'events_screen.dart';
import 'resources_screen.dart';
import 'subjects_screen.dart';
import 'certificates_screen.dart';
import 'attendance_screen.dart';
import 'character_screen.dart';
import 'messages_screen.dart';
import 'staff/staff_home_screen.dart';

/// Home shell — Dashboard landing + a drawer mirroring the portal sidebar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _section = 'dashboard';
  final List<String> _back = [];
  final List<String> _fwd = [];

  static const _titles = {
    'dashboard': 'Dashboard',
    'exams': 'CBT / Exams',
    'results': 'CBT Results',
    'reportcards': 'Report Card',
    'fees': 'School Fees',
    'profile': 'My Profile',
    'assignments': 'My Assignments',
    'announcements': 'Announcements',
    'events': 'Events',
    'resources': 'Learning Resources',
    'subjects': 'My Subjects',
    'certificates': 'My Certificates',
    'attendance': 'Attendance',
    'messages': 'Messages',
    'character': 'Character & Skills',
  };

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
      SystemNavigator.pop(); // truly exit only from the dashboard
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.user;
    final isStudent = user?.isStudent ?? false;

    if (!isStudent) {
      return const StaffHomeScreen();
    }

    final body = switch (_section) {
      'dashboard' => DashboardScreen(api: auth.api, onNavigate: _go),
      'exams' => ExamsScreen(api: auth.api),
      'results' => ResultsScreen(api: auth.api),
      'reportcards' => ReportCardsScreen(api: auth.api),
      'fees' => FeesScreen(api: auth.api),
      'profile' => ProfileScreen(api: auth.api),
      'assignments' => AssignmentsScreen(api: auth.api),
      'announcements' => AnnouncementsScreen(api: auth.api),
      'events' => EventsScreen(api: auth.api),
      'resources' => ResourcesScreen(api: auth.api),
      'subjects' => SubjectsScreen(api: auth.api),
      'certificates' => CertificatesScreen(api: auth.api),
      'attendance' => AttendanceScreen(api: auth.api),
      'character' => CharacterScreen(api: auth.api),
      'messages' => MessagesScreen(api: auth.api),
      _ => DashboardScreen(api: auth.api, onNavigate: _go),
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
          actions: [_logoutBtn(context)],
        ),
        drawer: _drawer(context, user),
        body: body,
        bottomNavigationBar: _bottomNav(),
      ),
    );
  }

  Widget _logoutBtn(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Sign out',
      onPressed: () => _confirmLogout(context),
    );
  }

  Drawer _drawer(BuildContext context, user) {
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
              Text(user?.roleName ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
            ]),
          ),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              _item(Icons.dashboard_outlined, 'Dashboard', 'dashboard'),
              _header('ACADEMICS'),
              _item(Icons.assessment_outlined, 'Report Card', 'reportcards'),
              _item(Icons.edit_note, 'CBT / Exams', 'exams'),
              _item(Icons.fact_check_outlined, 'CBT Results', 'results'),
              _item(Icons.menu_book_outlined, 'My Subjects', 'subjects'),
              _item(Icons.assignment_ind_outlined, 'My Assignments', 'assignments'),
              _item(Icons.workspace_premium_outlined, 'My Certificates', 'certificates'),
              _item(Icons.collections_bookmark_outlined, 'Learning Resources', 'resources'),
              _soon(Icons.description_outlined, 'Exam Registration'),
              _header('SCHOOL LIFE'),
              _item(Icons.event_available_outlined, 'Attendance', 'attendance'),
              _item(Icons.event_outlined, 'Events', 'events'),
              _item(Icons.campaign_outlined, 'Announcements', 'announcements'),
              _item(Icons.forum_outlined, 'Messages', 'messages'),
              _item(Icons.badge_outlined, 'Character & Skills', 'character'),
              _header('MY ACCOUNT'),
              _item(Icons.payments_outlined, 'School Fees', 'fees'),
              _item(Icons.person_outline, 'My Profile', 'profile'),
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

  Widget _header(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 0.8, color: Colors.grey.shade500)),
    );
  }

  Widget _item(IconData icon, String label, String section) {
    final selected = _section == section;
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: Branding.primaryColor.withOpacity(0.08),
      leading: Icon(icon, size: 20,
          color: selected ? Branding.primaryColor : Colors.grey.shade700),
      title: Text(label,
          style: TextStyle(fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      onTap: () {
        _go(section);
        Navigator.pop(context);
      },
    );
  }

  Widget _soon(IconData icon, String label) {
    return ListTile(
      dense: true,
      enabled: false,
      leading: Icon(icon, size: 20, color: Colors.grey.shade400),
      title: Text(label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('soon',
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
      ),
    );
  }

  Widget _welcome(BuildContext context, user) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: Branding.primaryColor,
            child: Text(user?.initials ?? '?',
                style: const TextStyle(fontSize: 32, color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          Text('Welcome, ${user?.fullName ?? 'there'}!',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          if (user?.roleName != null)
            Chip(
              label: Text(user!.roleName!),
              backgroundColor: Branding.primaryColor.withOpacity(0.1),
            ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'You are signed in as ${user?.roleName ?? 'staff'}.\n\n'
                'Your dashboard is coming in an upcoming build. The student '
                'experience is being completed first.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ]),
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
