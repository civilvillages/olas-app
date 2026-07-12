import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';

class CharacterScreen extends StatefulWidget {
  const CharacterScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _domains = const {};
  List<dynamic> _terms = const [];
  int? _termId;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    var path = '/me/character';
    if (_termId != null) path += '?term_id=$_termId';
    final res = await widget.api.get(path);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        _domains = (res.data['domains'] as Map?)?.cast<String, dynamic>() ?? {};
        _terms = (res.data['terms'] as List?) ?? const [];
        _termId ??= (res.meta['selected_term_id'] as num?)?.toInt();
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
                  Icon(Icons.lock_outline, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Center(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(_error!, textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600)),
                  )),
                ])
              : _body(),
    );
  }

  Widget _body() {
    final children = <Widget>[];
    if (_terms.isNotEmpty) {
      children.add(DropdownButtonFormField<int>(
        value: _termId,
        isDense: true,
        decoration: InputDecoration(
          labelText: 'Term',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: _terms
            .map<DropdownMenuItem<int>>((t) => DropdownMenuItem(
                value: (t['id'] as num).toInt(),
                child: Text('${t['session']} · ${t['name']}',
                    overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: (v) { setState(() => _termId = v); _load(); },
      ));
      children.add(const SizedBox(height: 12));
    }
    if (_domains.isEmpty) {
      children.addAll([
        const SizedBox(height: 60),
        Icon(Icons.badge_outlined, size: 52, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Center(child: Text('No ratings recorded for this term yet.',
            style: TextStyle(color: Colors.grey.shade600))),
      ]);
    } else {
      _domains.forEach((domain, traits) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 8),
          child: Text(domain.toUpperCase(),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  letterSpacing: 0.5, color: Colors.grey.shade600)),
        ));
        for (final t in (traits as List)) {
          final rating = (t['rating'] as num?)?.toInt() ?? 0;
          children.add(Card(
            margin: const EdgeInsets.only(bottom: 6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                Expanded(child: Text('${t['trait']}',
                    style: const TextStyle(fontSize: 14))),
                Row(children: List.generate(5, (i) => Icon(
                      i < rating ? Icons.star : Icons.star_border,
                      size: 18,
                      color: i < rating
                          ? const Color(0xFFB8860B)
                          : Colors.grey.shade300,
                    ))),
              ]),
            ),
          ));
        }
      });
    }
    return ListView(padding: const EdgeInsets.all(12), children: children);
  }
}
