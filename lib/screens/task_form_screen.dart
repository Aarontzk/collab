// Dikerjakan oleh: Rezzel (5026241079 - M. Azwar Alfarezzel Dharmawantara)
// Figma: halaman "Rezzel" > "05 Tugas baru" (+ Skor kontribusi),
// "05 · Pop-up deadline", "05 · Dropdown pilih PIC".
import 'package:flutter/material.dart';

import 'package:collab/utils/dates.dart';
import 'package:collab/utils/theme.dart';
import 'package:collab/utils/validators.dart';
import 'package:collab/widgets/collab_ui.dart';
import 'package:collab/widgets/common_widgets.dart';

/// Anggota yang bisa dipilih jadi PIC.
class TaskFormMember {
  const TaskFormMember({
    required this.userId,
    required this.fullName,
    this.isLeader = false,
    this.activeTasks = 0,
  });

  final String userId;
  final String fullName;
  final bool isLeader;
  final int activeTasks;
}

/// Isi form yang dikirim ke [TaskFormScreen.onSave].
/// Kolomnya sama dengan tabel `tasks` di supabase/schema.sql.
class TaskFormValue {
  const TaskFormValue({
    required this.title,
    this.description,
    this.assigneeId,
    this.weight = 2,
    this.deadline,
  });

  final String title;
  final String? description;
  final String? assigneeId;

  /// 1 ringan, 2 sedang, 3 berat.
  final int weight;
  final DateTime? deadline;
}

/// Komposisi skor kontribusi (persen). Bawaan sama dengan fungsi
/// `contribution_scores` di schema.sql: 60/15/15/10.
class ScoreWeights {
  const ScoreWeights({
    this.tasks = 60,
    this.attendance = 15,
    this.review = 15,
    this.validation = 10,
  });

  final int tasks;
  final int attendance;
  final int review;
  final int validation;

  int get total => tasks + attendance + review + validation;
}

