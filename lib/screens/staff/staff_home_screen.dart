import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/branding.dart';
import '../../state/auth_state.dart';
import 'score_picker_screen.dart';

/// Staff shell — Phase A: Dashboard welcome + Score Entry live.
class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  String _section = 'dashboard';

  static const _titles = {
    'dashboard': 'Staff Dashboard',
    'scores': 'Score Entry',
  };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.user;

    final body = switch (_section) {
      'scores' => ScorePickerScreen(api: auth.api),
      _ => _dashboard(user),
    };

    return Scaffold(
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
              _soon(Icons.assessment_outlined, 'Results'),
              _soon(Icons.lock_open_outlined, 'Result Release'),
              _soon(Icons.analytics_outlined, 'Reports & Analytics'),
              _soon(Icons.badge_outlined, 'Trait Ratings'),
              _header('CBT'),
              _soon(Icons.quiz_outlined, 'Question Bank'),
              _soon(Icons.edit_document, 'Exams'),
              _soon(Icons.publish_outlined, 'Publish Results'),
              _soon(Icons.rate_review_outlined, 'Theory Marking'),
              _header('MORE'),
              _soon(Icons.campaign_outlined, 'Communication Center'),
              _soon(Icons.groups_outlined, 'Student Management'),
              _soon(Icons.event_available_outlined, 'Attendance'),
              _soon(Icons.payments_outlined, 'Finance'),
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
        setState(() => _section = section);
        Navigator.pop(context);
      },
    );
  }

  Widget _soon(IconData icon, String label) => ListTile(
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

  Widget _dashboard(user) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Welcome, ${user?.fullName ?? ''}!',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      Text('Staff portal', style: TextStyle(color: Colors.grey.shade600)),
      const SizedBox(height: 18),
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _section = 'scores'),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Branding.primaryColor.withOpacity(0.3)),
            ),
            child: Row(children: [
              Icon(Icons.edit_note, size: 40, color: Branding.primaryColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Score Entry',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 17)),
                      Text('Enter CA and exam scores for your classes — works offline.',
                          style: TextStyle(
                              fontSize: 12.5, color: Colors.grey.shade600)),
                    ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Text('More staff features are coming in upcoming builds: results, result release, CBT management, communication, students, attendance and finance.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
    ]);
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
