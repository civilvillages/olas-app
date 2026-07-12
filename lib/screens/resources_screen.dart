import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/branding.dart';
import '../core/api_client.dart';

/// Learning resources — files and links shared with the student's class/school.
class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final res = await widget.api.get('/me/resources');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        _items = (res.data['resources'] as List?) ?? const [];
      } else {
        _error = res.friendlyError;
      }
    });
  }

  String _size(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  IconData _icon(dynamic r) {
    if ('${r['kind']}' == 'link') return Icons.link;
    final mime = '${r['mime'] ?? ''}';
    if (mime.contains('pdf')) return Icons.picture_as_pdf;
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime.contains('word') || mime.contains('document')) return Icons.description_outlined;
    if (mime.contains('sheet') || mime.contains('excel')) return Icons.table_chart_outlined;
    if (mime.startsWith('video/')) return Icons.video_file_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ListView(children: [
                  const SizedBox(height: 110),
                  Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Center(child: Text(_error!, style: TextStyle(color: Colors.grey.shade600))),
                  const SizedBox(height: 12),
                  Center(child: OutlinedButton(onPressed: _load, child: const Text('Try again'))),
                ])
              : _items.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 110),
                      Icon(Icons.collections_bookmark_outlined,
                          size: 52, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Center(child: Text('No learning resources shared yet.',
                          style: TextStyle(color: Colors.grey.shade600))),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _card(_items[i]),
                    ),
    );
  }

  Widget _card(dynamic r) {
    final isLink = '${r['kind']}' == 'link';
    final url = '${r['external_url'] ?? ''}';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Branding.primaryColor.withOpacity(0.09),
          child: Icon(_icon(r), color: Branding.primaryColor, size: 22),
        ),
        title: Text('${r['title']}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
        subtitle: Text(
          [
            if ('${r['subject'] ?? ''}'.isNotEmpty) '${r['subject']}',
            if ('${r['category'] ?? ''}'.isNotEmpty) '${r['category']}',
            if (isLink) 'Link' else '${r['file_name'] ?? ''} ${_size(r['size_bytes'] as int?)}',
          ].join(' · '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: isLink && url.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.copy, size: 19),
                tooltip: 'Copy link',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Link copied — paste it in your browser.')));
                },
              )
            : null,
        onTap: isLink && url.isNotEmpty
            ? () {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Link copied — paste it in your browser.')));
              }
            : () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('File downloads in the app are coming soon — open it on the portal.')));
              },
      ),
    );
  }
}
