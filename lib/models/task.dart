/// Bobot tugas: 1 ringan, 2 sedang, 3 berat (lihat tabel `tasks`).
enum TaskWeight {
  light(1, 'Ringan'),
  medium(2, 'Sedang'),
  heavy(3, 'Berat');

  const TaskWeight(this.points, this.label);

  final int points;
  final String label;

  static TaskWeight fromPoints(int? points) => switch (points) {
    1 => TaskWeight.light,
    3 => TaskWeight.heavy,
    _ => TaskWeight.medium,
  };
}

/// Status tugas, sama dengan enum `task_status` di Supabase.
enum TaskStatus {
  todo('todo', 'Belum mulai'),
  inProgress('in_progress', 'Dikerjakan'),
  submitted('submitted', 'Menunggu validasi'),
  approved('approved', 'Disetujui'),
  rejected('rejected', 'Ditolak');

  const TaskStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static TaskStatus fromDb(String? value) => switch (value) {
    'in_progress' => TaskStatus.inProgress,
    'submitted' => TaskStatus.submitted,
    'approved' => TaskStatus.approved,
    'rejected' => TaskStatus.rejected,
    _ => TaskStatus.todo,
  };
}

/// Satu baris tabel `tasks`.
class Task {
  const Task({
    required this.id,
    required this.groupId,
    required this.title,
    required this.weight,
    required this.status,
    this.description,
    this.assigneeId,
    this.deadline,
    this.createdBy,
    this.createdAt,
    this.submittedAt,
    this.approvedAt,
  });

  final String id;
  final String groupId;
  final String title;
  final String? description;
  final String? assigneeId;
  final TaskWeight weight;
  final DateTime? deadline;
  final TaskStatus status;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? submittedAt;
  final DateTime? approvedAt;

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as String,
    groupId: json['group_id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    assigneeId: json['assignee_id'] as String?,
    weight: TaskWeight.fromPoints((json['weight'] as num?)?.toInt()),
    deadline: _date(json['deadline']),
    status: TaskStatus.fromDb(json['status'] as String?),
    createdBy: json['created_by'] as String?,
    createdAt: _date(json['created_at']),
    submittedAt: _date(json['submitted_at']),
    approvedAt: _date(json['approved_at']),
  );

  bool get isDone => status == TaskStatus.approved;

  bool isLate(DateTime now) {
    final due = deadline;
    if (due == null || isDone) return false;
    return due.isBefore(now);
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}
