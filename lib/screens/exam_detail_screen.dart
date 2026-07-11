import 'package:flutter/material.dart';
import '../config/branding.dart';
import '../core/api_client.dart';
import '../models/exam.dart';

/// Feature 2 — exam detail. Built from the list data (the API has no
/// per-exam detail endpoint yet). Shows a Download button per the plan;
/// wiring to the package endpoint comes in Feature 3.
class ExamDetailScreen extends StatelessWidget {
  const ExamDetailScreen({super.key, required this.api, required this.exam});
  final ApiClient api;
  final Exam exam;

  @override
  Widget build(BuildContext context) {
    final (label, _) = exam.tag;
    return Scaffold(
      appBar: AppBar(title: const Text('Exam details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(exam.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('${exam.subject} · ${exam.term}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 16),

          // Facts grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _row('Questions', '${exam.questionCount}'),
                _row('Duration', '${exam.durationMinutes} minutes'),
                _row('Total marks', '${exam.totalMarks}'),
                _row('Pass mark', '${exam.passMark}'),
                _row('Attempts', '${exam.attemptsMade} of ${exam.maxAttempts} used'),
                if (exam.requiresPassword)
                  _row('Password', 'Required', highlight: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (exam.instructions.trim().isNotEmpty) ...[
            const Text('Instructions',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 6),
            Text(exam.instructions,
                style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
            const SizedBox(height: 20),
          ],

          // Action
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Branding.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: exam.canStart
                  ? () => _notReady(context)
                  : null,
              icon: const Icon(Icons.download_outlined),
              label: Text(exam.hasInProgress
                  ? 'Resume exam'
                  : (exam.canStart ? 'Download & start' : 'Not available')),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              exam.canStart
                  ? 'Downloading works offline once cached.'
                  : (label == 'Completed'
                      ? 'You have completed this exam.'
                      : 'This exam is not open for you right now.'),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  void _notReady(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download & take is coming in the next build.'),
      ),
    );
  }

  Widget _row(String k, String v, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(color: Colors.grey.shade600)),
          Text(v,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: highlight ? Branding.primaryColor : Colors.black87)),
        ],
      ),
    );
  }
}
