import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/branding.dart';
import '../core/api_client.dart';
import 'fee_detail_screen.dart';

/// Feature 6 — School Fees (read-only).
/// Summary card (billed / paid / outstanding) + invoice list with status.
class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _summary = const {};
  List<dynamic> _invoices = const [];
  List<dynamic> _sessions = const [];
  Map<String, dynamic> _payInfo = const {};
  int? _sessionId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _all = false;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    var path = '/me/fees';
    if (_all) {
      path += '?session_id=0';
    } else if (_sessionId != null) {
      path += '?session_id=$_sessionId';
    }
    final res = await widget.api.get(path);
    if (!mounted) return;
    if (!res.success) {
      setState(() {
        _loading = false;
        _error = res.friendlyError;
      });
      return;
    }
    setState(() {
      _loading = false;
      _summary = (res.data['summary'] as Map?)?.cast<String, dynamic>() ?? {};
      _invoices = (res.data['invoices'] as List?) ?? const [];
      _sessions = (res.data['sessions'] as List?) ?? const [];
      _payInfo = (res.data['payment_info'] as Map?)?.cast<String, dynamic>() ?? {};
      _sessionId ??= (res.meta['selected_session_id'] as num?)?.toInt();
    });
  }

  String _naira(num n) {
    final s = n.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
    final parts = s.split('.');
    final whole = parts[0].replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '₦${parts.length > 1 ? '$whole.${parts[1]}' : whole}';
  }

  (String, Color) _statusTag(String s) => switch (s) {
        'paid' => ('Paid', Branding.successColor),
        'part_paid' => ('Part paid', const Color(0xFFB8860B)),
        'unpaid' => ('Unpaid', Colors.red.shade700),
        _ => (s, Colors.grey.shade600),
      };

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ListView(children: [
                  const SizedBox(height: 100),
                  Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Center(
                      child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600)),
                  )),
                  const SizedBox(height: 12),
                  Center(
                      child: OutlinedButton(
                          onPressed: _load, child: const Text('Try again'))),
                ])
              : _body(),
    );
  }

  Widget _body() {
    final sessOut = (_summary['session_outstanding'] as num?) ??
        ((_summary['total_outstanding'] as num?) ?? 0);
    final billed = (_summary['session_billed'] as num?) ??
        ((_summary['total_billed'] as num?) ?? 0);
    final paid = (_summary['session_paid'] as num?) ??
        ((_summary['total_paid'] as num?) ?? 0);
    final broughtForward = (_summary['brought_forward'] as num?) ?? 0;
    final outstanding = (_summary['total_due'] as num?) ?? (sessOut + broughtForward);
    final settled = outstanding <= 0;

    return ListView(padding: const EdgeInsets.all(12), children: [
      if (_sessions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DropdownButtonFormField<int>(
            value: _all ? -1 : _sessionId,
            isDense: true,
            decoration: InputDecoration(
              labelText: 'Session',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              const DropdownMenuItem<int>(
                  value: -1, child: Text('All sessions')),
              ..._sessions.map<DropdownMenuItem<int>>((s) => DropdownMenuItem(
                    value: (s['id'] as num).toInt(),
                    child: Text('${s['name']}'),
                  )),
            ],
            onChanged: (v) {
              setState(() { _all = v == -1; if (v != -1) _sessionId = v; });
              _load();
            },
          ),
        ),

      // Outstanding hero
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: (settled ? Branding.successColor : Colors.red.shade700)
              .withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: (settled ? Branding.successColor : Colors.red.shade700)
                  .withOpacity(0.25)),
        ),
        child: Column(children: [
          Text('Total amount due',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 4),
          Text(_naira(outstanding),
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: settled
                      ? Branding.successColor
                      : Colors.red.shade700)),
          const SizedBox(height: 12),
          Row(children: [
            _mini('Billed', _naira(billed)),
            const SizedBox(width: 10),
            _mini('Paid', _naira(paid)),
          ]),
          if (broughtForward > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.history, size: 16, color: Color(0xFF8A6D00)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Previous balance brought forward: ${_naira(broughtForward)}',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A6D00),
                      fontWeight: FontWeight.w600),
                )),
              ]),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 14),

      if ('${_payInfo['account_number'] ?? ''}'.isNotEmpty) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Branding.primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Branding.primaryColor.withOpacity(0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.account_balance, size: 18, color: Branding.primaryColor),
              const SizedBox(width: 8),
              const Text('How to pay',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            Text('Bank: ${_payInfo['bank_name'] ?? ''}',
                style: const TextStyle(fontSize: 13.5)),
            Text('Account name: ${_payInfo['account_name'] ?? ''}',
                style: const TextStyle(fontSize: 13.5)),
            Row(children: [
              Text('Account number: ${_payInfo['account_number'] ?? ''}',
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(
                      text: '${_payInfo['account_number'] ?? ''}'));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Account number copied.')));
                },
                child: Icon(Icons.copy, size: 16, color: Branding.primaryColor),
              ),
            ]),
            const SizedBox(height: 6),
            Text('After paying, open the invoice below and tap "I have paid" to notify the school.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ]),
        ),
        const SizedBox(height: 14),
      ],

      Text('INVOICES',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Colors.grey.shade600)),
      const SizedBox(height: 6),
      if (_invoices.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
              child: Text('No invoices yet.',
                  style: TextStyle(color: Colors.grey.shade600))),
        ),
      ..._invoices.map((inv) {
        final (label, color) = _statusTag('${inv['status']}');
        return Card(
          margin: const EdgeInsets.only(top: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FeeDetailScreen(
                  api: widget.api,
                  invoiceId: (inv['id'] as num).toInt(),
                  payInfo: _payInfo,
                ),
              ),
            ),
            title: Text('${inv['invoice_number']}',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text('${inv['session']} · ${inv['term']}',
                style: const TextStyle(fontSize: 12.5)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_naira((inv['balance'] as num?) ?? 0),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        );
      }),
    ]);
  }

  Widget _mini(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
