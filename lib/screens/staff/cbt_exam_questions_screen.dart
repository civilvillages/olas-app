import 'package:flutter/material.dart';
import '../../config/branding.dart';
import '../../core/api_client.dart';

/// Questions attached to one exam: view, attach from the bank (manual or
/// random), remove. Bank copies are never touched by removal.
class CbtExamQuestionsScreen extends StatefulWidget {
  const CbtExamQuestionsScreen({super.key, required this.api, required this.exam});
  final ApiClient api;
  final dynamic exam; // mapExam row from the list

  @override
  State<CbtExamQuestionsScreen> createState() => _CbtExamQuestionsScreenState();
}

class _CbtExamQuestionsScreenState extends State<CbtExamQuestionsScreen> {
  bool _loading = true;
  List<dynamic> _questions = const [];
  num _totalMarks = 0;
  bool _busy = false;

  int get _examId => (widget.exam['id'] as num).toInt();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await widget.api.get('/cbt/manage/exams/$_examId/questions');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        _questions = (res.data['questions'] as List?) ?? const [];
        _totalMarks = (res.meta['total_marks'] as num?) ?? 0;
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res.friendlyError)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Branding.primaryColor,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Exam questions', style: TextStyle(fontSize: 16)),
          Text('${widget.exam['title']}',
              style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Branding.primaryColor.withOpacity(0.06),
                child: Text(
                    '${_questions.length} question(s) · $_totalMarks marks total '
                    '(exam is set to ${widget.exam['total_marks']})',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              Expanded(
                child: _questions.isEmpty
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                            'No questions yet. Attach some from the bank below — the exam cannot be published while empty.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600)),
                      ))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
                        itemCount: _questions.length,
                        itemBuilder: (ctx, i) => _qCard(_questions[i], i),
                      ),
              ),
            ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Branding.primaryColor,
        foregroundColor: Colors.white,
        onPressed: _busy ? null : _attachSheet,
        icon: const Icon(Icons.add),
        label: const Text('Attach from bank'),
      ),
    );
  }

  Widget _qCard(dynamic q, int i) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${i + 1}. ',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Expanded(child: Text('${q['text']}',
                maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5))),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
              onPressed: () => _remove(q),
            ),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: [
            _chip('${q['type']}'.replaceAll('_', ' '), Branding.primaryColor),
            _chip('${q['marks']} marks', const Color(0xFFB8860B)),
            if ((q['options'] as List?)?.isNotEmpty ?? false)
              _chip('${(q['options'] as List).length} options', Colors.grey.shade600),
          ]),
        ]),
      ),
    );
  }

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(t, style: TextStyle(fontSize: 10.5, color: c,
            fontWeight: FontWeight.w600)),
      );

  Future<void> _remove(dynamic q) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove question from exam?'),
        content: const Text('The question stays in the bank — only this exam loses it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    final res = await widget.api
        .delete('/cbt/manage/exams/$_examId/questions/${q['link_id']}');
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success) {
      _load();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.friendlyError)));
    }
  }

  Future<void> _attachSheet() async {
    final exam = widget.exam;
    var mode = 'manual';
    var termNumber = 0; // bank term number filter — start with exam's term if known
    final marksCtl = TextEditingController();
    final nCtl = TextEditingController(text: '10');
    List<dynamic> bank = const [];
    final picked = <int>{};
    var bankLoading = false;
    var available = 0;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        Future<void> loadBank() async {
          if (termNumber == 0) return;
          setSt(() => bankLoading = true);
          final res = await widget.api.get(
              '/cbt/manage/bank?class_id=${exam['class_id']}&term_number=$termNumber'
              '&subject_id=${exam['subject_id']}&exam_id=$_examId');
          setSt(() {
            bankLoading = false;
            if (res.success) {
              bank = (res.data['questions'] as List?) ?? const [];
              available = (res.meta['available'] as num?)?.toInt() ?? 0;
            }
          });
        }

        return Padding(
          padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.78,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Attach questions from the bank',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text('${exam['subject_name']} · ${exam['class_name']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'manual', label: Text('Pick manually')),
                    ButtonSegment(value: 'random', label: Text('Random N')),
                  ],
                  selected: {mode},
                  onSelectionChanged: (s) => setSt(() => mode = s.first),
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                const Text('Bank term: ', style: TextStyle(fontSize: 13)),
                ...[1, 2, 3].map((t) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text('Term $t', style: const TextStyle(fontSize: 12)),
                        selected: termNumber == t,
                        onSelected: (_) {
                          setSt(() => termNumber = t);
                          loadBank();
                        },
                      ),
                    )),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: marksCtl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Marks per question (optional override)',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              if (mode == 'random') ...[
                TextField(
                  controller: nCtl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'How many random questions?',
                    helperText: termNumber == 0
                        ? 'Pick a bank term above first'
                        : '$available available in this bank',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
              if (mode == 'manual')
                Expanded(
                  child: termNumber == 0
                      ? Center(child: Text('Pick a bank term above to browse questions.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)))
                      : bankLoading
                          ? const Center(child: CircularProgressIndicator())
                          : bank.isEmpty
                              ? Center(child: Text('This bank is empty.',
                                  style: TextStyle(color: Colors.grey.shade600)))
                              : ListView.builder(
                                  itemCount: bank.length,
                                  itemBuilder: (ctx2, i) {
                                    final q = bank[i];
                                    final qid = (q['question_id'] as num).toInt();
                                    final inExam = q['already_in_exam'] == true;
                                    return CheckboxListTile(
                                      dense: true,
                                      value: inExam || picked.contains(qid),
                                      onChanged: inExam
                                          ? null
                                          : (v) => setSt(() => v == true
                                              ? picked.add(qid)
                                              : picked.remove(qid)),
                                      title: Text('${q['text']}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 13,
                                              color: inExam ? Colors.grey.shade400 : null)),
                                      subtitle: Text(
                                          '${q['type']} · ${q['marks']} marks'
                                          '${inExam ? ' · already in exam' : ''}',
                                          style: const TextStyle(fontSize: 11)),
                                    );
                                  },
                                ),
                )
              else
                const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Branding.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () async {
                    if (termNumber == 0) return;
                    final body = <String, dynamic>{
                      'mode': mode,
                      if (marksCtl.text.trim().isNotEmpty)
                        'marks_override': marksCtl.text.trim(),
                    };
                    if (mode == 'manual') {
                      if (picked.isEmpty) return;
                      body['question_ids'] = picked.toList();
                    } else {
                      body['n'] = int.tryParse(nCtl.text) ?? 0;
                      body['src_class_id'] = exam['class_id'];
                      body['src_term_number'] = termNumber;
                      body['src_subject_id'] = exam['subject_id'];
                    }
                    final res = await widget.api.post(
                        '/cbt/manage/exams/$_examId/questions', body: body);
                    if (!ctx.mounted) return;
                    if (res.success) {
                      Navigator.pop(ctx);
                    } else {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(res.friendlyError)));
                    }
                  },
                  child: Text(mode == 'manual'
                      ? 'Attach selected'
                      : 'Attach random set',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        );
      }),
    );
    marksCtl.dispose();
    nCtl.dispose();
    _load();
  }
}
