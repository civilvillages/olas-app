import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/branding.dart';
import '../state/auth_state.dart';
import 'exams_screen.dart';
import 'results_screen.dart';
import 'fees_screen.dart';
import 'profile_screen.dart';
import 'assignments_screen.dart';
import 'announcements_screen.dart';
import 'events_screen.dart';
import 'resources_screen.dart';

/// Home shell with a drawer that mirrors the portal's student sidebar:
/// Academics (Report Card & Results, CBT / Exams, …) and School Life sections.
/// Items not yet built in the app appear greyed with "soon".
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _Section { exams, results, fees, profile, assignments, announcements, events, resources }

class _HomeScreenState extends State<HomeScreen> {
  _Section _section = _Section.exams;

  String get _title => switch (_section) {
        _Section.exams => 'CBT / Exams',
        _Section.results => 'Report Card & Results',
        _Section.fees => 'School Fees',
        _Section.profile => 'My Profile',
        _Section.assignments => 'My Assignments',
        _Section.announcements => 'Announcements',
        _Section.events => 'Events',
        _Section.resources => 'Learning Resources',
      };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.user;
    final isStudent = user?.isStudent ?? false;

    if (!isStudent) {
      // Staff/other roles: welcome card until their screens are built.
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Branding.primaryColor,
          foregroundColor: Colors.white,
          title: Text(Branding.schoolName),
          actions: [_logoutBtn(context)],
        ),
        body: _welcome(context, user),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Branding.primaryColor,
        foregroundColor: Colors.white,
        title: Text(_title),
        actions: [_logoutBtn(context)],
      ),
      drawer: _drawer(context, user),
      body: switch (_section) {
        _Section.exams => ExamsScreen(api: auth.api),
        _Section.results => ResultsScreen(api: auth.api),
        _Section.fees => FeesScreen(api: auth.api),
        _Section.profile => ProfileScreen(api: auth.api),
        _Section.assignments => AssignmentsScreen(api: auth.api),
        _Section.announcements => AnnouncementsScreen(api: auth.api),
        _Section.events => EventsScreen(api: auth.api),
        _Section.resources => ResourcesScreen(api: auth.api),
      },
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
          // header — mirrors the portal's brand block
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
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ),
              const SizedBox(height: 10),
              Text(user?.fullName ?? '',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              Text(user?.roleName ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
            ]),
          ),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              _sectionHeader('ACADEMICS'),
              _item(
                icon: Icons.assignment_outlined,
                label: 'Report Card & Results',
                selected: _section == _Section.results,
                onTap: () {
                  setState(() => _section = _Section.results);
                  Navigator.pop(context);
                },
              ),
              _item(
                icon: Icons.edit_note,
                label: 'CBT / Exams',
                selected: _section == _Section.exams,
                onTap: () {
                  setState(() => _section = _Section.exams);
                  Navigator.pop(context);
                },
              ),
              _item(icon: Icons.menu_book_outlined, label: 'My Subjects', soon: true),
              _item(icon: Icons.workspace_premium_outlined, label: 'My Certificates', soon: true),
              _item(
                icon: Icons.assignment_ind_outlined,
                label: 'My Assignments',
                selected: _section == _Section.assignments,
                onTap: () {
                  setState(() => _section = _Section.assignments);
                  Navigator.pop(context);
                },
              ),
              _item(icon: Icons.description_outlined, label: 'Exam Registration', soon: true),
              _item(
                icon: Icons.collections_bookmark_outlined,
                label: 'Learning Resources',
                selected: _section == _Section.resources,
                onTap: () {
                  setState(() => _section = _Section.resources);
                  Navigator.pop(context);
                },
              ),
              _sectionHeader('MY ACCOUNT'),
              _item(
                icon: Icons.payments_outlined,
                label: 'School Fees',
                selected: _section == _Section.fees,
                onTap: () {
                  setState(() => _section = _Section.fees);
                  Navigator.pop(context);
                },
              ),
              _item(
                icon: Icons.person_outline,
                label: 'My Profile',
                selected: _section == _Section.profile,
                onTap: () {
                  setState(() => _section = _Section.profile);
                  Navigator.pop(context);
                },
              ),
              _sectionHeader('SCHOOL LIFE'),
              _item(icon: Icons.event_available_outlined, label: 'Attendance', soon: true),
              _item(
                icon: Icons.event_outlined,
                label: 'Events',
                selected: _section == _Section.events,
                onTap: () {
                  setState(() => _section = _Section.events);
                  Navigator.pop(context);
                },
              ),
              _item(
                icon: Icons.campaign_outlined,
                label: 'Announcements',
                selected: _section == _Section.announcements,
                onTap: () {
                  setState(() => _section = _Section.announcements);
                  Navigator.pop(context);
                },
              ),
              _item(icon: Icons.badge_outlined, label: 'Character & Skills', soon: true),
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

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Colors.grey.shade500)),
    );
  }

  Widget _item({
    required IconData icon,
    required String label,
    bool selected = false,
    bool soon = false,
    VoidCallback? onTap,
  }) {
    return ListTile(
      dense: true,
      enabled: !soon,
      selected: selected,
      selectedTileColor: Branding.primaryColor.withOpacity(0.08),
      leading: Icon(icon,
          size: 20,
          color: soon
              ? Colors.grey.shade400
              : (selected ? Branding.primaryColor : Colors.grey.shade700)),
      title: Text(label,
          style: TextStyle(
              fontSize: 14,
              color: soon ? Colors.grey.shade400 : null,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      trailing: soon
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('soon',
                  style:
                      TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
            )
          : null,
      onTap: onTap,
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
                style: const TextStyle(
                    fontSize: 32,
                    color: Colors.white,
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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (yes == true && context.mounted) {
      await context.read<AuthState>().logout();
    }
  }
}
