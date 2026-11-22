// Dibuat oleh Gregorius Cahya Khrisna Setiaputra - 5026241122

import 'package:flutter/material.dart';

import 'package:collab/utils/theme.dart';

/// Dialog dan bottom sheet untuk screen Detail Tugas:
/// Tambah Bukti Kerja (06a), Tolak Tugas (06b), Tempel Tautan, dan Hapus Tugas.

const _scrim = Color(0x6B000000); // hitam 42%, sama dengan scrim di Figma
const _errorRed = Color(0xFFB3261E);
const _errorContainer = Color(0xFFF9DEDC);
const _fieldFill = Color(0xFFF7F8FC);
const _outline = Color(0xFFC4C6D0);

/// Batas panjang di schema.sql: `task_validations.comment` <= 500 karakter.
const _maxCommentLength = 500;

TextStyle _text(
  double size,
  FontWeight weight, {
  Color color = ItsColors.ink,
  double? height,
}) => TextStyle(
  fontFamily: AppFonts.text,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

/// Pratinjau foto bukti (bisa dicubit untuk zoom). [image] bisa dari
/// signed URL Storage atau file lokal yang baru dipilih.
Future<void> showEvidencePreview(
  BuildContext context, {
  required String title,
  required ImageProvider image,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xCC000000),
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _text(15, FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Flexible(
            child: InteractiveViewer(
              maxScale: 5,
              child: Image(
                image: image,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                errorBuilder: (context, error, stack) => SizedBox(
                  height: 160,
                  child: Center(
                    child: Text(
                      'Gagal memuat gambar',
                      style: _text(
                        13,
                        FontWeight.w500,
                        color: ItsColors.inkMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

/// Isian tanpa garis dan latar: tema global memberi semua TextField garis
/// dan isi putih, sedangkan di sini kotaknya sudah digambar sendiri.
const bareFieldDecoration = InputDecoration(
  isCollapsed: true,
  filled: false,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  contentPadding: EdgeInsets.zero,
);

/// Sumber bukti yang dipilih di sheet "Tambah bukti kerja".
enum EvidenceSource { photo, file, link }

/// Bottom sheet "Tambah bukti kerja". Mengembalikan sumber yang dipilih,
/// atau null kalau ditutup.
Future<EvidenceSource?> showAddEvidenceSheet(BuildContext context) {
  return showModalBottomSheet<EvidenceSource>(
    context: context,
    barrierColor: _scrim,
    showDragHandle: false,
    isScrollControlled: true,
    builder: (_) => const _AddEvidenceSheet(),
  );
}

class _AddEvidenceSheet extends StatelessWidget {
  const _AddEvidenceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: _outline,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            Text('Tambah bukti kerja', style: _text(18, FontWeight.w700)),
            const SizedBox(height: 10),
            _SourceOption(
              icon: Icons.photo_camera_outlined,
              title: 'Ambil Foto / Pilih dari Galeri',
              subtitle: 'Unggah screenshot hasil kerja ke Supabase Storage',
              onTap: () => Navigator.pop(context, EvidenceSource.photo),
            ),
            const SizedBox(height: 10),
            _SourceOption(
              icon: Icons.upload_file_outlined,
              title: 'Upload File Dokumen',
              subtitle: 'PDF, ZIP, atau dokumen pendukung (maks. 10 MB)',
              onTap: () => Navigator.pop(context, EvidenceSource.file),
            ),
            const SizedBox(height: 10),
            _SourceOption(
              icon: Icons.link,
              title: 'Tempel Tautan URL',
              subtitle: 'GitHub PR, Figma, atau Google Drive',
              onTap: () => Navigator.pop(context, EvidenceSource.link),
            ),
            const SizedBox(height: 10),
            DialogButton(
              label: 'Tutup',
              outlined: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _fieldFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ItsColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              IconTile(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _text(14, FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: _text(
                        12,
                        FontWeight.w400,
                        color: ItsColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asal foto bukti: kamera atau galeri.
enum PhotoSource { camera, gallery }

/// Bottom sheet kecil "Ambil foto" setelah memilih sumber foto/galeri.
Future<PhotoSource?> showPhotoSourceSheet(BuildContext context) {
  return showModalBottomSheet<PhotoSource>(
    context: context,
    barrierColor: _scrim,
    showDragHandle: false,
    builder: (context) => SafeArea(
      minimum: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ambil foto bukti', style: _text(18, FontWeight.w700)),
            const SizedBox(height: 10),
            _SourceOption(
              icon: Icons.photo_camera_outlined,
              title: 'Ambil Foto',
              subtitle: 'Buka kamera untuk memotret hasil kerja',
              onTap: () => Navigator.pop(context, PhotoSource.camera),
            ),
            const SizedBox(height: 10),
            _SourceOption(
              icon: Icons.photo_library_outlined,
              title: 'Pilih dari Galeri',
              subtitle: 'Gunakan foto atau screenshot yang sudah ada',
              onTap: () => Navigator.pop(context, PhotoSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Dialog "Tolak tugas?". Alasan wajib diisi. Mengembalikan alasan
/// (sudah di-trim), atau null kalau dibatalkan.
Future<String?> showRejectTaskDialog(
  BuildContext context, {
  required String picName,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: _scrim,
    builder: (_) => _RejectTaskDialog(picName: picName),
  );
}

class _RejectTaskDialog extends StatefulWidget {
  const _RejectTaskDialog({required this.picName});

  final String picName;

  @override
  State<_RejectTaskDialog> createState() => _RejectTaskDialogState();
}

class _RejectTaskDialogState extends State<_RejectTaskDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DialogShell(
      icon: Icons.cancel,
      title: 'Tolak tugas?',
      message:
          'Tuliskan alasan penolakan agar ${widget.picName} tahu bagian '
          'mana yang perlu diperbaiki.',
      content: _BoxedField(
        controller: _reason,
        label: 'Alasan penolakan *',
        hint: 'Mis. bukti belum sesuai dengan deskripsi tugas',
        fill: _fieldFill,
        borderColor: _outline,
        minLines: 2,
        maxLines: 4,
        maxLength: _maxCommentLength,
        autofocus: true,
      ),
      actions: ListenableBuilder(
        listenable: _reason,
        builder: (context, _) {
          final reason = _reason.text.trim();
          return Row(
            children: [
              Expanded(
                child: DialogButton(
                  label: 'Batal',
                  outlined: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DialogButton(
                  label: 'Tolak tugas',
                  color: _errorRed,
                  onPressed: reason.isEmpty
                      ? null
                      : () => Navigator.pop(context, reason),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Dialog "Setujui tugas?". Komentar boleh kosong. Mengembalikan komentar
/// (sudah di-trim, "" kalau kosong), atau null kalau dibatalkan.
Future<String?> showApproveTaskDialog(
  BuildContext context, {
  required String picName,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: _scrim,
    builder: (_) => _ApproveTaskDialog(picName: picName),
  );
}

class _ApproveTaskDialog extends StatefulWidget {
  const _ApproveTaskDialog({required this.picName});

  final String picName;

  @override
  State<_ApproveTaskDialog> createState() => _ApproveTaskDialogState();
}

class _ApproveTaskDialogState extends State<_ApproveTaskDialog> {
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DialogShell(
      icon: Icons.check_circle,
      iconBackground: ItsColors.blueContainer,
      iconColor: ItsColors.blue,
      title: 'Setujui tugas?',
      message:
          'Pastikan bukti kerja sudah sesuai. Kamu bisa menambahkan komentar '
          'untuk ${widget.picName}.',
      content: _BoxedField(
        controller: _comment,
        label: 'Komentar (opsional)',
        hint: 'Mis. sudah dicoba dan berjalan baik',
        fill: _fieldFill,
        borderColor: _outline,
        minLines: 2,
        maxLines: 4,
        maxLength: _maxCommentLength,
      ),
      actions: Row(
        children: [
          Expanded(
            child: DialogButton(
              label: 'Batal',
              outlined: true,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DialogButton(
              label: 'Setujui',
              onPressed: () => Navigator.pop(context, _comment.text.trim()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog "Tempel tautan". Mengembalikan URL http(s), atau null.
Future<String?> showAddLinkDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierColor: _scrim,
    builder: (_) => const _AddLinkDialog(),
  );
}

class _AddLinkDialog extends StatefulWidget {
  const _AddLinkDialog();

  @override
  State<_AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends State<_AddLinkDialog> {
  final _url = TextEditingController();

  /// Sama dengan check di schema.sql: `url ~* '^https?://'`.
  static final _validUrl = RegExp(r'^https?://\S+$', caseSensitive: false);

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DialogShell(
      icon: Icons.link,
      iconBackground: ItsColors.blueContainer,
      iconColor: ItsColors.blue,
      title: 'Tempel tautan',
      message: 'Tautan harus diawali http:// atau https://.',
      content: _BoxedField(
        controller: _url,
        label: 'Tautan bukti',
        hint: 'https://github.com/...',
        fill: _fieldFill,
        borderColor: _outline,
        keyboardType: TextInputType.url,
        maxLength: 1000,
        autofocus: true,
      ),
      actions: ListenableBuilder(
        listenable: _url,
        builder: (context, _) {
          final url = _url.text.trim();
          return Row(
            children: [
              Expanded(
                child: DialogButton(
                  label: 'Batal',
                  outlined: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DialogButton(
                  label: 'Tambah',
                  onPressed: _validUrl.hasMatch(url)
                      ? () => Navigator.pop(context, url)
                      : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Konfirmasi hapus tugas (khusus ketua). Mengembalikan true kalau dihapus.
Future<bool> showDeleteTaskDialog(
  BuildContext context, {
  required String taskTitle,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: _scrim,
    builder: (context) => DialogShell(
      icon: Icons.delete_outline,
      title: 'Hapus tugas?',
      message:
          'Tugas "$taskTitle" akan dihapus permanen beserta bukti kerja dan '
          'riwayat validasinya.',
      actions: Row(
        children: [
          Expanded(
            child: DialogButton(
              label: 'Batal',
              outlined: true,
              onPressed: () => Navigator.pop(context, false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DialogButton(
              label: 'Hapus',
              color: _errorRed,
              onPressed: () => Navigator.pop(context, true),
            ),
          ),
        ],
      ),
    ),
  );
  return confirmed ?? false;
}

/// Kerangka dialog: kartu putih radius 28 (lebar layar - 64), judul dengan
/// ikon, penjelasan, isi opsional, lalu baris tombol.
class DialogShell extends StatelessWidget {
  const DialogShell({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
    this.content,
    this.iconBackground = _errorContainer,
    this.iconColor = _errorRed,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? content;
  final Widget actions;
  final Color iconBackground;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconTile(
                    icon: icon,
                    background: iconBackground,
                    color: iconColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title, style: _text(18, FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                message,
                style: _text(
                  13,
                  FontWeight.w400,
                  color: ItsColors.inkMuted,
                  height: 19 / 13,
                ),
              ),
              if (content != null) ...[const SizedBox(height: 14), content!],
              const SizedBox(height: 14),
              actions,
            ],
          ),
        ),
      ),
    );
  }
}

/// Kotak ikon 32px radius 12 (Figma: "ic").
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.background = ItsColors.blueContainer,
    this.color = ItsColors.blue,
  });

  final IconData icon;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

/// Tombol 48px radius 16 persis Figma: isi biru (atau [color]), atau outline.
class DialogButton extends StatelessWidget {
  const DialogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.color = ItsColors.blue,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final style = _text(14, FontWeight.w600);
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: outlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                shape: shape,
                side: const BorderSide(color: _outline),
                foregroundColor: ItsColors.inkMuted,
                textStyle: style,
              ),
              child: Text(label),
            )
          : FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                shape: shape,
                backgroundColor: color,
                foregroundColor: Colors.white,
                textStyle: style,
              ),
              child: Text(label),
            ),
    );
  }
}

/// Kotak isian dengan label kecil di dalamnya (gaya "alasan-input" di Figma).
class _BoxedField extends StatelessWidget {
  const _BoxedField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.fill,
    required this.borderColor,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final Color fill;
  final Color borderColor;
  final int minLines;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: _text(11, FontWeight.w600, color: ItsColors.inkMuted),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            autofocus: autofocus,
            minLines: minLines,
            maxLines: maxLines,
            maxLength: maxLength,
            keyboardType: keyboardType,
            textCapitalization: keyboardType == TextInputType.url
                ? TextCapitalization.none
                : TextCapitalization.sentences,
            style: _text(13, FontWeight.w400),
            cursorColor: ItsColors.blue,
            buildCounter: (
              _, {
              required currentLength,
              required isFocused,
              required maxLength,
            }) => null,
            decoration: bareFieldDecoration.copyWith(
              hintText: hint,
              hintStyle: _text(13, FontWeight.w400, color: ItsColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
