// Dibuat oleh Gregorius Cahya Khrisna Setiaputra - 5026241122

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:collab/models/group.dart';
import 'package:collab/models/task.dart';
import 'package:collab/models/task_detail_data.dart';
import 'package:collab/screens/task_form_screen.dart';
import 'package:collab/services/group_service.dart';
import 'package:collab/services/supabase_service.dart';
import 'package:collab/services/task_service.dart';
import 'package:collab/utils/dates.dart';

/// Satu tugas beserta konteks pengguna yang sedang melihatnya.
class TaskDetailLoad {
  const TaskDetailLoad({
    required this.task,
    required this.groupId,
    required this.isPic,
    required this.isLeader,
    required this.canValidate,
    required this.members,
  });

  final TaskDetailData task;
  final String groupId;

  /// Pengguna adalah PIC (`tasks.assignee_id`) tugas ini.
  final bool isPic;

  /// Pengguna adalah ketua kelompok.
  final bool isLeader;

  /// Pengguna boleh menyetujui atau menolak sekarang: mahasiswa (bukan dosen),
  /// bukan PIC, tugas berstatus Menunggu validasi, dan belum memberi suara.
  final bool canValidate;

  /// Anggota kelompok, untuk memilih PIC di form ubah tugas.
  final List<TaskFormMember> members;
}

/// Akses data screen Detail Tugas. Screen tidak memanggil Supabase langsung
/// (aturan di README), jadi semua lewat kelas ini. Satu objek untuk satu tugas.
///
/// Setiap aksi mengembalikan data terbaru dari server. Status Disetujui atau
/// Ditolak ditentukan trigger di database, bukan oleh aplikasi.
abstract class TaskDetailService {
  Future<TaskDetailLoad> load();

  /// PIC memulai: todo -> in_progress.
  Future<TaskDetailLoad> start();

  /// Unggah foto/file ke Storage. Mengembalikan path di bucket, yang nanti
  /// disimpan di `task_evidences.url` saat [submit].
  Future<String> uploadEvidence({
    required String fileName,
    required Uint8List bytes,
  });

  /// Hapus bukti yang sudah tersimpan (hanya PIC, saat belum diajukan atau
  /// ditolak).
  Future<TaskDetailLoad> removeEvidence(EvidenceItem item);

  /// Simpan bukti baru ([pending]) lalu ajukan validasi. [note] ikut pada
  /// bukti pertama karena baris bukti tidak bisa diubah setelah dibuat.
  Future<TaskDetailLoad> submit({
    required List<EvidenceItem> pending,
    String note = '',
  });

  /// Setuju atau tolak (hanya anggota lain, saat Menunggu validasi).
  Future<TaskDetailLoad> validate({required bool approved, String? comment});

  /// Ubah detail tugas (hanya ketua).
  Future<TaskDetailLoad> save(TaskFormValue value);

  /// Hapus tugas (hanya ketua, belum Disetujui).
  Future<void> delete();

  /// Signed URL sementara untuk membuka foto/file di bucket privat.
  Future<String> signedUrl(String storagePath);
}

/// Implementasi Supabase untuk satu tugas.
///
/// Operasi yang sudah ada di [TaskService] dan [GroupService] (kerangka
/// bersama) dipakai ulang di sini: status, validasi, ubah/hapus tugas, hapus
/// bukti, dan daftar anggota. Yang ditambahkan hanya yang belum ada di sana:
/// upload foto/file ke Storage, signed URL, penyimpanan bukti sekaligus
/// (atomik, dengan catatan), dan penggabungan data untuk layar ini.
///
/// Aturan siapa boleh apa dijaga RLS dan trigger di `supabase/schema.sql`.
class SupabaseTaskDetailService implements TaskDetailService {
  SupabaseTaskDetailService(
    this.taskId, {
    TaskService? tasks,
    GroupService? groups,
  }) : _tasks = tasks ?? TaskService(),
       _groups = groups ?? GroupService();

  final String taskId;
  final TaskService _tasks;
  final GroupService _groups;

  static const _bucket = 'evidences';

