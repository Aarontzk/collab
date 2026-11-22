import 'package:flutter/material.dart';
import 'package:collab/widgets/brand_shapes.dart';
import 'package:collab/widgets/press_scale.dart';

import 'package:collab/models/group.dart';
import 'package:collab/models/task.dart';
import 'package:collab/utils/dates.dart';
import 'package:collab/utils/theme.dart';
import 'package:collab/widgets/member_avatar.dart';

export 'package:collab/widgets/brand_shapes.dart';

/// Potongan UI bersama yang dipakai screen-screen di Figma "Collab Screens"
/// (Farel, Aludra, gergi, Rezzel, Zahra, Maria). Skala font sengaja dibatasi: 12, 13, 15, 17, 20, 34.
abstract final class CText {
  static TextStyle _s(double size, FontWeight w, [Color c = ItsColors.ink]) =>
      TextStyle(
        fontFamily: AppFonts.text,
        fontSize: size,
        fontWeight: w,
        color: c,
        height: size >= 20 ? 1.15 : 1.3,
        // Bagi sisa line-height rata atas-bawah. Tanpa ini Poppins (ascent
        // besar) terlihat turun dan menempel ke teks di bawahnya.
        leadingDistribution: TextLeadingDistribution.even,
        letterSpacing: trackingFor(size),
      );

  /// Tracking ikut ukuran (gaya tipografi Apple): teks besar dirapatkan,
  /// teks kecil sedikit dilonggarkan, teks body dibiarkan 0.
  static double trackingFor(double size) {
    if (size >= 20) return -0.02 * size;
    if (size <= 12) return 0.1;
    return 0;
  }

  /// Judul section ("Tenggat terdekat", "Kelompokmu").
  static final section = _s(17, FontWeight.w700);

  /// Judul section tebal ("Tugas kelompok").
  static final sectionStrong = _s(17, FontWeight.w800);

  /// Judul kartu kelompok / item carousel.
  static final cardTitle = _s(15, FontWeight.w700);

  /// Judul baris tugas.
  static final rowTitle = _s(15, FontWeight.w600);

  /// Judul halaman detail (mis. judul tugas).
  static final title = _s(20, FontWeight.w700);

  static final body = _s(15, FontWeight.w500);
  static final meta = _s(13, FontWeight.w500, ItsColors.inkMuted);
  static final label = _s(12, FontWeight.w600, ItsColors.inkMuted);
  static final labelInk = _s(12, FontWeight.w600);
  static final caption = _s(12, FontWeight.w600, ItsColors.inkMuted);
  static final chip = _s(12, FontWeight.w700);
  static final stat = _s(20, FontWeight.w800).copyWith(fontFeatures: _tabular);
  static final bigNumber = _s(
    34,
    FontWeight.w800,
    ItsColors.blue,
  ).copyWith(fontFeatures: _tabular);
  static final percent = _s(
    12,
    FontWeight.w800,
    ItsColors.blue,
  ).copyWith(fontFeatures: _tabular);

  /// Angka data selebar sama, jadi tidak goyang saat nilainya berubah.
  static const _tabular = [FontFeature.tabularFigures()];
}

/// Warna tambahan dari Figma yang belum ada di [ItsColors].
abstract final class CColors {
  static const neutralChip = Color(0xFFEFF0F7);
  static const errorContainer = Color(0xFFF9DEDC);
  static const error = Color(0xFFB3261E);

  /// Warna ikon garis, sama dengan ikon navigasi bawah.
  static const icon = Color(0xFF49454F);
  static const success = Color(0xFF1B6E3A);
  static const successContainer = Color(0xFFDDF3E4);
  static const outline = Color(0xFFC4C6D0);
  static const chipBorder = Color(0xFFE2E4EC);
  static const carousel = Color(0xFFF7F8FC);
  static const muted = Color(0xFF49454F);
}

