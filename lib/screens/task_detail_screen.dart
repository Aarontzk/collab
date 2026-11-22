// Dibuat oleh Gregorius Cahya Khrisna Setiaputra - 5026241122

import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:collab/models/task_detail_data.dart';
import 'package:collab/screens/task_form_screen.dart';
import 'package:collab/services/task_detail_service.dart';
import 'package:collab/utils/dates.dart';
import 'package:collab/utils/errors.dart';
import 'package:collab/utils/theme.dart';
import 'package:collab/widgets/common_widgets.dart';
import 'package:collab/widgets/task_dialogs.dart';

const _errorRed = Color(0xFFB3261E);
const _errorContainer = Color(0xFFF9DEDC);
const _fieldFill = Color(0xFFF7F8FC);
const _outline = Color(0xFFC4C6D0);

/// Batas bucket "evidences" di schema.sql: 10 MB per file.
const _maxFileBytes = 10 * 1024 * 1024;

TextStyle _text(
  double size,
  FontWeight weight, {
  Color color = ItsColors.ink,
  double? height,
  double? letterSpacing,
}) => TextStyle(
  fontFamily: AppFonts.text,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  letterSpacing: letterSpacing,
);

/// Detail Tugas (frame Figma "06 Detail tugas"). Tampilan dan tombol aksi
/// mengikuti status tugas dan peran pengguna:
///
/// - Belum mulai: PIC menekan "Mulai kerjakan", bagian bukti terkunci.
/// - Dikerjakan: PIC menambah bukti lalu "Ajukan validasi".
/// - Menunggu validasi: anggota lain (bukan PIC) "Setujui" atau "Tolak".
/// - Ditolak: PIC mengganti bukti lalu "Kirim ulang validasi".
/// - Disetujui: selesai, dihitung ke skor kontribusi (terkunci).
///
/// Peran (PIC, ketua, boleh memvalidasi) datang dari [service], bukan dari
/// parameter. Setiap aksi dikirim ke server, lalu tampilan memakai data
/// terbaru yang dikembalikan. Status Disetujui/Ditolak ditentukan database.
///
/// Menutup layar dengan hasil `true` berarti tugas dihapus.
class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.service, this.openUrl});

  final TaskDetailService service;

  /// Membuka tautan di luar aplikasi. Bawaan: `launchUrl` (browser).
  /// Diganti hanya untuk tes.
  final Future<bool> Function(Uri url)? openUrl;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  TaskDetailLoad? _data;
  Object? _error;

  /// Bukti yang sudah diunggah ke Storage tapi baris `task_evidences`-nya baru
  /// dibuat saat Ajukan validasi (baris bukti tidak bisa diubah setelahnya,
  /// jadi catatan harus ikut saat dibuat).
  final List<EvidenceItem> _pending = [];

  /// Ada aksi (dialog, pemilih foto/file, kirim ke server) yang sedang
  /// berjalan. Ditandai langsung (tanpa menunggu rebuild) supaya tekan dua kali
  /// cepat tidak membuka dua sheet atau mengirim dua kali.
  bool _busy = false;

  /// Foto/file sedang diunggah ke Storage.
  bool _uploading = false;
  final _note = TextEditingController();

  TaskDetailData get _task => _data!.task;
  TaskDetailStatus get _status => _task.status;
  bool get _isPic => _data!.isPic;
  bool get _isLeader => _data!.isLeader;

  /// Bukti tersimpan ditambah bukti baru yang menunggu diajukan.
  List<EvidenceItem> get _evidences => [..._task.evidences, ..._pending];

  /// Bukti bisa ditambah atau dihapus oleh PIC saat Dikerjakan, dan saat
  /// tugas Ditolak (PIC langsung memperbaiki bukti tanpa langkah tambahan).
  bool get _canEditEvidence =>
      _isPic &&
      (_status == TaskDetailStatus.inProgress ||
          _status == TaskDetailStatus.rejected);

  /// Dari server: mahasiswa, bukan PIC, belum memberi suara, status Menunggu
  /// validasi.
  bool get _canValidate => _data!.canValidate;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final data = await widget.service.load();
      if (mounted) _setData(data);
    } catch (e) {
      if (!mounted) return;
      // Kalau data sudah tampil (tarik untuk muat ulang), cukup beri tahu.
      if (_data == null) {
        setState(() => _error = e);
      } else {
        showError(context, e);
      }
    }
  }

  void _setData(TaskDetailLoad data) {
    setState(() {
      _data = data;
      _error = null;
    });
    if (_note.text.isEmpty) _note.text = data.task.workNote;
  }

  /// Jalankan [action] satu per satu. Tombol ikut nonaktif selama berjalan.
  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Kirim aksi ke server dan pakai data terbaru dari jawabannya. Mengembalikan
  /// true kalau berhasil; kalau gagal, errornya ditampilkan.
  Future<bool> _apply(Future<TaskDetailLoad> Function() op) async {
    try {
      final data = await op();
      if (!mounted) return false;
      _setData(data);
      return true;
    } catch (e) {
      if (mounted) showError(context, e);
      return false;
    }
  }

  // ---------- Aksi PIC ----------

  Future<void> _start() => _apply(widget.service.start);

  Future<void> _addEvidence() async {
    final source = await showAddEvidenceSheet(context);
    if (source == null || !mounted) return;
    switch (source) {
      case EvidenceSource.photo:
        await _pickPhoto();
      case EvidenceSource.file:
        await _pickFile();
      case EvidenceSource.link:
        await _addLink();
    }
  }

  Future<void> _addLink() async {
    final url = await showAddLinkDialog(context);
    if (url == null) return;
    setState(
      () => _pending.add(
        EvidenceItem(
          kind: EvidenceKind.link,
          title: url.replaceFirst(
            RegExp(r'^https?://', caseSensitive: false),
            '',
          ),
          subtitle: 'Tautan · ${formatDateTime(DateTime.now())}',
          localPath: url,
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      // Kamera tidak ada di web/desktop: langsung ke galeri.
      var source = ImageSource.gallery;
      if (picker.supportsImageSource(ImageSource.camera)) {
        final choice = await showPhotoSourceSheet(context);
        if (choice == null) return;
        source = choice == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery;
      }
      final picked = await picker.pickImage(source: source);
      if (picked == null) return;
      await _upload(
        picked.name,
        await picked.readAsBytes(),
        picked.path,
        EvidenceKind.image,
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _pickFile() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'zip', 'docx', 'pptx', 'xlsx'],
      );
      if (picked == null) return;
      await _upload(
        picked.name,
        await picked.readAsBytes(),
        picked.path,
        EvidenceKind.file,
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Unggah ke Storage lebih dulu supaya jenis dan ukuran file ditolak sejak
  /// awal; baris bukti baru dibuat saat [_submit].
  Future<void> _upload(
    String name,
    Uint8List bytes,
    String? path,
    EvidenceKind kind,
  ) async {
    if (!mounted) return;
    if (bytes.length > _maxFileBytes) {
      showMessage(context, 'Ukuran file maksimal 10 MB.', isError: true);
      return;
    }
    setState(() => _uploading = true);
    try {
      final storagePath = await widget.service.uploadEvidence(
        fileName: name,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(
        () => _pending.add(
          EvidenceItem(
            kind: kind,
            title: name,
            subtitle:
                '${_formatSize(bytes.length)} · '
                '${kind == EvidenceKind.image ? 'Foto' : 'File'} di Storage',
            localPath: path,
            storagePath: storagePath,
          ),
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeEvidence(EvidenceItem item) async {
    if (item.id == null) {
      // Belum disimpan: cukup dibuang dari daftar.
      setState(() => _pending.remove(item));
      return;
    }
    await _apply(() => widget.service.removeEvidence(item));
  }

  Future<void> _submit() async {
    if (_evidences.isEmpty) {
      showMessage(
        context,
        'Tambahkan minimal satu bukti kerja sebelum mengajukan.',
        isError: true,
      );
      return;
    }
    final ok = await _apply(
      () => widget.service.submit(
        pending: List.of(_pending),
        note: _note.text.trim(),
      ),
    );
    if (!ok || !mounted) return;
    setState(_pending.clear);
    _note.text = _task.workNote;
    showMessage(context, 'Tugas diajukan untuk divalidasi.');
  }

  // ---------- Aksi validator ----------

  Future<void> _approve() async {
    final comment = await showApproveTaskDialog(
      context,
      picName: _task.picName,
    );
    if (comment == null) return;
    final ok = await _apply(
      () => widget.service.validate(approved: true, comment: comment),
    );
    if (ok && mounted && _status == TaskDetailStatus.approved) {
      showMessage(context, 'Tugas disetujui dan dinyatakan selesai.');
    }
  }

  Future<void> _reject() async {
    final reason = await showRejectTaskDialog(context, picName: _task.picName);
    if (reason == null) return;
    // Satu penolakan cukup untuk mengembalikan tugas ke PIC (diatur database).
    await _apply(
      () => widget.service.validate(approved: false, comment: reason),
    );
  }

  // ---------- Aksi ketua ----------

  /// Buka form ubah tugas (TaskFormScreen, Rezzel) berisi data tugas ini.
  Future<void> _edit() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(
          members: _data!.members,
          initial: TaskFormValue(
            title: _task.title,
            description: _task.description,
            assigneeId: _task.picId,
            weight: _task.weight,
            deadline: _task.deadline,
          ),
          onSave: (value) async {
            final data = await widget.service.save(value);
            if (mounted) _setData(data);
          },
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await showDeleteTaskDialog(context, taskTitle: _task.title);
    if (!ok || !mounted) return;
    try {
      await widget.service.delete();
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  // ---------- Buka bukti ----------

  void _copyLink(EvidenceItem item) {
    Clipboard.setData(ClipboardData(text: _linkOf(item)));
    showMessage(context, 'Tautan disalin.');
  }

  String _linkOf(EvidenceItem item) =>
      item.localPath ?? 'https://${item.title}';

  Future<void> _launch(Uri url) async {
    if (url.scheme != 'http' && url.scheme != 'https') {
      showMessage(
        context,
        'Hanya tautan http/https yang bisa dibuka.',
        isError: true,
      );
      return;
    }
    final open =
        widget.openUrl ??
        (Uri u) => launchUrl(u, mode: LaunchMode.externalApplication);
    final ok = await open(url);
    if (!ok && mounted) {
      showMessage(context, 'Tidak bisa membuka tautan.', isError: true);
    }
  }

  /// Signed URL Storage untuk foto/file, atau null kalau tidak ada path.
  Future<String?> _signedUrl(EvidenceItem item) async {
    final path = item.storagePath;
    if (path == null) return null;
    return widget.service.signedUrl(path);
  }

  /// Ketuk bukti: tautan dibuka di browser, foto dipratinjau, file dibuka
  /// lewat signed URL.
  Future<void> _openEvidence(EvidenceItem item) async {
    try {
      switch (item.kind) {
        case EvidenceKind.link:
          await _launch(Uri.parse(_linkOf(item)));
        case EvidenceKind.image:
          final url = await _signedUrl(item);
          final local = item.localPath;
          final ImageProvider? image = url != null
              ? NetworkImage(url)
              : local == null
              ? null
              : (kIsWeb ? NetworkImage(local) : FileImage(File(local)));
          if (image == null) return _notAvailable();
          if (!mounted) return;
          await showEvidencePreview(context, title: item.title, image: image);
        case EvidenceKind.file:
          final url = await _signedUrl(item);
          if (url == null) return _notAvailable();
          await _launch(Uri.parse(url));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _notAvailable() {
    if (!mounted) return;
    showMessage(context, 'Bukti ini belum bisa dibuka.');
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      return Scaffold(
        appBar: _appBar(),
        body: _error != null
            ? MessageView(
                icon: Icons.error_outline,
                message: friendlyError(_error!),
                actionLabel: 'Coba lagi',
                onAction: () {
                  setState(() => _error = null);
                  _reload();
                },
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: _appBar(),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                children: [
                  _buildSummary(),
                  const SizedBox(height: 10),
                  _buildEvidence(),
                  const SizedBox(height: 10),
                  _buildValidation(),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    // Tugas Disetujui terkunci di database, jadi ubah/hapus disembunyikan.
    final showLeaderActions =
        _data != null && _isLeader && _status != TaskDetailStatus.approved;
    return AppBar(
      toolbarHeight: 64,
      titleSpacing: 4,
      leading: IconButton(
        tooltip: 'Kembali',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        'Detail tugas',
        style: _text(
          22,
          FontWeight.w800,
          color: ItsColors.blue,
          letterSpacing: -0.44,
        ),
      ),
      actions: [
        if (showLeaderActions) ...[
          IconButton(
            tooltip: 'Ubah tugas',
            icon: const Icon(Icons.edit, size: 22),
            color: ItsColors.inkMuted,
            onPressed: _busy ? null : () => _guard(_edit),
          ),
          IconButton(
            tooltip: 'Hapus tugas',
            icon: const Icon(Icons.delete_outline, size: 22),
            color: _errorRed,
            onPressed: _busy ? null : () => _guard(_delete),
          ),
        ],
        const SizedBox(width: 4),
      ],
    );
  }

  // ---------- Kartu 1: ringkasan ----------

  Widget _buildSummary() {
    final description = _task.description?.trim() ?? '';
    return _Card(
      gap: 12,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Pill(
              _status.label,
              background: _status.chipColor,
              foreground: ItsColors.ink,
            ),
            _WeightBadge(weight: _task.weight, label: _task.weightLabel),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _task.title,
              style: _text(
                20,
                FontWeight.w700,
                height: 26 / 20,
                letterSpacing: -0.4,
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                description,
                style: _text(
                  13,
                  FontWeight.w400,
                  color: ItsColors.inkMuted,
                  height: 19 / 13,
                ),
              ),
            ],
          ],
        ),
        const Divider(height: 1, color: ItsColors.border),
        Column(
          children: [
            Row(
              children: [
                _InitialAvatar(name: _task.picName),
                const SizedBox(width: 12),
                Expanded(
                  child: _LabeledValue(label: 'PIC', value: _task.picName),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildDeadlineRow(),
          ],
        ),
      ],
    );
  }

  Widget _buildDeadlineRow() {
    final deadline = _task.deadline;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6FB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.event, size: 18, color: ItsColors.blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _LabeledValue(
            label: 'Deadline',
            value: deadline == null
                ? 'Tanpa tenggat'
                : formatDeadlineFull(deadline).replaceFirst(' pukul ', ' · '),
          ),
        ),
        if (deadline != null) _deadlineBadge(deadline),
      ],
    );
  }

  /// Sisa waktu: kuning kalau masih lega, merah kalau < 2 hari atau lewat,
  /// biru "Selesai" kalau tugas sudah disetujui.
  Widget _deadlineBadge(DateTime deadline) {
    if (_status == TaskDetailStatus.approved) {
      return const _Pill(
        'Selesai',
        background: ItsColors.blueContainer,
        foreground: ItsColors.blue,
      );
    }
    final left = deadline.difference(DateTime.now());
    if (left.isNegative) {
      return const _Pill(
        'Terlambat',
        background: _errorContainer,
        foreground: _errorRed,
      );
    }
    final label = left.inHours < 24
        ? '${left.inHours < 1 ? 1 : left.inHours} jam lagi'
        : '${(left.inHours / 24).ceil()} hari lagi';
    final urgent = left.inHours < 48;
    return _Pill(
      label,
      background: urgent ? _errorContainer : ItsColors.yellowContainer,
      foreground: urgent ? _errorRed : ItsColors.onYellowContainer,
    );
  }

  // ---------- Kartu 2: bukti kerja ----------

  Widget _buildEvidence() {
    final evidences = _evidences;
    final locked = _status == TaskDetailStatus.todo;

    final Widget trailing;
    if (locked) {
      trailing = const _Pill(
        'Terkunci',
        background: ItsColors.surfaceContainer,
        foreground: ItsColors.inkMuted,
      );
    } else {
      trailing = _Pill(
        evidences.isEmpty ? 'Belum ada' : '${evidences.length} lampiran',
        background: ItsColors.surfaceContainer,
        foreground: ItsColors.inkMuted,
      );
    }

    return _Card(
      gap: 8,
      children: [
        _CardHeader(
          icon: _canEditEvidence ? Icons.upload_file : Icons.link,
          title: 'Bukti kerja',
          trailing: trailing,
        ),
        if (_uploading) const LinearProgressIndicator(minHeight: 3),
        if (locked)
          _InfoTile(
            _isPic
                ? 'Tekan "Mulai kerjakan" di bawah untuk mengunggah '
                      'foto/file atau tautan bukti.'
                : 'Bukti kerja belum diunggah oleh PIC.',
          ),
        if (_canEditEvidence)
          Row(
            children: [
              Expanded(
                child: _SourceButton(
                  icon: Icons.upload_file,
                  label: 'Upload Foto/File',
                  filled: true,
                  onTap: _busy ? null : () => _guard(_addEvidence),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SourceButton(
                  icon: Icons.add_link,
                  label: 'Tempel Tautan',
                  onTap: _busy ? null : () => _guard(_addLink),
                ),
              ),
            ],
          ),
        for (final item in evidences)
          _EvidenceTile(
            item: item,
            onRemove: _canEditEvidence && !_busy
                ? () => _guard(() => _removeEvidence(item))
                : null,
            onTap: _busy ? null : () => _guard(() => _openEvidence(item)),
            onLongPress: item.kind == EvidenceKind.link
                ? () => _copyLink(item)
                : null,
          ),
        if (_canEditEvidence)
          _NoteField(controller: _note)
        else if (_task.workNote.isNotEmpty)
          _NoteBox(note: _task.workNote),
        if (!locked && evidences.isEmpty && !_canEditEvidence)
          const _InfoTile('Belum ada bukti kerja.'),
      ],
    );
  }

  // ---------- Kartu 3: validasi ----------

  Widget _buildValidation() {
    final rejected = _status == TaskDetailStatus.rejected;
    final started =
        _status == TaskDetailStatus.submitted ||
        _status == TaskDetailStatus.approved ||
        rejected;

    final String countLabel;
    final Color countBg;
    final Color countFg;
    if (rejected) {
      countLabel = 'Perlu revisi';
      countBg = _errorContainer;
      countFg = _errorRed;
    } else if (started) {
      countLabel = '${_task.approvedCount} / ${_task.requiredApprovals} setuju';
      countBg = ItsColors.skyContainer;
      countFg = ItsColors.onSkyContainer;
    } else {
      countLabel = 'Belum diajukan';
      countBg = ItsColors.surfaceContainer;
      countFg = ItsColors.inkMuted;
    }

    return _Card(
      gap: 10,
      children: [
        _CardHeader(
          icon: rejected ? Icons.cancel : Icons.check_circle,
          iconBackground: rejected ? _errorContainer : ItsColors.blueContainer,
          iconColor: rejected ? _errorRed : ItsColors.blue,
          title: 'Validasi',
          trailing: _Pill(countLabel, background: countBg, foreground: countFg),
        ),
        if (!started)
          const _InfoTile(
            'Anggota lain dapat memvalidasi setelah bukti kerja diajukan.',
          )
        else if (_task.validations.isEmpty)
          const _InfoTile('Menunggu validasi dari anggota lain.')
        else
          for (final v in _task.validations) _ValidatorTile(entry: v),
      ],
    );
  }

  // ---------- Bottom bar ----------

  Widget _buildBottomBar() {
    final Widget? actions = switch (_status) {
      TaskDetailStatus.todo =>
        _isPic
            ? DialogButton(
                label: 'Mulai kerjakan',
                onPressed: _busy ? null : () => _guard(_start),
              )
            : null,
      TaskDetailStatus.inProgress =>
        _isPic
            ? DialogButton(
                label: 'Ajukan validasi',
                onPressed: _busy ? null : () => _guard(_submit),
              )
            : null,
      TaskDetailStatus.submitted =>
        _canValidate
            ? Row(
                children: [
                  Expanded(
                    child: DialogButton(
                      label: 'Tolak',
                      outlined: true,
                      onPressed: _busy ? null : () => _guard(_reject),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DialogButton(
                      label: 'Setujui',
                      onPressed: _busy ? null : () => _guard(_approve),
                    ),
                  ),
                ],
              )
            : null,
      TaskDetailStatus.rejected =>
        _isPic
            ? DialogButton(
                label: 'Kirim ulang validasi',
                onPressed: _busy ? null : () => _guard(_submit),
              )
            : null,
      TaskDetailStatus.approved => Center(
        child: Text(
          'Tugas selesai · dihitung ke skor kontribusi',
          textAlign: TextAlign.center,
          style: _text(12, FontWeight.w500, color: ItsColors.inkMuted),
        ),
      ),
    };

    if (actions == null) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ItsColors.border)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: actions,
        ),
      ),
    );
  }
}

/// Contoh: 1258291 -> "1,2 MB" (koma desimal, format Indonesia).
String _formatSize(int bytes) {
  String one(double v) => v.toStringAsFixed(1).replaceFirst('.', ',');
  if (bytes >= 1024 * 1024) return '${one(bytes / (1024 * 1024))} MB';
  if (bytes >= 1024) return '${one(bytes / 1024)} KB';
  return '$bytes B';
}

// ---------- Komponen kecil ----------

/// Kartu putih radius 28 dengan bayangan biru tipis (padding 16 x 12).
class _Card extends StatelessWidget {
  const _Card({required this.children, required this.gap});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14244080),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.title,
    required this.trailing,
    this.iconBackground = ItsColors.blueContainer,
    this.iconColor = ItsColors.blue,
  });

  final IconData icon;
  final String title;
  final Widget trailing;
  final Color iconBackground;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconTile(icon: icon, background: iconBackground, color: iconColor),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: _text(15, FontWeight.w700))),
        trailing,
      ],
    );
  }
}

/// Chip bulat 11px bold (status, sisa waktu, jumlah).
class _Pill extends StatelessWidget {
  const _Pill(this.label, {required this.background, required this.foreground});

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(1000),
      ),
      child: Text(label, style: _text(11, FontWeight.w700, color: foreground)),
    );
  }
}

