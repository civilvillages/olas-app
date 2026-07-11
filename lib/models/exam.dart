/// A CBT exam as returned by GET /cbt/exams (available_now / upcoming / past).
class Exam {
  final int id;
  final String title;
  final String description;
  final String instructions;
  final String subject;
  final String term;
  final int durationMinutes;
  final num totalMarks;
  final num passMark;
  final int questionCount;
  final int maxAttempts;
  final int attemptsMade;
  final int attemptsRemaining;
  final bool hasInProgress;
  final int? inProgressAttemptId;
  final bool requiresPassword;
  final String? startAt;
  final String? endAt;
  final String status;

  /// Which bucket the API placed this exam in.
  final String bucket; // 'available_now' | 'upcoming' | 'past'

  Exam({
    required this.id,
    required this.title,
    required this.description,
    required this.instructions,
    required this.subject,
    required this.term,
    required this.durationMinutes,
    required this.totalMarks,
    required this.passMark,
    required this.questionCount,
    required this.maxAttempts,
    required this.attemptsMade,
    required this.attemptsRemaining,
    required this.hasInProgress,
    required this.inProgressAttemptId,
    required this.requiresPassword,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.bucket,
  });

  factory Exam.fromJson(Map<String, dynamic> j, String bucket) => Exam(
        id: (j['id'] as num).toInt(),
        title: (j['title'] as String?) ?? 'Untitled exam',
        description: (j['description'] as String?) ?? '',
        instructions: (j['instructions'] as String?) ?? '',
        subject: (j['subject'] as String?) ?? '',
        term: (j['term'] as String?) ?? '',
        durationMinutes: (j['duration_minutes'] as num?)?.toInt() ?? 0,
        totalMarks: (j['total_marks'] as num?) ?? 0,
        passMark: (j['pass_mark'] as num?) ?? 0,
        questionCount: (j['question_count'] as num?)?.toInt() ?? 0,
        maxAttempts: (j['max_attempts'] as num?)?.toInt() ?? 1,
        attemptsMade: (j['attempts_made'] as num?)?.toInt() ?? 0,
        attemptsRemaining: (j['attempts_remaining'] as num?)?.toInt() ?? 0,
        hasInProgress: (j['has_in_progress'] as bool?) ?? false,
        inProgressAttemptId: (j['in_progress_attempt_id'] as num?)?.toInt(),
        requiresPassword: (j['requires_password'] as bool?) ?? false,
        startAt: j['start_at'] as String?,
        endAt: j['end_at'] as String?,
        status: (j['status'] as String?) ?? 'published',
        bucket: bucket,
      );

  /// A friendly status label + intent for the coloured tag.
  /// Returns (label, kind) where kind is 'open'|'soon'|'done'|'used'.
  (String, String) get tag {
    if (hasInProgress) return ('In progress', 'open');
    if (bucket == 'available_now') {
      if (attemptsRemaining <= 0) return ('Completed', 'used');
      return ('Open now', 'open');
    }
    if (bucket == 'upcoming') return ('Upcoming', 'soon');
    // past
    if (attemptsMade > 0) return ('Completed', 'done');
    return ('Closed', 'used');
  }

  bool get canStart =>
      (bucket == 'available_now' && attemptsRemaining > 0) || hasInProgress;
}