/// Kartu putih radius 28 dengan bayangan biru tipis (kartu kelompok, ringkasan).
class ElevatedPanel extends StatelessWidget {
  const ElevatedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
    this.onTap,
    this.highlight = false,
    this.deco,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  /// Kartu sorotan: garis tepi bergradasi brand.
  final bool highlight;

  /// Shape hiasan yang mengintip dari pojok kanan atas.
  final BrandShape? deco;

  static const shadow = [
    BoxShadow(color: Color(0x14244080), blurRadius: 16, offset: Offset(0, 4)),
  ];

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return PressScale(
      enabled: onTap != null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: shape,
          boxShadow: shadow,
        ),
        child: CustomPaint(
          foregroundPainter: highlight
              ? GradientBorderPainter(radius: radius)
              : null,
          child: ClipRRect(
            borderRadius: shape,
            child: Stack(
              children: [
                if (deco != null)
                  Positioned(
                    top: -36,
                    right: -36,
                    child: DecoShape(deco!, size: 132, rotation: 0.3),
                  ),
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: shape,
                    onTap: onTap,
                    child: Padding(padding: padding, child: child),
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

/// Kartu bergaris tipis (radius 20) berisi baris-baris dengan pemisah.
class OutlinedList extends StatelessWidget {
  const OutlinedList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Material (bukan Container berwarna) supaya ripple ListTile di dalamnya
    // tetap terlihat.
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: ItsColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: ItsColors.border,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Label info kecil: teks berwarna dengan ikon opsional, tanpa latar.
/// Chip berlatar hanya dipakai untuk hal yang bisa ditekan (filter, dropdown).
class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.foreground = ItsColors.inkMuted,
    this.style,
    this.icon,
  });

  final String label;
  final Color foreground;
  final TextStyle? style;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = (style ?? CText.chip).copyWith(color: foreground);
    if (icon != null) return IconLabel(icon: icon!, label: label, style: text);
    return Text(
      label,
      style: text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Status tugas: titik warna 8px + teks.
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.style});

  final TaskStatus status;

  /// Gaya teks; default label. Di baris info pakai gaya meta supaya setara.
  final TextStyle? style;

  /// Warna titik, cukup pekat supaya terbaca di atas putih.
  static Color colorOf(TaskStatus s) => switch (s) {
    TaskStatus.todo => const Color(0xFF9A9DA8),
    TaskStatus.inProgress => ItsColors.skyBlue,
    TaskStatus.submitted => const Color(0xFFE0A100),
    TaskStatus.approved => ItsColors.blue,
    TaskStatus.rejected => CColors.error,
  };

  @override
  Widget build(BuildContext context) => DotLabel(
    color: colorOf(status),
    label: status.label,
    style: style ?? CText.labelInk,
  );
}

/// Titik warna + teks. Titik dipusatkan ke tinggi huruf kecil (bukan ke
/// kotak baris), supaya tidak terlihat naik di font dengan ascent besar.
class DotLabel extends StatelessWidget {
  const DotLabel({
    super.key,
    required this.color,
    required this.label,
    required this.style,
    this.gap = 8,
  });

  final Color color;
  final String label;
  final TextStyle style;
  final double gap;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      style: style,
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: EdgeInsets.only(right: gap),
            child: Container(
              transform: Matrix4.translationValues(0, opticalShift(style), 0),
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
        TextSpan(text: label),
      ],
    ),
  );
}

/// Peran anggota sebagai teks: Ketua biru dengan ikon, lainnya netral.
class RolePill extends StatelessWidget {
  const RolePill(this.role, {super.key});

  final MemberRole role;

  @override
  Widget build(BuildContext context) => switch (role) {
    MemberRole.leader => Pill(
      role.label,
      icon: Icons.workspace_premium_outlined,
      foreground: ItsColors.blue,
      style: CText.labelInk.copyWith(fontWeight: FontWeight.w700),
    ),
    MemberRole.lecturer => Pill(
      role.label,
      foreground: ItsColors.onYellowContainer,
      style: CText.label,
    ),
    MemberRole.member => Pill(role.label, style: CText.label),
  };
}

