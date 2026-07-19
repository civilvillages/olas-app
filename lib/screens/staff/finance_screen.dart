import 'package:flutter/material.dart';
import '../../config/branding.dart';
import '../../core/api_client.dart';

/// Finance — invoice overview by class/term, invoice detail, record payment.
/// Plus: set the school bank account that parents see and pay into.
class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _classes = const [];
  List<dynamic> _terms = const [];
  List<dynamic> _invoices = const [];
  int? _classId;
  int? _termId;
  bool _listLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _listLoading = _classId != null && _termId != null);
    var path = '/staff/fees';
    if (_classId != null && _termId != null) {
      path += '?class_id=$_classId&term_id=$_termId';
    }
    final res = await widget.api.get(path);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _listLoading = false;
      if (res.success) {
        _invoices = (res.data['invoices'] as List?) ?? const [];
        final cls = (res.data['classes'] as List?) ?? const [];
        final trm = (res.data['terms'] as List?) ?? const [];
        if (cls.isNotEmpty) _classes = cls;
        if (trm.isNotEmpty) _terms = trm;
        _error = null;
      } else {
        _error = res.friendlyError;
      }
    });
  }

  Future<void> _bankSheet() async {
    final res = await widget.api.get('/staff/settings/bank');
    if (!mounted) return;
    if (!res.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.friendlyError)));
      return;
    }
    final bank = (res.data['bank'] as Map?)?.cast<String, dynamic>() ?? {};
    final nameCtl = TextEditingController(text: '${bank['bank_name'] ?? ''}');
    final acctNameCtl =
        TextEditingController(text: '${bank['account_name'] ?? ''}');
    final acctNumCtl =
        TextEditingController(text: '${bank['account_number'] ?? ''}');
    var saving = false;

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.account_balance, color: Branding.primaryColor),
              const SizedBox(width: 8),
              const Text('School bank account',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
            const SizedBox(height: 4),
            Text('Parents see these details on their fees page and pay into this account.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtl,
              decoration: _bankDec('Bank name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: acctNameCtl,
              decoration: _bankDec('Account name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: acctNumCtl,
              keyboardType: TextInputType.number,
              decoration: _bankDec('Account number'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Branding.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: saving
                    ? null
                    : () async {
                        setSt(() => saving = true);
                        final r = await widget.api
                            .post('/staff/settings/bank', body: {
                          'bank_name': nameCtl.text.trim(),
                          'account_name': acctNameCtl.text.trim(),
                          'account_number': acctNumCtl.text.trim(),
                        });
                        setSt(() => saving = false);
                        if (!ctx.mounted) return;
                        if (r.success) {
                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Bank details saved — parents can now see them.')));
                          }
                        } else {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(r.friendlyError)));
                        }
                      },
                child: Text(saving ? 'Saving…' : 'Save bank details',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
    nameCtl.dispose();
    acctNameCtl.dispose();
    acctNumCtl.dispose();
  }

  InputDecoration _bankDec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8F9FB),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline, size: 44, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(_error!, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
        ]),
      ));
    }

    num tot = 0, paid = 0, bal = 0;
    for (final i in _invoices) {
      tot += (i['total'] as num?) ?? 0;
      paid += (i['paid'] as num?) ?? 0;
      bal += (i['balance'] as num?) ?? 0;
    }

    return ListView(padding: const EdgeInsets.all(14), children: [
      // Bank-details setup card — the missing admin-side piece of #9.
      Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Branding.primaryColor.withOpacity(0.25)),
        ),
        color: Branding.primaryColor.withOpacity(0.04),
        child: ListTile(
          leading: Icon(Icons.account_balance, color: Branding.primaryColor),
          title: const Text('School bank account',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          subtitle: const Text('Set the account parents pay into',
              style: TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right),
          onTap: _bankSheet,
        ),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: DropdownButtonFormField<int>(
          value: _classId,
          isExpanded: true,
          decoration: _dec('Class'),
          hint: const Text('Class'),
          items: _classes.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(
                value: (c['id'] as num).toInt(),
                child: Text('${c['name']}', overflow: TextOverflow.ellipsis),
              )).toList(),
          onChanged: (v) { setState(() => _classId = v); _load(); },
        )),
        const SizedBox(width: 8),
        Expanded(child: DropdownButtonFormField<int>(
          value: _termId,
          isExpanded: true,
          decoration: _dec('Term'),
          hint: const Text('Term'),
          items: _terms.map<DropdownMenuItem<int>>((t) => DropdownMenuItem(
                value: (t['id'] as num).toInt(),
                child: Text('${t['name']}', overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
              )).toList(),
          onChanged: (v) { setState(() => _termId = v); _load(); },
        )),
      ]),
      const SizedBox(height: 10),

      if (_listLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 50),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_classId != null && _termId != null) ...[
        Row(children: [
          _mini('Invoiced', tot),
          const SizedBox(width: 8),
          _mini('Paid', paid),
          const SizedBox(width: 8),
          _mini('Outstanding', bal),
        ]),
        const SizedBox(height: 8),
        if (_invoices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text(
                'No invoices for this class and term. Generate them on the web.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600))),
          ),
        ..._invoices.map(_invoiceCard),
      ] else
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text('Pick class and term to see invoices.',
              style: TextStyle(color: Colors.grey.shade600))),
        ),
    ]);
  }

  String _n(num v) => v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);

  Widget _mini(String label, num v) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: [
            Text('₦${_n(v)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            Text(label, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
          ]),
        ),
      );

  Widget _invoiceCard(dynamic inv) {
    final balance = (inv['balance'] as num?) ?? 0;
    final settled = balance <= 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        title: Text('${inv['student']}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(
            '${inv['invoice_number']} · ₦${_n((inv['paid'] as num?) ?? 0)} of ₦${_n((inv['total'] as num?) ?? 0)} paid',
            style: const TextStyle(fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: settled
                ? Branding.successColor.withOpacity(0.1)
                : const Color(0xFFFFF4D6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(settled ? 'settled' : '₦${_n(balance)} due',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800,
                  color: settled ? Branding.successColor : const Color(0xFF8A6D00))),
        ),
        onTap: () async {
          final changed = await Navigator.push<bool>(context, MaterialPageRoute(
              builder: (_) => _InvoiceScreen(api: widget.api,
                  invoiceId: (inv['invoice_id'] as num).toInt())));
          if (changed == true) _load();
        },
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      );
}

