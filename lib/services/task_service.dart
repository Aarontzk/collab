import 'package:collab/services/supabase_service.dart';
import 'package:collab/models/task.dart';

class TaskService {
  /// Daftar tugas yang update realtime saat anggota lain mengubahnya.
  Stream<List<Task>> watchTasks(String groupId) {
    return supabase
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('created_at')
        .map((rows) => rows.map(Task.fromJson).toList());
  }

  Future<Task> fetchTask(String taskId) async {
    final row = await supabase.from('tasks').select().eq('id', taskId).single();
    return Task.fromJson(row);
  }

  Future<void> createTask(TaskDraft draft) async {
    await supabase.from('tasks').insert(draft.toInsertJson());
  }

  /// Hanya ketua, dan tugas yang sudah disetujui ditolak database.
  Future<void> updateTask(String taskId, TaskDraft draft) async {
    final updated = await supabase
        .from('tasks')
        .update(draft.toUpdateJson())
        .eq('id', taskId)
        .select('id');
    if (updated.isEmpty) {
      throw StateError('Tugas tidak bisa diubah');
    }
  }

  /// Hanya ketua, dan tugas yang sudah disetujui tidak bisa dihapus.
  /// Bukti dan validasinya ikut terhapus (on delete cascade).
  Future<void> deleteTask(String taskId) async {
    final deleted = await supabase
        .from('tasks')
        .delete()
        .eq('id', taskId)
        .select('id');
    if (deleted.isEmpty) {
      throw StateError('Tugas tidak bisa dihapus');
    }
  }

  /// Untuk todo -> in_progress -> submitted.
  /// Status approved/rejected ditolak database (hanya lewat validasi).
  Future<void> updateStatus(String taskId, TaskStatus status) async {
    await supabase
        .from('tasks')
        .update({'status': status.dbValue})
        .eq('id', taskId);
  }

  Future<List<Evidence>> fetchEvidences(String taskId) async {
    final rows = await supabase
        .from('task_evidences')
        .select()
        .eq('task_id', taskId)
        .order('created_at');
    return rows.map(Evidence.fromJson).toList();
  }

  Future<void> addLinkEvidence({
    required String taskId,
    required String url,
    String? note,
  }) async {
    final trimmedNote = note?.trim();
    await supabase.from('task_evidences').insert({
      'task_id': taskId,
      'type': 'link',
      'url': url.trim(),
      'note': (trimmedNote == null || trimmedNote.isEmpty) ? null : trimmedNote,
    });
  }

  /// Hanya pengunggah, selama tugas belum disubmit (dijaga RLS).
  Future<void> deleteEvidence(String evidenceId) async {
    final deleted = await supabase
        .from('task_evidences')
        .delete()
        .eq('id', evidenceId)
        .select('id');
    if (deleted.isEmpty) {
      throw StateError('Bukti tidak bisa dihapus setelah tugas disubmit');
    }
  }

  // TODO(anggota-3): addFileEvidence — upload ke bucket "evidences" dengan path
  // "{groupId}/{taskId}/{namaFile}", lalu insert ke task_evidences type 'file'/'image'.

  Future<List<Validation>> fetchValidations(String taskId) async {
    final rows = await supabase
        .from('task_validations')
        .select()
        .eq('task_id', taskId);
    return rows.map(Validation.fromJson).toList();
  }

  Future<void> validate({
    required String taskId,
    required bool approved,
    String? comment,
  }) async {
    final trimmed = comment?.trim();
    await supabase.from('task_validations').insert({
      'task_id': taskId,
      'approved': approved,
      'comment': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
    });
  }
}