/// Bar progres 8px (Figma: track #D9E2FF, isi #243F81).
class ThinProgress extends StatelessWidget {
  const ThinProgress(this.value, {super.key, this.color = ItsColors.blue});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 8,
        color: color,
        backgroundColor: ItsColors.blueContainer,
      ),
    );
  }
}

/// Judul section dengan aksi di kanan.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.trailing,
    this.strong = false,
  });

  final String title;
  final Widget? trailing;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: strong ? CText.sectionStrong : CText.section,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Kerangka halaman tab kelompok (Tugas, Rapat, Review, Kontribusi):
/// [SummaryCard] di atas, lalu [TabSection]. Padding sama di semua tab,
/// bawah 96 supaya isi terakhir tidak tertutup FAB.
class TabPageList extends StatelessWidget {
  const TabPageList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
    children: children,
  );
}

/// Kartu ringkasan teratas tiap tab: ikon + nama tab (sama dengan navigasi
/// bawah) + aksi kecil, angka besar + keterangan, bar progres, catatan opsional.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.caption,
    this.trailing,
    this.progress,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String value;
  final String caption;
  final Widget? trailing;

  /// 0–1; null kalau tidak ada bar.
  final double? progress;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return ElevatedPanel(
      highlight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 24,
            child: Row(
              children: [
                Icon(icon, size: IconSizes.section, color: CColors.icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: CText.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Angka besar dan keterangannya duduk di baseline yang sama.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: CText.bigNumber),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  caption,
                  style: CText.body.copyWith(color: ItsColors.inkMuted),
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            ThinProgress(progress!),
          ],
          if (footer != null) ...[const SizedBox(height: 16), footer!],
        ],
      ),
    );
  }
}

/// Satu section halaman tab: judul di luar kartu, jarak 12, lalu isinya.
class TabSection extends StatelessWidget {
  const TabSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title, trailing: trailing),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

/// Kotak catatan abu dalam kartu (ikon info + teks kecil).
class NoteBox extends StatelessWidget {
  const NoteBox(this.text, {super.key, this.icon = Icons.info_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: CColors.carousel,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: IconSizes.note, color: ItsColors.inkMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: CText.caption.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

/// Tab teks bergaris bawah, pengganti chip filter. Yang aktif tebal dan
/// bergaris biru; sisanya abu. Satu garis tipis di bawah menyatukan barisnya.
class TextTabs<T> extends StatelessWidget {
  const TextTabs({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<(T, String)> items;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ItsColors.border)),
      ),
      child: Row(
        children: [
          for (final (value, label) in items)
            _TextTab(
              label: label,
              active: value == selected,
              onTap: () => onSelected(value),
            ),
        ],
      ),
    );
  }
}