/// One invoice: items, payments, balance — and Record payment.
class _InvoiceScreen extends StatefulWidget {
  const _InvoiceScreen({required this.api, required this.invoiceId});
  final ApiClient api;
  final int invoiceId;

  @override
  State<_InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<_InvoiceScreen> {
  bool _loading = true;
  Map<String, dynamic> _inv = const {};
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await widget.api.get('/staff/fees/invoice/${widget.invoiceId}');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        _inv = (res.data['invoice'] as Map?)?.cast<String, dynamic>() ?? const {};
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res.friendlyError)));
      }
    });
  }

  String _n(num v) => v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);

  @override
  Widget build(BuildContext context) {
    final balance = (_inv['balance'] as num?) ?? 0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          backgroundColor: Branding.primaryColor,
          foregroundColor: Colors.white,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_inv['student'] ?? 'Invoice'}',
                style: const TextStyle(fontSize: 16)),
            Text('${_inv['invoice_number'] ?? ''} · ${_inv['term'] ?? ''}',
                style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
          ]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(14), children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(children: [
                      Text('₦${_n((_inv['total'] as num?) ?? 0)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text('Total', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                    ])),
                    Expanded(child: Column(children: [
                      Text('₦${_n((_inv['paid'] as num?) ?? 0)}',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15,
                              color: Branding.successColor)),
                      Text('Paid', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                    ])),
                    Expanded(child: Column(children: [
                      Text('₦${_n(balance)}',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15,
                              color: balance > 0 ? const Color(0xFF8A6D00) : Branding.successColor)),
                      Text('Balance', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                    ])),
                  ]),
                ),
                if (((_inv['student_credit'] as num?) ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Branding.primaryColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                          'Student credit on file: ₦${_n((_inv['student_credit'] as num))}',
                          style: TextStyle(fontSize: 12.5, color: Branding.primaryColor,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),

                const SizedBox(height: 12),
                Text('ITEMS', style: _h()),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(children: [
                    for (final it in (_inv['items'] as List? ?? const []))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          Expanded(child: Text('${it['description']}',
                              style: const TextStyle(fontSize: 13))),
                          Text('₦${_n((it['amount'] as num?) ?? 0)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                  ]),
                ),

                const SizedBox(height: 12),
                Text('PAYMENTS', style: _h()),
                if ((_inv['payments'] as List? ?? const []).isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('No payments recorded yet.',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500))),
                  ),
                for (final p in (_inv['payments'] as List? ?? const []))
                  Card(
                    margin: const EdgeInsets.only(top: 6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text('₦${_n((p['amount'] as num?) ?? 0)} · ${p['method']}',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          '${p['date'] ?? ''}'
                          '${'${p['reference'] ?? ''}'.isNotEmpty ? ' · ref ${p['reference']}' : ''}'
                          '${'${p['note'] ?? ''}'.isNotEmpty ? '\n${p['note']}' : ''}',
                          style: const TextStyle(fontSize: 11.5)),
                    ),
                  ),
                const SizedBox(height: 90),
              ]),
        floatingActionButton: _loading ? null : FloatingActionButton.extended(
          backgroundColor: Branding.successColor,
          foregroundColor: Colors.white,
          onPressed: _recordSheet,
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Record payment'),
        ),
      ),
    );
  }

  TextStyle _h() => TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
      letterSpacing: 0.5, color: Colors.grey.shade600);

  Future<void> _recordSheet() async {
    final amountCtl = TextEditingController();
    final refCtl = TextEditingController();
    final noteCtl = TextEditingController();
    var method = 'cash';
    var sending = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Record payment — ${_inv['student']}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          Text('Balance ₦${_n((_inv['balance'] as num?) ?? 0)} — any excess becomes student credit.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          TextField(
            controller: amountCtl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              labelText: 'Amount received (₦) *',
              filled: true, fillColor: const Color(0xFFF8F9FB), isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: method,
            decoration: InputDecoration(
              labelText: 'Method',
              filled: true, fillColor: const Color(0xFFF8F9FB), isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'transfer', child: Text('Bank transfer')),
              DropdownMenuItem(value: 'pos', child: Text('POS')),
              DropdownMenuItem(value: 'manual', child: Text('Other / manual')),
            ],
            onChanged: (v) => setSt(() => method = v ?? 'cash'),
          ),
          const SizedBox(height: 10),
          TextField(controller: refCtl, decoration: InputDecoration(
            labelText: 'Reference (optional)',
            filled: true, fillColor: const Color(0xFFF8F9FB), isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          )),
          const SizedBox(height: 10),
          TextField(controller: noteCtl, decoration: InputDecoration(
            labelText: 'Note (optional)',
            filled: true, fillColor: const Color(0xFFF8F9FB), isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          )),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Branding.successColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: sending ? null : () async {
                final amount = double.tryParse(amountCtl.text.trim()) ?? 0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Enter an amount greater than zero.')));
                  return;
                }
                setSt(() => sending = true);
                final res = await widget.api.post(
                    '/staff/fees/invoice/${widget.invoiceId}/pay',
                    body: {
                      'amount': amount,
                      'method': method,
                      'reference': refCtl.text.trim(),
                      'note': noteCtl.text.trim(),
                    });
                setSt(() => sending = false);
                if (!ctx.mounted) return;
                if (res.success) {
                  Navigator.pop(ctx);
                  final credited = (res.data['credited'] as num?) ?? 0;
                  var msg = 'Payment of ₦${_n((res.data['applied'] as num?) ?? 0)} recorded.';
                  if (credited > 0) {
                    msg += ' Overpayment of ₦${_n(credited)} added to student credit.';
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(msg), duration: const Duration(seconds: 5)));
                  }
                  _changed = true;
                  _load();
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(res.friendlyError)));
                }
              },
              child: Text(sending ? 'Recording…' : 'Record payment',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      )),
    );
    amountCtl.dispose();
    refCtl.dispose();
    noteCtl.dispose();
  }
}
