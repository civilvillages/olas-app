import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';

/// Feature 6 — one invoice: line items, payments received, balance.
class FeeDetailScreen extends StatefulWidget {
  const FeeDetailScreen(
      {super.key, required this.api, required this.invoiceId, this.payInfo});
  final ApiClient api;
  final int invoiceId;
  final Map<String, dynamic>? payInfo;

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

  Future<void> _claimForm() async {
    final amountCtl = TextEditingController();
    final refCtl = TextEditingController();
    final noteCtl = TextEditingController();
    String method = 'bank_transfer';
    DateTime paidOn = DateTime.now();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('I have paid'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: amountCtl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Amount paid (₦)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: method,
                decoration: const InputDecoration(
                    labelText: 'Payment method', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'bank_transfer', child: Text('Bank transfer')),
                  DropdownMenuItem(value: 'bank_deposit', child: Text('Bank deposit (teller)')),
                  DropdownMenuItem(value: 'pos', child: Text('POS')),
                  DropdownMenuItem(value: 'cash', child: Text('Cash at school')),
                ],
                onChanged: (v) => setSt(() => method = v ?? 'bank_transfer'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: refCtl,
                decoration: const InputDecoration(
                    labelText: 'Reference / teller number',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: paidOn,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setSt(() => paidOn = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Date paid', border: OutlineInputBorder()),
                  child: Text('${paidOn.day}/${paidOn.month}/${paidOn.year}'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Note (optional)', border: OutlineInputBorder()),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Send to school')),
          ],
        ),
      ),
    );
    if (submitted != true || !mounted) return;

    final amount = double.tryParse(amountCtl.text.trim()) ?? 0;
    final iso = '${paidOn.year}-${paidOn.month.toString().padLeft(2, '0')}-${paidOn.day.toString().padLeft(2, '0')}';
    final res = await widget.api.post('/me/fees/${widget.invoiceId}/claim', body: {
      'amount': amount,
      'method': method,
      'reference': refCtl.text.trim(),
      'paid_on': iso,
      'note': noteCtl.text.trim(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.success
          ? '${res.data['message'] ?? 'The school has been notified.'}'
          : res.friendlyError),
      duration: const Duration(seconds: 4),
    ));
    if (res.success) _load();
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
      const SizedBox(height: 10),

      if (!settled)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Branding.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _claimForm,
            icon: const Icon(Icons.check_circle_outline, size: 20),
            label: const Text('I have paid — notify the school',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
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