class _TextTab extends StatelessWidget {
  const _TextTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: active,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
          margin: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? ItsColors.blue : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: CText.body.copyWith(
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? ItsColors.ink : ItsColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pilihan centang tanpa bingkai (ikon lingkaran + teks), untuk pilih banyak.
class CheckToggle extends StatelessWidget {
  const CheckToggle({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? ItsColors.blue : ItsColors.inkMuted,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: CText.body.copyWith(
                  color: selected ? ItsColors.ink : ItsColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar bulat berisi huruf awal (kartu kelompok).
class LetterAvatar extends StatelessWidget {
  const LetterAvatar(this.text, {super.key, this.size = 48, this.color});

  final String text;
  final double size;
  final Color? color;

  static const _palette = [
    ItsColors.blueContainer,
    ItsColors.skyContainer,
    ItsColors.yellowContainer,
  ];

  @override
  Widget build(BuildContext context) {
    final letter = text.trim().isEmpty
        ? '?'
        : text.trim().characters.first.toUpperCase();
    final bg = color ?? _palette[text.hashCode.abs() % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        letter,
        style: TextStyle(
          fontFamily: AppFonts.text,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.375,
          color: ItsColors.blue,
        ),
      ),
    );
  }
}

/// Satu baris tugas: judul + status, lalu PIC · bobot · deadline.
class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.members,
    this.onTap,
  });

  final Task task;
  final List<Member> members;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final due = task.deadline;
    final late = task.isLate(DateTime.now());
    Member? pic;
    for (final m in members) {
      if (m.userId == task.assigneeId) pic = m;
    }
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: CText.rowTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                StatusPill(
                  task.status,
                  style: CText.meta.copyWith(color: ItsColors.ink),
                ),
                const SizedBox(width: 4),
                if (pic != null)
                  MemberAvatar(
                    name: pic.fullName,
                    avatarUrl: pic.avatarUrl,
                    radius: 10,
                  ),
                Text(
                  _firstName(members.nameOf(task.assigneeId)),
                  style: CText.meta,
                ),
                const SizedBox(width: 4),
                if (due != null)
                  _MetaIcon(
                    Icons.schedule,
                    formatDateShort(due),
                    color: late ? CColors.error : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _firstName(String name) => name.split(' ').first;
}

class _MetaIcon extends StatelessWidget {
  const _MetaIcon(this.icon, this.label, {this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? ItsColors.inkMuted;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: IconLabel(icon: icon, label: label, style: CText.meta, color: c),
    );
  }
}

/// Kepala bottom sheet: pegangan, judul, keterangan.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: CColors.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        if (title.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontFamily: AppFonts.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: ItsColors.ink,
            ),
          ),
        ] else
          const SizedBox(height: 16),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: CText.meta),
        ],
      ],
    );
  }
}

/// Tampilkan bottom sheet bergaya Figma (putih, padding 20).
Future<T?> showCollabSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool scrollable = false,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: scrollable,
  backgroundColor: Colors.white,
  showDragHandle: false,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: builder(context),
    ),
  ),
);

/// Kotak ikon kecil berwarna (ikon pilihan di sheet, ringkasan).
class IconBadge extends StatelessWidget {
  const IconBadge(
    this.icon, {
    super.key,
    this.size = 40,
    this.background = ItsColors.blueContainer,
    this.color = CColors.icon,
    this.radius = 10,
  });

  /// Ukuran ikon judul kartu.
  static const sectionSize = 32.0;

  final IconData icon;
  final double size;
  final Color background;
  final Color color;
  final double radius;

  /// Ikon polos tanpa latar. [background] dan [radius] diabaikan.
  ///
  /// - Ukuran judul kartu ([sectionSize]): ikon 18 tanpa slot, tepi kirinya
  ///   rata dengan isi kartu.
  /// - Ukuran lain: ikon di tengah slot [size] x [size], selebar avatar, jadi
  ///   teks di baris berikon dan baris beravatar mulai di x yang sama.
  @override
  Widget build(BuildContext context) {
    if (size <= sectionSize) {
      return Icon(icon, size: IconSizes.section, color: color);
    }
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: Icon(icon, size: IconSizes.leading, color: color),
      ),
    );
  }
}

/// Geser ikon/titik ke bawah supaya pusatnya jatuh di tengah huruf.
///
/// Flutter memusatkan ikon ke kotak baris teks. Plus Jakarta Sans punya
/// ascent 1,038em tapi tinggi kapital hanya 0,745em, jadi tengah kotak
/// baris ada ~0,12em di atas tengah huruf (terukur 1,5px di teks 12).
/// Ini berlaku untuk `Row` maupun `WidgetSpan` (PlaceholderAlignment.middle).
double opticalShift(TextStyle style) => (style.fontSize ?? 14) * 0.12;

