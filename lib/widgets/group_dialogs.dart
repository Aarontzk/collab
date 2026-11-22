import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:collab/models/group.dart';
import 'package:collab/services/group_service.dart';
import 'package:collab/utils/theme.dart';
import 'package:collab/utils/validators.dart';
import 'package:collab/widgets/collab_ui.dart';
import 'package:collab/widgets/common_widgets.dart';
import 'package:collab/widgets/labeled_field.dart';

enum AddGroupAction { create, join }

/// Sheet "Tambah kelompok" (Figma Farel F3).
Future<AddGroupAction?> showAddGroupSheet(BuildContext context) =>
    showCollabSheet<AddGroupAction>(
      context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader(
            title: 'Tambah kelompok',
            subtitle: 'Pilih cara kamu masuk ke kelompok',
          ),
          const SizedBox(height: 16),
          OptionCard(
            icon: Icons.group_add_outlined,
            title: 'Buat kelompok baru',
            subtitle: 'Kamu otomatis menjadi ketua',
            onTap: () => Navigator.pop(sheet, AddGroupAction.create),
          ),
          const SizedBox(height: 16),
          OptionCard(
            icon: Icons.vpn_key_outlined,
            title: 'Gabung pakai kode',
            subtitle: 'Masukkan 6 karakter kode dari ketua',
            onTap: () => Navigator.pop(sheet, AddGroupAction.join),
          ),
        ],
      ),
    );

/// Halaman "Kelompok baru" (Figma Farel F4). Mengembalikan kelompok baru.
Future<Group?> showCreateGroupDialog(BuildContext context, GroupService repo) =>
    Navigator.of(context).push<Group>(
      MaterialPageRoute(builder: (_) => CreateGroupScreen(repo: repo)),
    );

/// Halaman "Edit kelompok" (khusus ketua). Mengembalikan kelompok terbaru.
Future<Group?> showEditGroupScreen(
  BuildContext context,
  GroupService repo,
  Group group,
) => Navigator.of(context).push<Group>(
  MaterialPageRoute(
    builder: (_) => CreateGroupScreen(repo: repo, initial: group),
  ),
);

/// Mengembalikan `true` kalau berhasil bergabung (Figma Farel F5).
Future<bool> showJoinGroupDialog(
  BuildContext context,
  GroupService repo,
) async {
  final joined = await showDialog<bool>(
    context: context,
    builder: (_) => JoinGroupDialog(onJoin: repo.joinGroup),
  );
  return joined ?? false;
}

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key, required this.repo, this.initial});
  final GroupService repo;

  /// Diisi = mode edit.
  final Group? initial;

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _course = TextEditingController(text: widget.initial?.courseName);
  bool _loading = false;

  bool get _editing => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _course.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final initial = widget.initial;
      final group = initial == null
          ? await widget.repo.createGroup(
              name: _name.text,
              courseName: _course.text,
            )
          : await widget.repo.updateGroup(
              initial,
              name: _name.text,
              courseName: _course.text,
            );
      if (mounted) Navigator.of(context).pop(group);
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit kelompok' : 'Kelompok baru')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ElevatedPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconBadge(
                        _editing
                            ? Icons.edit_outlined
                            : Icons.group_add_outlined,
                        size: IconBadge.sectionSize,
                      ),
                      const SizedBox(width: 12),
                      Text('Detail kelompok', style: CText.cardTitle),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Nama kelompok',
                    child: TextFormField(
                      controller: _name,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Contoh: Kelompok 15 Tekber',
                      ),
                      validator: (v) => Validators.requiredText(v, max: 100),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Mata kuliah',
                    optional: true,
                    child: TextFormField(
                      controller: _course,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Contoh: Teknologi Berkembang',
                      ),
                      validator: (v) => Validators.optionalText(v, max: 100),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
            ),
            if (!_editing) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CColors.carousel,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: IconSizes.note,
                      color: ItsColors.inkMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kamu otomatis menjadi ketua. Kode gabung anggota dan '
                        'kode dosen dibuat setelah kelompok disimpan.',
                        style: CText.label.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: ItsColors.border)),
          ),
          child: LoadingButton(
            label: _editing ? 'Simpan perubahan' : 'Buat kelompok',
            onPressed: _submit,
            isLoading: _loading,
          ),
        ),
      ),
    );
  }
}

/// Dialog gabung dengan kotak per karakter.
class JoinGroupDialog extends StatefulWidget {
  const JoinGroupDialog({super.key, required this.onJoin});

  final Future<Object?> Function(String code) onJoin;

  @override
  State<JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends State<JoinGroupDialog> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() => _error = null));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = Validators.inviteCode(_code.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.onJoin(_code.text.trim().toUpperCase());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _code.text.toUpperCase();
    // Kode dosen 8 karakter: kotak bertambah kalau user mengetik lebih dari 6.
    final boxes = code.length > 6 ? 8 : 6;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconBadge(Icons.vpn_key_outlined, size: 48, radius: 14),
            const SizedBox(height: 16),
            Text('Gabung pakai kode', style: CText.stat.copyWith(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              'Minta kode 6 karakter ke ketua kelompok, lalu masukkan di bawah.',
              style: CText.meta,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _focus.requestFocus(),
              child: Stack(
                children: [
                  // Field asli tak terlihat; kotak di atasnya hanya tampilan.
                  Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: _code,
                      focusNode: _focus,
                      autofocus: true,
                      maxLength: 8,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        filled: false,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp('[0-9a-fA-F]'),
                        ),
                      ],
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < boxes; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(child: _box(code, i)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  _error == null ? Icons.info_outline : Icons.error_outline,
                  size: 16,
                  color: _error == null ? ItsColors.inkMuted : CColors.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error ?? 'Kode berisi huruf kapital dan angka',
                    style: CText.label.copyWith(
                      fontWeight: FontWeight.w500,
                      color: _error == null ? null : CColors.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                const SizedBox(width: 8),
                LoadingButton(
                  label: 'Gabung',
                  onPressed: _submit,
                  isLoading: _loading,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(String code, int i) {
    final active = _focus.hasFocus && i == code.length;
    return AspectRatio(
      aspectRatio: 44 / 54,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.white : CColors.carousel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? ItsColors.blue : ItsColors.border,
            width: active ? 2 : 1,
          ),
        ),
        child: i < code.length
            ? Text(
                code[i],
                style: CText.stat.copyWith(fontSize: 20, color: ItsColors.blue),
              )
            : active
            ? Container(width: 2, height: 24, color: ItsColors.blue)
            : null,
      ),
    );
  }
}
