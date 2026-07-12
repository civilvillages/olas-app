import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';

/// Feature 6 — one invoice: line items, payments received, balance.
class FeeDetailScreen extends StatefulWidget {
  const FeeDetailScreen(
      {super.key, required this.api, required this.invoiceId});
  final ApiClient api;
  final int invoiceId;

  @override
  State<FeeDetailScreen> createState() => _FeeDetailScreenState();
}

class _FeeDetailScreenState extends State<FeeDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _inv = const {};
  List<dynamic> _lines = const [];
  List<dynamic> _payments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await widget.api.get('/me/fees/${widget.invoiceId}');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        _inv = (res.data['invoice'] as Map?)?.cast<String, dynamic>() ?? {};
        _lines = (res.data['lines'] as List?) ?? const [];
        _payments = (res.data['payments'] as List?) ?? const [];
      } else {
        _error = res.friendlyError;
      }
    });
  }

  String _naira(num n) {
    final s = n.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
    final parts = s.split('.');
    final whole = parts[0].replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '₦${parts.length > 1 ? '$whole.${parts[1]}' : whole}';
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Branding.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Invoice'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(_error!, textAlign: TextAlign.center),
                ))
              : _body(),
    );
  }

  Widget _body() {
    final balance = (_inv['balance'] as num?) ?? 0;
    final paid = (_inv['amount_paid'] as num?) ?? 0;
    final net = (_inv['net_amount'] as num?) ?? 0;
    final discount = (_inv['discount'] as num?) ?? 0;
    final settled = balance <= 0;

    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('${_inv['invoice_number'] ?? ''}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Text('${_inv['session'] ?? ''} · ${_inv['term'] ?? ''} · issued ${_fmtDate('${_inv['created_at'] ?? ''}')}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      const SizedBox(height: 16),

      // Balance banner
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (settled ? Branding.successColor : Colors.red.shade700)
              .withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: (settled ? Branding.successColor : Colors.red.shade700)
                  .withOpacity(0.25)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(settled ? 'Fully paid' : 'Balance due',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(_naira(balance),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: settled
                      ? Branding.successColor
                      : Colors.red.shade700)),
        ]),
      ),
      const SizedBox(height: 16),

      // Line items
      Text('FEE BREAKDOWN',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Colors.grey.shade600)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(children: [
          ..._lines.map((l) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${l['name']}')),
                      Text(_naira((l['amount'] as num?) ?? 0),
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
              )),
          if (discount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Discount',
                        style: TextStyle(color: Branding.successColor)),
                    Text('-${_naira(discount)}',
                        style: TextStyle(
                            color: Branding.successColor,
                            fontWeight: FontWeight.w600)),
                  ]),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child:
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(_naira(net),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),

      // Payments
      Text('PAYMENTS (${_payments.length})',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Colors.grey.shade600)),
      const SizedBox(height: 6),
      if (_payments.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
              child: Text('No payments recorded yet.',
                  style: TextStyle(color: Colors.grey.shade600))),
        ),
      ..._payments.map((p) => Card(
            margin: const EdgeInsets.only(top: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(Icons.receipt_long,
                  color: Branding.successColor, size: 22),
              title: Text(_naira((p['amount'] as num?) ?? 0),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  '${p['method'] ?? ''} · ${p['reference'] ?? ''}\n${_fmtDate('${p['paid_at'] ?? ''}')}',
                  style: const TextStyle(fontSize: 12)),
              isThreeLine: true,
            ),
          )),
      const SizedBox(height: 10),
      Center(
        child: Text('Total paid so far: ${_naira(paid)}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      ),
    ]);
  }
}