/// Ikon kecil + teks satu baris, sejajar secara optis. Pakai ini untuk semua
/// pasangan ikon–teks satu baris, jangan `Row(Icon, Text)` langsung.
class IconLabel extends StatelessWidget {
  const IconLabel({
    super.key,
    required this.icon,
    required this.label,
    required this.style,
    this.color,
    this.size = IconSizes.inline,
    this.gap = 4,
  });

  final IconData icon;
  final String label;
  final TextStyle style;

  /// Warna ikon dan teks; default warna [style].
  final Color? color;
  final double size;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final text = color == null ? style : style.copyWith(color: color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: Offset(0, opticalShift(text)),
          child: Icon(icon, size: size, color: text.color),
        ),
        SizedBox(width: gap),
        Flexible(
          child: Text(
            label,
            style: text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Ukuran ikon, dipasangkan dengan ukuran teks di sebelahnya.
abstract final class IconSizes {
  /// Teks 12–13 (label, meta, chip).
  static const inline = 14.0;

  /// Kotak info dan catatan (teks 12–13, bisa lebih dari satu baris).
  static const note = 16.0;

  /// Ikon di tombol (standar M3).
  static const button = 18.0;

  /// Judul kartu (teks 15, cardTitle), jarak ke teks 8.
  static const section = 18.0;

  /// Ikon pembuka baris di slot 40, sejajar avatar.
  static const leading = 24.0;
}

/// Pilihan berbentuk kartu abu muda (sheet "Tambah kelompok").
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
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
    return PressScale(
      child: Material(
        color: CColors.carousel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ItsColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                IconBadge(icon),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: CText.cardTitle),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: CText.label.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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

/// Dropdown teks kecil ("Semua peran ⌄"), tanpa bingkai.
class DropdownPill<T> extends StatelessWidget {
  const DropdownPill({
    super.key,
    required this.label,
    required this.items,
    required this.onSelected,
  });

  final String label;
  final List<(T, String)> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: label,
      position: PopupMenuPosition.under,
      color: Colors.white,
      onSelected: (i) => onSelected(items[i].$1),
      itemBuilder: (_) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem(value: i, child: Text(items[i].$2)),
      ],
      // Tanpa bingkai: cukup teks + panah, supaya tidak terlihat seperti chip.
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: CText.labelInk.copyWith(color: ItsColors.blue)),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more, size: 18, color: ItsColors.blue),
          ],
        ),
      ),
    );
  }
}

/// Satu aksi di [MoreMenu].
class MoreMenuItem {
  const MoreMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
}

/// Tombol titik tiga untuk aksi ubah/hapus. Aksi merusak diberi warna merah.
class MoreMenu extends StatelessWidget {
  const MoreMenu({super.key, required this.items, this.tooltip = 'Lainnya'});

  final List<MoreMenuItem> items;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: tooltip,
      position: PopupMenuPosition.under,
      color: Colors.white,
      icon: const Icon(Icons.more_vert, size: 20, color: ItsColors.inkMuted),
      onSelected: (i) => items[i].onTap(),
      itemBuilder: (_) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem(
            value: i,
            child: Row(
              children: [
                Icon(
                  items[i].icon,
                  size: 20,
                  color: items[i].danger ? CColors.error : CColors.icon,
                ),
                const SizedBox(width: 12),
                Text(
                  items[i].label,
                  style: CText.body.copyWith(
                    color: items[i].danger ? CColors.error : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Dialog konfirmasi bergaya Figma (ikon, judul, pesan, Batal/aksi).
/// Mengembalikan `true` kalau tombol aksi ditekan.
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _ConfirmDialog(
    icon: icon,
    danger: danger,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
  ),
);

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconBadge(
                  icon,
                  size: IconBadge.sectionSize,
                  background: danger
                      ? CColors.errorContainer
                      : ItsColors.blueContainer,
                  color: danger ? CColors.error : ItsColors.blue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: CText.stat.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(message, style: CText.meta.copyWith(fontSize: 15)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: danger ? CColors.error : null,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