  /// Batas bucket: 10 MB per file.
  static const maxFileBytes = 10 * 1024 * 1024;

  /// Jenis file yang diterima bucket (`allowed_mime_types` di schema.sql).
  static const mimeByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'pdf': 'application/pdf',
    'zip': 'application/zip',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  };

  String? _groupId;

  @override
  Future<TaskDetailLoad> load() async {
    final task = await _tasks.fetchTask(taskId);
    final groupId = task.groupId;
    _groupId = groupId;

    final (members, evidences, validations, activeTasks) = await (
      _groups.fetchMembers(groupId),
      _tasks.fetchEvidences(taskId),
      _tasks.fetchValidations(taskId),
      _activeTaskCounts(groupId),
    ).wait;

    final me = currentUserId;
    final myMember = members.byId(me);
    final isPic = task.assigneeId == me;

    // Sama dengan apply_task_validation di schema.sql.
    final required = (members.students.length - 1).clamp(1, 2);
    final iVoted = validations.any((v) => v.validatorId == me);
    final note = evidences
        .map((e) => e.note?.trim() ?? '')
        .firstWhere((n) => n.isNotEmpty, orElse: () => '');

    return TaskDetailLoad(
      groupId: groupId,
      isPic: isPic,
      isLeader: myMember?.role == MemberRole.leader,
      canValidate:
          myMember != null &&
          myMember.role.isStudent &&
          !isPic &&
          task.status == TaskStatus.submitted &&
          !iVoted,
      members: [
        for (final m in members.students)
          TaskFormMember(
            userId: m.userId,
            fullName: m.fullName,
            isLeader: m.role == MemberRole.leader,
            activeTasks: activeTasks[m.userId] ?? 0,
          ),
      ],
      task: TaskDetailData(
        id: task.id,
        title: task.title,
        description: task.description,
        picId: task.assigneeId,
        picName: task.assigneeId == null
            ? 'Belum ada PIC'
            : (members.byId(task.assigneeId!)?.fullName ?? 'Anggota'),
        status: _statusOf(task.status),
        weight: task.weight.value,
        deadline: task.deadline?.toLocal(),
        evidences: [for (final e in evidences) _evidenceOf(e)],
        workNote: note,
        validations: [
          for (final v in validations)
            ValidationEntry(
              validatorName: members.byId(v.validatorId)?.fullName ?? 'Anggota',
              approved: v.approved,
              comment: v.comment,
            ),
        ],
        requiredApprovals: required,
      ),
    );
  }

  @override
  Future<TaskDetailLoad> start() async {
    await _tasks.updateStatus(taskId, TaskStatus.inProgress);
    return _loadExpecting(TaskDetailStatus.inProgress);
  }

  @override
  Future<String> uploadEvidence({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    final mime = mimeByExtension[ext];
    if (mime == null) {
      throw StateError(
        'Jenis file tidak didukung. Pakai JPG, PNG, WEBP, PDF, ZIP, DOCX, '
        'PPTX, atau XLSX.',
      );
    }
    if (bytes.length > maxFileBytes) {
      throw StateError('Ukuran file maksimal 10 MB.');
    }
    final groupId = _groupId ?? (await _tasks.fetchTask(taskId)).groupId;
    // Path wajib {group_id}/{task_id}/{nama_file} (policy storage).
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        '$groupId/$taskId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await supabase.storage
        .from(_bucket)
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
    return path;
  }

  @override
  Future<TaskDetailLoad> removeEvidence(EvidenceItem item) async {
    final id = item.id;
    if (id == null) return load();
    await _tasks.deleteEvidence(id);
    // Bucket belum punya policy hapus, jadi file bisa tertinggal di Storage.
    final path = item.storagePath;
    if (path != null) {
      try {
        await supabase.storage.from(_bucket).remove([path]);
      } catch (_) {
        // Diabaikan: yang penting baris buktinya sudah hilang.
      }
    }
    return load();
  }

  @override
  Future<TaskDetailLoad> submit({
    required List<EvidenceItem> pending,
    String note = '',
  }) async {
    if (pending.isNotEmpty) {
      // Satu insert untuk semua bukti, jadi berhasil semua atau gagal semua.
      await supabase.from('task_evidences').insert([
        for (var i = 0; i < pending.length; i++)
          {
            'task_id': taskId,
            'type': pending[i].kind.name,
            'url': pending[i].kind == EvidenceKind.link
                ? (pending[i].localPath ?? pending[i].title)
                : pending[i].storagePath,
            if (i == 0 && note.isNotEmpty) 'note': note,
          },
      ]);
    }
    await _tasks.updateStatus(taskId, TaskStatus.submitted);
    return _loadExpecting(TaskDetailStatus.submitted);
  }

  @override
  Future<TaskDetailLoad> validate({
    required bool approved,
    String? comment,
  }) async {
    await _tasks.validate(taskId: taskId, approved: approved, comment: comment);
    return load();
  }

  @override
  Future<TaskDetailLoad> save(TaskFormValue value) async {
    final groupId = _groupId ?? (await _tasks.fetchTask(taskId)).groupId;
    await _tasks.updateTask(
      taskId,
      TaskDraft(
        groupId: groupId,
        title: value.title,
        description: value.description,
        assigneeId: value.assigneeId,
        weight: TaskWeight.fromValue(value.weight),
        deadline: value.deadline,
      ),
    );
    return load();
  }

  @override
  Future<void> delete() => _tasks.deleteTask(taskId);

  @override
  Future<String> signedUrl(String storagePath) =>
      supabase.storage.from(_bucket).createSignedUrl(storagePath, 3600);

  /// [TaskService.updateStatus] tidak memeriksa apakah RLS menolaknya (hasilnya
  /// 0 baris tanpa error). Setelah memuat ulang, pastikan status benar-benar
  /// berubah supaya penolakan tidak terlihat seperti sukses.
  Future<TaskDetailLoad> _loadExpecting(TaskDetailStatus expected) async {
    final data = await load();
    if (data.task.status != expected) {
      throw StateError('Kamu tidak punya akses untuk mengubah tugas ini.');
    }
    return data;
  }

  /// Jumlah tugas belum selesai per anggota, untuk daftar PIC di form ubah.
  /// Hanya pelengkap tampilan, jadi kegagalannya tidak menggagalkan layar.
  Future<Map<String, int>> _activeTaskCounts(String groupId) async {
    try {
      final tasks = await _tasks.watchTasks(groupId).first;
      final counts = <String, int>{};
      for (final t in tasks) {
        final id = t.assigneeId;
        if (id != null && t.status != TaskStatus.approved) {
          counts[id] = (counts[id] ?? 0) + 1;
        }
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  static TaskDetailStatus _statusOf(TaskStatus status) => switch (status) {
    TaskStatus.todo => TaskDetailStatus.todo,
    TaskStatus.inProgress => TaskDetailStatus.inProgress,
    TaskStatus.submitted => TaskDetailStatus.submitted,
    TaskStatus.approved => TaskDetailStatus.approved,
    TaskStatus.rejected => TaskDetailStatus.rejected,
  };

  static EvidenceItem _evidenceOf(Evidence e) {
    final when = formatDateTime(e.createdAt);
    if (e.isLink) {
      return EvidenceItem(
        id: e.id,
        kind: EvidenceKind.link,
        title: e.url.replaceFirst(
          RegExp(r'^https?://', caseSensitive: false),
          '',
        ),
        subtitle: 'Tautan · $when',
        localPath: e.url,
      );
    }
    final image = e.type == 'image';
    // Path: {group}/{task}/{epoch}_{nama}. Tampilkan hanya nama aslinya.
    final name = e.url.split('/').last.replaceFirst(RegExp(r'^\d+_'), '');
    return EvidenceItem(
      id: e.id,
      kind: image ? EvidenceKind.image : EvidenceKind.file,
      title: name,
      subtitle: '${image ? 'Foto' : 'File'} di Storage · $when',
      storagePath: e.url,
    );
  }
}