/// Form tambah / ubah tugas: detail, PIC, deadline, bobot.
///
/// Screen ini tidak memanggil Supabase. Penyimpanan dikerjakan [onSave]
/// (diisi pemanggil lewat task service), sesuai aturan di README.
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({
    super.key,
    required this.members,
    required this.onSave,
    this.initial,
    this.scoreWeights = const ScoreWeights(),
    this.onSaveWeights,
  });

  final List<TaskFormMember> members;
  final Future<void> Function(TaskFormValue value) onSave;

  /// Komposisi skor kelompok yang sedang berlaku.
  final ScoreWeights scoreWeights;

  /// Menyimpan komposisi baru dari screen Skor kontribusi. Kosong = tombol
  /// Ubah disembunyikan (mis. bukan ketua).
  final Future<void> Function(ScoreWeights weights)? onSaveWeights;

  /// Diisi saat mengubah tugas. Kosong = tugas baru.
  final TaskFormValue? initial;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _description = TextEditingController(
    text: widget.initial?.description,
  );
  late String? _assigneeId = widget.initial?.assigneeId;
  late int _weight = widget.initial?.weight ?? 2;
  late DateTime? _deadline = widget.initial?.deadline;
  late ScoreWeights _weights = widget.scoreWeights;
  bool _saving = false;

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  TaskFormMember? get _pic {
    for (final m in widget.members) {
      if (m.userId == _assigneeId) return m;
    }
    return null;
  }

  Future<void> _pickDeadline() async {
    final picked = await showCollabSheet<DateTime>(
      context,
      scrollable: true,
      builder: (_) => _DeadlineSheet(initial: _deadline),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _editWeights() async {
    final onSave = widget.onSaveWeights;
    if (onSave == null) return;
    final result = await Navigator.of(context).push<ScoreWeights>(
      MaterialPageRoute(
        builder: (_) => ScoreWeightsScreen(initial: _weights, onSave: onSave),
      ),
    );
    if (result != null && mounted) setState(() => _weights = result);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final description = _description.text.trim();
      await widget.onSave(
        TaskFormValue(
          title: _title.text.trim(),
          description: description.isEmpty ? null : description,
          assigneeId: _assigneeId,
          weight: _weight,
          deadline: _deadline,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ItsColors.surfaceLow,
      appBar: AppBar(
        backgroundColor: ItsColors.surfaceLow,
        title: Text(_isEdit ? 'Ubah tugas' : 'Tugas baru'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: [
            _FormCard(
              icon: Icons.edit,
              title: 'Detail tugas',
              children: [
                _Field(
                  label: 'Judul tugas',
                  child: TextFormField(
                    controller: _title,
                    textInputAction: TextInputAction.next,
                    style: _inputText,
                    decoration: _inputDecoration('Contoh: Fitur absensi QR'),
                    validator: (v) => Validators.requiredText(v, max: 150),
                  ),
                ),
                _Field(
                  label: 'Deskripsi (opsional)',
                  child: TextFormField(
                    controller: _description,
                    minLines: 2,
                    maxLines: 5,
                    style: _inputText,
                    decoration: _inputDecoration('Jelaskan tugasnya singkat'),
                    validator: (v) => Validators.optionalText(v, max: 2000),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _FormCard(
              icon: Icons.person_outline,
              title: 'Penugasan',
              children: [
                _PicPicker(
                  members: widget.members,
                  selected: _pic,
                  onSelected: (m) => setState(() => _assigneeId = m.userId),
                ),
                _DeadlineRow(deadline: _deadline, onTap: _pickDeadline),
              ],
            ),
            const SizedBox(height: 10),
            _FormCard(
              icon: Icons.fitness_center,
              title: 'Bobot tugas',
              children: [
                Row(
                  children: [
                    for (final w in const [1, 2, 3]) ...[
                      if (w > 1) const SizedBox(width: 8),
                      Expanded(
                        child: _WeightOption(
                          weight: w,
                          selected: _weight == w,
                          onTap: () => setState(() => _weight = w),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            _FormCard(
              icon: Icons.star,
              title: 'Matriks penilaian',
              action: widget.onSaveWeights == null
                  ? null
                  : _TonalButton(label: 'Ubah', onPressed: _editWeights),
              children: [ScoreComposition(_weights)],
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        child: LoadingButton(
          label: 'Simpan',
          isLoading: _saving,
          onPressed: _save,
        ),
      ),
    );
  }
}

// ---------- Potongan UI ----------

const _inputText = TextStyle(
  fontFamily: AppFonts.text,
  fontSize: 15,
  fontWeight: FontWeight.w500,
  color: ItsColors.ink,
);

InputDecoration _inputDecoration(String hint) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppShape.large),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: _inputText.copyWith(color: CColors.outline),
    isDense: true,
    contentPadding: const EdgeInsets.all(14),
    filled: true,
    fillColor: Colors.white,
    border: border(ItsColors.border),
    enabledBorder: border(ItsColors.border),
    focusedBorder: border(ItsColors.blue, 2),
  );
}

/// Kartu putih radius 28: ikon dalam kotak biru muda + judul, lalu isi.
class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.icon,
    required this.title,
    required this.children,
    this.action,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  /// Tombol kecil di kanan judul (mis. "Ubah").
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ElevatedPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: ItsColors.blueContainer,
                  borderRadius: BorderRadius.circular(AppShape.medium),
                ),
                child: Icon(icon, size: 18, color: ItsColors.onBlueContainer),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: CText.cardTitle)),
              if (action != null) action!,
            ],
          ),
          for (final child in children) ...[
            const SizedBox(height: 10),
            child,
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: CText.label),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Baris PIC: avatar inisial + nama, buka menu anggota saat ditekan.
class _PicPicker extends StatelessWidget {
  const _PicPicker({
    required this.members,
    required this.selected,
    required this.onSelected,
  });

  final List<TaskFormMember> members;
  final TaskFormMember? selected;
  final ValueChanged<TaskFormMember> onSelected;

  @override
  Widget build(BuildContext context) {
    final pic = selected;
    return LayoutBuilder(
      builder: (context, constraints) => MenuAnchor(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(8),
          shadowColor: const WidgetStatePropertyAll(Color(0x2E1A264D)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 8),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppShape.medium),
            ),
          ),
          minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
        ),
        menuChildren: [
          for (final m in members)
            _PicMenuItem(
              member: m,
              selected: m.userId == pic?.userId,
              onTap: () => onSelected(m),
            ),
        ],
        builder: (context, controller, _) => _RowShell(
          active: controller.isOpen,
          onTap: members.isEmpty
              ? null
              : () => controller.isOpen ? controller.close() : controller.open(),
          leading: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: ItsColors.blue,
              shape: BoxShape.circle,
            ),
            child: pic == null
                ? const Icon(Icons.person_add_alt, size: 20, color: Colors.white)
                : Text(
                    _initials(pic.fullName),
                    style: const TextStyle(
                      fontFamily: AppFonts.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
          label: 'PIC',
          value: pic?.fullName ?? 'Pilih anggota',
          trailing: const Icon(
            Icons.arrow_drop_down,
            size: 24,
            color: ItsColors.inkMuted,
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.first.isEmpty ? '?' : parts.first[0];
    final second = parts.length > 1 ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }
}

class _PicMenuItem extends StatelessWidget {
  const _PicMenuItem({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final TaskFormMember member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final role = member.isLeader ? 'Ketua' : 'Anggota';
    return MenuItemButton(
      onPressed: onTap,
      style: MenuItemButton.styleFrom(
        backgroundColor: selected ? const Color(0xFFD6ECF8) : null,
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      leadingIcon: const Icon(
        Icons.person_outline,
        size: 24,
        color: ItsColors.ink,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            member.fullName,
            style: TextStyle(
              fontFamily: AppFonts.component,
              fontSize: 16,
              letterSpacing: 0.5,
              color: selected ? ItsColors.blue : const Color(0xFF1D1B20),
            ),
          ),
          Text(
            '$role · ${member.activeTasks} tugas aktif',
            style: const TextStyle(
              fontFamily: AppFonts.component,
              fontSize: 14,
              letterSpacing: 0.25,
              color: ItsColors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris deadline: ikon kalender, tanggal, badge sisa hari.
class _DeadlineRow extends StatelessWidget {
  const _DeadlineRow({required this.deadline, required this.onTap});

  final DateTime? deadline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = deadline;
    return _RowShell(
      onTap: onTap,
      leading: const SizedBox.square(
        dimension: 40,
        child: Icon(Icons.event, size: 20, color: ItsColors.inkMuted),
      ),
      label: 'Deadline',
      value: d == null
          ? 'Belum diatur'
          : formatDeadlineFull(d).replaceFirst(' pukul ', ' · '),
      trailing: d == null ? null : _DueBadge(d),
    );
  }
}

class _DueBadge extends StatelessWidget {
  const _DueBadge(this.deadline);

  final DateTime deadline;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = deadline.toLocal();
    final days = DateTime(d.year, d.month, d.day).difference(today).inDays;
    final late = deadline.isBefore(now);
    final text = late
        ? 'Lewat'
        : days == 0
        ? 'Hari ini'
        : '$days hari lagi';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: late ? CColors.errorContainer : ItsColors.yellowContainer,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppFonts.text,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: late ? CColors.error : ItsColors.onYellowContainer,
        ),
      ),
    );
  }
}

/// Kerangka baris PIC dan deadline (radius 12, padding 12×6).
class _RowShell extends StatelessWidget {
  const _RowShell({
    required this.leading,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
    this.active = false,
  });

  final Widget leading;
  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Bergaris biru saat menunya terbuka (Figma "Dropdown pilih PIC").
  final bool active;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppShape.medium);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: active
            ? const BorderSide(color: ItsColors.blue, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: AppFonts.text,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ItsColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: ItsColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu pilihan bobot: 3 batang naik, nama, poin.
class _WeightOption extends StatelessWidget {
  const _WeightOption({
    required this.weight,
    required this.selected,
    required this.onTap,
  });

  final int weight;
  final bool selected;
  final VoidCallback onTap;

  static const _names = {1: 'Ringan', 2: 'Sedang', 3: 'Berat'};
  static const _barOff = Color(0xFFD5D9E4);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppShape.medium);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? ItsColors.blueContainer : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? ItsColors.blue : ItsColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 3),
                      Container(
                        width: 6,
                        height: 10.0 + i * 4,
                        decoration: BoxDecoration(
                          color: i < weight ? ItsColors.blue : _barOff,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _names[weight]!,
                  style: TextStyle(
                    fontFamily: AppFonts.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? ItsColors.blue : ItsColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$weight poin',
                  style: const TextStyle(
                    fontFamily: AppFonts.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ItsColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bar komposisi skor + legenda. [long] = label panjang dan titik 10px
/// (screen Skor kontribusi); default label pendek dan titik 8px (Form Tugas).
class ScoreComposition extends StatelessWidget {
  const ScoreComposition(this.weights, {super.key, this.long = false});

  final ScoreWeights weights;
  final bool long;

  static const colors = [
    ItsColors.blue,
    Color(0xFF4F6FB8),
    Color(0xFF8FB0E0),
    ItsColors.skyContainer,
  ];

  @override
  Widget build(BuildContext context) {
    final parts = [
      (long ? 'Tugas selesai' : 'Tugas', weights.tasks),
      (long ? 'Kehadiran rapat' : 'Kehadiran', weights.attendance),
      ('Peer review', weights.review),
      ('Validasi', weights.validation),
    ];
    const legend = TextStyle(
      fontFamily: AppFonts.text,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: ItsColors.inkMuted,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 14,
          child: Row(
            children: [
              for (var i = 0; i < parts.length; i++)
                if (parts[i].$2 > 0) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    flex: parts[i].$2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors[i],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
            ],
          ),
        ),
        SizedBox(height: long ? 12 : 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (var i = 0; i < parts.length; i++)
              _LegendDot(
                color: colors[i],
                size: long ? 10 : 8,
                label: '${parts[i].$1} ${parts[i].$2}%',
                style: legend,
              ),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.size,
    required this.label,
    required this.style,
  });

  final Color color;
  final double size;
  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );
  }
}

/// Tombol tonal kecil (Button - tonal di Figma): biru langit, stadium.
class _TonalButton extends StatelessWidget {
  const _TonalButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: ItsColors.skyContainer,
        foregroundColor: ItsColors.onSkyContainer,
        minimumSize: const Size(64, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: const StadiumBorder(),
      ),
      child: Text(label),
    );
  }
}

/// Bar bawah putih bergaris atas, berisi tombol utama selebar layar.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ItsColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: SizedBox(
            height: 48,
            child: FilledButtonTheme(
              data: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppShape.large),
                  ),
                ).merge(Theme.of(context).filledButtonTheme.style),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Sheet deadline ----------

class _DeadlineSheet extends StatefulWidget {
  const _DeadlineSheet({this.initial});

  final DateTime? initial;

  @override
  State<_DeadlineSheet> createState() => _DeadlineSheetState();
}

class _DeadlineSheetState extends State<_DeadlineSheet> {
  late DateTime _date;
  late final TextEditingController _hour;
  late final TextEditingController _minute;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final base = widget.initial?.toLocal() ??
        DateTime(now.year, now.month, now.day, 23, 59);
    _date = DateTime(base.year, base.month, base.day);
    _hour = TextEditingController(text: _two(base.hour));
    _minute = TextEditingController(text: _two(base.minute));
  }

  @override
  void dispose() {
    _hour.dispose();
    _minute.dispose();
    super.dispose();
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  int? _parse(TextEditingController c, int max) {
    final v = int.tryParse(c.text.trim());
    if (v == null || v < 0 || v > max) return null;
    return v;
  }

  DateTime? get _result {
    final h = _parse(_hour, 23);
    final m = _parse(_minute, 59);
    if (h == null || m == null) return null;
    return DateTime(_date.year, _date.month, _date.day, h, m);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final now = DateTime.now();
    return SingleChildScrollView(
      child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader(title: ''),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: ItsColors.skyContainer,
            borderRadius: BorderRadius.circular(AppShape.extraLarge),
          ),
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Pilih deadline',
                  style: CText.label.copyWith(color: ItsColors.blue),
                ),
              ),
              const SizedBox(height: 8),
              Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                    surface: ItsColors.skyContainer,
                  ),
                ),
                child: CalendarDatePicker(
                  initialDate: _date,
                  firstDate: _date.isBefore(DateTime(now.year - 1))
                      ? _date
                      : DateTime(now.year - 1),
                  lastDate: DateTime(now.year + 2),
                  onDateChanged: (d) => setState(() => _date = d),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _timeField('Jam', _hour)),
            const SizedBox(width: 12),
            Expanded(child: _timeField('Menit', _minute)),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: FilledButton(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppShape.large),
              ),
            ),
            onPressed: result == null
                ? null
                : () => Navigator.of(context).pop(result),
            child: Text(
              result == null
                  ? 'Jam atau menit tidak valid'
                  : 'Pakai ${formatDateTime(result)}',
            ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _timeField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 2,
      style: _inputText,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShape.medium),
          borderSide: const BorderSide(color: ItsColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShape.medium),
          borderSide: const BorderSide(color: ItsColors.border),
        ),
      ),
    );
  }
}