/// Badge bobot: tiga batang naik, yang sesuai bobot berwarna penuh.
class _WeightBadge extends StatelessWidget {
  const _WeightBadge({required this.weight, required this.label});

  final int weight;
  final String label;

  @override
  Widget build(BuildContext context) {
    const heights = [6.0, 9.0, 12.0];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ItsColors.blueContainer,
        borderRadius: BorderRadius.circular(1000),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Container(
                  width: 3.5,
                  height: heights[i],
                  decoration: BoxDecoration(
                    color: ItsColors.blue.withValues(
                      alpha: i < weight ? 1 : 0.25,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 6),
          Text(label, style: _text(11, FontWeight.w700, color: ItsColors.blue)),
        ],
      ),
    );
  }
}

/// Avatar lingkaran berisi inisial (foto profil menyusul dari tabel profiles).
class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.length > 1
        ? '${parts.first[0]}${parts.last[0]}'
        : (name.isEmpty ? '?' : name[0]);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: ItsColors.blueContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials.toUpperCase(),
        style: _text(13, FontWeight.w700, color: ItsColors.blue),
      ),
    );
  }
}

/// Label kecil di atas, nilai di bawah (PIC, Deadline).
class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _text(11, FontWeight.w600, color: ItsColors.inkMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _text(14, FontWeight.w600),
        ),
      ],
    );
  }
}

