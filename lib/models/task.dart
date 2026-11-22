enum TaskStatus {
  todo('todo', 'Belum mulai'),
  inProgress('in_progress', 'Dikerjakan'),
  submitted('submitted', 'Menunggu validasi'),
  approved('approved', 'Disetujui'),
  rejected('rejected', 'Ditolak');

  const TaskStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  /// PIC masih boleh menambah bukti dan submit.
  bool get isEditableByAssignee =>
      this == todo || this == inProgress || this == rejected;

  static TaskStatus fromDb(String value) => TaskStatus.values.firstWhere(
    (s) => s.dbValue == value,
    orElse: () => throw FormatException('Status tidak dikenal: $value'),
  );
}

enum TaskWeight {
  light(1, 'Ringan'),
  medium(2, 'Sedang'),
  heavy(3, 'Berat');

  const TaskWeight(this.value, this.label);

  final int value;
  final String label;

  static TaskWeight fromValue(int value) => TaskWeight.values.firstWhere(
    (w) => w.value == value,
    orElse: () => throw FormatException('Bobot tidak dikenal: $value'),
  );
}

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
  final DateTime? submittedAt;
  final DateTime? approvedAt;

  /// Telat = disubmit setelah deadline, atau belum disubmit padahal deadline lewat.
  bool isLate(DateTime now) {
    final due = deadline;
    if (due == null) return false;
    final doneAt = submittedAt;
    if (doneAt != null) return doneAt.isAfter(due);
    return status != TaskStatus.approved && now.isAfter(due);
  }

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as String,
    groupId: json['group_id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    assigneeId: json['assignee_id'] as String?,
    weight: TaskWeight.fromValue((json['weight'] as num).toInt()),
    deadline: _parseDate(json['deadline']),
    status: TaskStatus.fromDb(json['status'] as String),
    submittedAt: _parseDate(json['submitted_at']),
    approvedAt: _parseDate(json['approved_at']),
  );
}

/// Data untuk membuat tugas baru (belum punya id).
class TaskDraft {
  const TaskDraft({
    required this.groupId,
    required this.title,
    required this.weight,
    this.description,
    this.assigneeId,
    this.deadline,
  });

  final String groupId;
  final String title;
  final String? description;
  final String? assigneeId;
  final TaskWeight weight;
  final DateTime? deadline;

  Map<String, dynamic> toInsertJson() => {
    'group_id': groupId,
    ...toUpdateJson(),
  };

  /// Kolom yang boleh diubah ketua. group_id tidak ikut karena tidak bisa dipindah.
  Map<String, dynamic> toUpdateJson() {
    final desc = description?.trim();
    return {
      'title': title.trim(),
      'description': (desc == null || desc.isEmpty) ? null : desc,
      'assignee_id': assigneeId,
      'weight': weight.value,
      'deadline': deadline?.toUtc().toIso8601String(),
    };
  }
}

class Evidence {
  const Evidence({
    required this.id,
    required this.type,
    required this.url,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String type; // file | image | link
  final String url;
  final String? note;
  final DateTime createdAt;

  bool get isLink => type == 'link';

  factory Evidence.fromJson(Map<String, dynamic> json) => Evidence(
    id: json['id'] as String,
    type: json['type'] as String,
    url: json['url'] as String,
    note: json['note'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class Validation {
  const Validation({
    required this.validatorId,
    required this.approved,
    this.comment,
  });

  final String validatorId;
  final bool approved;
  final String? comment;

  factory Validation.fromJson(Map<String, dynamic> json) => Validation(
    validatorId: json['validator_id'] as String,
    approved: json['approved'] as bool,
    comment: json['comment'] as String?,
  );
}

DateTime? _parseDate(Object? value) =>
    value == null ? null : DateTime.parse(value as String);