// ---------- Screen Skor kontribusi (Matriks penilaian) ----------

/// Atur persentase komponen skor kontribusi. Total wajib 100% sebelum
/// tombol "Simpan matriks" aktif. Hasilnya dikembalikan lewat `pop`.
class ScoreWeightsScreen extends StatefulWidget {
  const ScoreWeightsScreen({
    super.key,
    required this.initial,
    required this.onSave,
  });

  final ScoreWeights initial;
  final Future<void> Function(ScoreWeights weights) onSave;

  @override
  State<ScoreWeightsScreen> createState() => _ScoreWeightsScreenState();
}

class _ScoreWeightsScreenState extends State<ScoreWeightsScreen> {
  late final _tasks = TextEditingController(text: '${widget.initial.tasks}');
  late final _attendance = TextEditingController(
    text: '${widget.initial.attendance}',
  );
  late final _review = TextEditingController(text: '${widget.initial.review}');
  late final _validation = TextEditingController(
    text: '${widget.initial.validation}',
  );
  bool _saving = false;

  @override
  void dispose() {
    _tasks.dispose();
    _attendance.dispose();
    _review.dispose();
    _validation.dispose();
    super.dispose();
  }

  static int _read(TextEditingController c) =>
      (int.tryParse(c.text.trim()) ?? 0).clamp(0, 100);

