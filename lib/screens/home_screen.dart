import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/branding.dart';
import '../state/auth_state.dart';
import 'exams_screen.dart';

/// Home. Students land on My Exams; other roles see a welcome card for now
/// (their dedicated screens arrive in later builds).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.user;
    final isStudent = user?.isStudent ?? false;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Branding.primaryColor,
        foregroundColor: Colors.white,
        title: Text(isStudent ? 'My Exams' : Branding.schoolName),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: isStudent
          ? ExamsScreen(api: auth.api)
          : _welcome(context, user),
    );
  }

  Widget _welcome(BuildContext context, user) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                  'exam experience is being built first.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
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