/// Kotak info abu-abu dengan ikon (mis. "Bukti kerja terkunci").
class _InfoTile extends StatelessWidget {
  const _InfoTile(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _fieldFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: ItsColors.inkMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: _text(
                12,
                FontWeight.w400,
                color: ItsColors.inkMuted,
                height: 17 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol sumber bukti: "Upload Foto/File" (biru muda) dan "Tempel Tautan".
class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = (filled ? ItsColors.onSkyContainer : ItsColors.blue)
        .withValues(alpha: onTap == null ? 0.4 : 1);
    return Material(
      color: filled ? ItsColors.skyContainer : _fieldFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: filled
            ? BorderSide.none
            : const BorderSide(color: Color(0xFFD5D9E4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(12, FontWeight.w700, color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Satu baris bukti: tautan (biru) atau foto/file (ikon di kotak biru muda).
class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({
    required this.item,
    this.onRemove,
    this.onTap,
    this.onLongPress,
  });

  final EvidenceItem item;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isLink = item.kind == EvidenceKind.link;
    return Material(
      color: _fieldFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ItsColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 6, onRemove != null ? 4 : 12, 6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 42),
            child: Row(
              children: [
                if (isLink)
                  const Icon(Icons.link, size: 20, color: ItsColors.blue)
                else
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: ItsColors.blueContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.kind == EvidenceKind.image
                          ? Icons.image
                          : Icons.insert_drive_file,
                      size: 18,
                      color: ItsColors.blue,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _text(
                          13,
                          FontWeight.w600,
                          color: isLink ? ItsColors.blue : ItsColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _text(
                          11,
                          FontWeight.w500,
                          color: ItsColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Hapus bukti',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, size: 18),
                    color: ItsColors.ink,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                  )
                else
                  Icon(
                    isLink ? Icons.open_in_new : Icons.visibility_outlined,
                    size: 18,
                    color: ItsColors.inkMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Isian "Catatan pekerjaan (opsional)" (maks. 500 karakter, sama dengan
/// kolom `task_evidences.note`).
class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ItsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Catatan pekerjaan (opsional)',
            style: _text(11, FontWeight.w600, color: ItsColors.inkMuted),
          ),
          const SizedBox(height: 3),
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            style: _text(12, FontWeight.w400),
            cursorColor: ItsColors.blue,
            buildCounter: (
              _, {
              required currentLength,
              required isFocused,
              required maxLength,
            }) => null,
            decoration: bareFieldDecoration.copyWith(
              hintText: 'Tulis catatan singkat tentang pekerjaanmu',
              hintStyle: _text(12, FontWeight.w400, color: _outline),
            ),
          ),
        ],
      ),
    );
  }
}

/// Catatan pekerjaan yang sudah dikirim (baca saja).
class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ItsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Catatan pekerjaan',
            style: _text(11, FontWeight.w600, color: ItsColors.inkMuted),
          ),
          const SizedBox(height: 3),
          Text(note, style: _text(12, FontWeight.w400)),
        ],
      ),
    );
  }
}

/// Hasil validasi satu anggota: ikon, nama, status, dan komentar.
class _ValidatorTile extends StatelessWidget {
  const _ValidatorTile({required this.entry});

  final ValidationEntry entry;

  @override
  Widget build(BuildContext context) {
    final ok = entry.approved;
    final comment = entry.comment?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ok ? _fieldFill : const Color(0xFFFDF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ok ? ItsColors.border : _errorContainer),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.cancel,
            size: 20,
            color: ok ? ItsColors.blue : _errorRed,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        entry.validatorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _text(13, FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ok ? 'Disetujui' : 'Ditolak',
                      style: _text(
                        11,
                        FontWeight.w700,
                        color: ok ? ItsColors.blue : _errorRed,
                      ),
                    ),
                  ],
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    comment,
                    style: _text(
                      12,
                      FontWeight.w400,
                      color: ok ? ItsColors.inkMuted : const Color(0xFF601410),
                      height: 17 / 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
