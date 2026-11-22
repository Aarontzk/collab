// Dibuat oleh Gregorius Cahya Khrisna Setiaputra - 5026241122

import 'dart:typed_data';

import 'package:collab/models/task_detail_data.dart';
import 'package:collab/screens/task_form_screen.dart';
import 'package:collab/services/task_detail_service.dart';

/// Service palsu di memori untuk tes screen Detail Tugas. Meniru aturan
/// penting di database: satu penolakan = Ditolak, persetujuan cukup =
/// Disetujui, submit ulang menghapus validasi lama, satu suara per orang.
class FakeTaskDetailService implements TaskDetailService {
  FakeTaskDetailService(
    TaskDetailData task, {
    this.isPic = false,
    this.isLeader = false,
    this.isStudent = true,
    this.members = const [
      TaskFormMember(userId: 'aludra', fullName: 'Aludra Nadia Salwa'),
      TaskFormMember(userId: 'maria', fullName: 'Maria Arum Ningtyas'),
    ],
  }) : task = task.copyWith(
         evidences: [
           for (var i = 0; i < task.evidences.length; i++)
             _withId(task.evidences[i], 'e${i + 1}'),
         ],
       );

  TaskDetailData task;
  final bool isPic;
  final bool isLeader;
  final bool isStudent;
  final List<TaskFormMember> members;

  bool deleted = false;
  bool voted = false;
  int _nextId = 100;

  /// Kalau diisi, setiap aksi melempar ini (untuk menguji tampilan error).
  Object? failWith;
  int loadCalls = 0;
  final uploaded = <String>[];
  final signedFor = <String>[];

  static EvidenceItem _withId(EvidenceItem e, String id) => EvidenceItem(
    id: e.id ?? id,
    kind: e.kind,
    title: e.title,
    subtitle: e.subtitle,
    localPath: e.localPath,
    storagePath: e.storagePath,
  );

  void _check() {
    final error = failWith;
    if (error != null) throw error;
  }

  TaskDetailLoad _snapshot() => TaskDetailLoad(
    task: task,
    groupId: 'g1',
    isPic: isPic,
    isLeader: isLeader,
    canValidate:
        isStudent &&
        !isPic &&
        task.status == TaskDetailStatus.submitted &&
        !voted,
    members: members,
  );

  @override
  Future<TaskDetailLoad> load() async {
    loadCalls++;
    _check();
    return _snapshot();
  }

  @override
  Future<TaskDetailLoad> start() async {
    _check();
    task = task.copyWith(status: TaskDetailStatus.inProgress);
    return _snapshot();
  }

  @override
  Future<String> uploadEvidence({
    required String fileName,
    required Uint8List bytes,
  }) async {
    _check();
    uploaded.add(fileName);
    return 'g1/${task.id}/$fileName';
  }

  @override
  Future<TaskDetailLoad> removeEvidence(EvidenceItem item) async {
    _check();
    task = task.copyWith(
      evidences: task.evidences.where((e) => e.id != item.id).toList(),
    );
    return _snapshot();
  }

  @override
  Future<TaskDetailLoad> submit({
    required List<EvidenceItem> pending,
    String note = '',
  }) async {
    _check();
    task = task.copyWith(
      status: TaskDetailStatus.submitted,
      evidences: [
        ...task.evidences,
        for (final p in pending) _withId(p, 'e${_nextId++}'),
      ],
      workNote: note.isNotEmpty ? note : task.workNote,
      validations: const [],
    );
    voted = false;
    return _snapshot();
  }

  @override
  Future<TaskDetailLoad> validate({
    required bool approved,
    String? comment,
  }) async {
    _check();
    final validations = [
      ...task.validations,
      ValidationEntry(
        validatorName: 'Kamu',
        approved: approved,
        comment: (comment == null || comment.trim().isEmpty)
            ? null
            : comment.trim(),
      ),
    ];
    voted = true;
    final rejected = validations.any((v) => !v.approved);
    final enough =
        validations.where((v) => v.approved).length >= task.requiredApprovals;
    task = task.copyWith(
      validations: validations,
      status: rejected
          ? TaskDetailStatus.rejected
          : (enough ? TaskDetailStatus.approved : task.status),
    );
    return _snapshot();
  }

  @override
  Future<TaskDetailLoad> save(TaskFormValue value) async {
    _check();
    final pic = members.where((m) => m.userId == value.assigneeId).firstOrNull;
    task = task.copyWith(
      title: value.title,
      description: value.description ?? '',
      weight: value.weight,
      deadline: value.deadline,
      picId: value.assigneeId,
      picName: pic?.fullName,
    );
    return _snapshot();
  }

  @override
  Future<void> delete() async {
    _check();
    deleted = true;
  }

  @override
  Future<String> signedUrl(String storagePath) async {
    _check();
    signedFor.add(storagePath);
    return 'https://example.supabase.co/signed/$storagePath?token=x';
  }
}
