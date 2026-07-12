import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = const [];
  String _class = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final res = await widget.api.get('/me/subjects');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        _items = (res.data['subjects'] as List?) ?? const [];
        _class = '${res.data['class'] ?? ''}';
      } else { _error = res.friendlyError; }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ListView(children: [
                  const SizedBox(height: 100),
                  Center(child: Text(_error!, style: TextStyle(color: Colors.grey.shade600))),
                  const SizedBox(height: 12),
                  Center(child: OutlinedButton(onPressed: _load, child: const Text('Try again'))),
                ])
              : _items.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 100),
                      Icon(Icons.menu_book_outlined, size: 52, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Center(child: Text('No subjects assigned to $_class yet.',
                          style: TextStyle(color: Colors.grey.shade600))),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final s = _items[i];
                        final elective = (s['is_elective'] as bool?) ?? false;
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Branding.primaryColor.withOpacity(0.09),
                              child: Text('${s['name']}'.isNotEmpty ? '${s['name']}'[0] : '?',
                                  style: TextStyle(
                                      color: Branding.primaryColor,
                                      fontWeight: FontWeight.w700)),
                            ),
                            title: Row(children: [
                              Expanded(child: Text('${s['name']}',
                                  style: const TextStyle(fontWeight: FontWeight.w600))),
                              if (elective)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF4D6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Elective',
                                      style: TextStyle(fontSize: 10.5, color: Color(0xFF8A6D00))),
                                ),
                            ]),
                            subtitle: Text(
                                [if ('${s['code'] ?? ''}'.isNotEmpty) '${s['code']}',
                                 if (s['teacher'] != null) 'Teacher: ${s['teacher']}']
                                    .join(' · '),
                                style: const TextStyle(fontSize: 12.5)),
                          ),
                        );
                      },
                    ),
    );
  }
}