  ScoreWeights get _current => ScoreWeights(
    tasks: _read(_tasks),
    attendance: _read(_attendance),
    review: _read(_review),
    validation: _read(_validation),
  );

  Future<void> _save() async {
    final weights = _current;
    setState(() => _saving = true);
    try {
      await widget.onSave(weights);
      if (mounted) Navigator.of(context).pop(weights);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weights = _current;
    final ok = weights.total == 100;
    return Scaffold(
      backgroundColor: ItsColors.surfaceLow,
      appBar: AppBar(
        backgroundColor: ItsColors.surfaceLow,
        title: const Text('Skor kontribusi'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppShape.large),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Pratinjau komposisi',
                  style: TextStyle(
                    fontFamily: AppFonts.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ItsColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                ScoreComposition(weights, long: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _percentField('Tugas selesai (%)', _tasks),
          const SizedBox(height: 16),
          _percentField('Kehadiran rapat (%)', _attendance),
          const SizedBox(height: 16),
          _percentField('Peer review (%)', _review),
          const SizedBox(height: 16),
          _percentField('Validasi (%)', _validation),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: ok ? ItsColors.blueContainer : CColors.errorContainer,
              borderRadius: BorderRadius.circular(AppShape.large),
            ),
            child: Row(
              children: [
                Icon(
                  ok ? Icons.check_circle : Icons.error_outline,
                  size: 20,
                  color: ok ? ItsColors.onBlueContainer : CColors.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ok
                        ? 'Total 100%'
                        : 'Total ${weights.total}% (harus 100%)',
                    style: TextStyle(
                      fontFamily: AppFonts.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ok ? ItsColors.onBlueContainer : CColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: SizedBox(
            height: 48,
            child: FilledButtonTheme(
              data: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppShape.large),
                  ),
                ).merge(Theme.of(context).filledButtonTheme.style),
              ),
              child: LoadingButton(
                label: 'Simpan matriks',
                isLoading: _saving,
                onPressed: ok ? _save : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _percentField(String label, TextEditingController controller) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppShape.medium),
      borderSide: BorderSide(color: c, width: w),
    );
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 3,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(
        fontFamily: AppFonts.text,
        fontSize: 16,
        color: ItsColors.ink,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontFamily: AppFonts.text,
          fontSize: 12,
          color: ItsColors.inkMuted,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        counterText: '',
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
        border: border(ItsColors.border),
        enabledBorder: border(ItsColors.border),
        focusedBorder: border(ItsColors.blue, 2),
      ),
    );
  }
}
