import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:collab/models/contribution.dart';
import 'package:collab/models/group.dart';
import 'package:collab/models/task.dart';
import 'package:collab/screens/detail_kontribusi_anggota.dart';
import 'package:collab/screens/pratinjau_laporan_kontribusi.dart';
import 'package:collab/utils/contribution_math.dart';
import 'package:collab/utils/theme.dart';
import 'package:collab/widgets/collab_ui.dart';
import 'package:collab/widgets/contribution_chart.dart';
import 'package:collab/widgets/contribution_nav_bar.dart';
import 'package:collab/widgets/home_cards.dart';

/// Halaman Kontribusi satu kelompok: porsi adil, grafik skor, dan komposisi.
class DetailKontribusiKelompokScreen extends StatefulWidget {
  const DetailKontribusiKelompokScreen({
    super.key,
    required this.group,
    required this.scores,
    this.tasks = const [],
    this.totalMeetings = 0,
    this.onTabSelected,
  });

  final Group group;

  /// Hasil RPC `contribution_scores(gid)`, sudah urut skor menurun.
  final List<ContributionScore> scores;

  /// Semua tugas kelompok, untuk rincian di halaman detail anggota.
  final List<Task> tasks;

  /// Jumlah rapat kelompok, untuk tabel "Hadir x/y" di laporan.
  final int totalMeetings;

  /// Kalau diisi, tab lain di navigasi bawah meneruskan indeksnya.
  final ValueChanged<int>? onTabSelected;

  @override
  State<DetailKontribusiKelompokScreen> createState() =>
      _DetailKontribusiKelompokScreenState();
}

class _DetailKontribusiKelompokScreenState
    extends State<DetailKontribusiKelompokScreen> {
  int _tab = 0;

  ContributionTotals get _totals => ContributionTotals.of(widget.scores);

  double get _fairShare {
    final fair = _totals.fairShare;
    if (fair > 0) return fair;
    final count = widget.group.studentCount;
    return count == 0 ? 0 : 100 / count;
  }

  int get _attentionCount =>
      widget.scores.where((score) => score.needsAttention).length;

  Future<void> _showExport() async {
    final days = await showCollabSheet<int>(
      context,
      builder: (_) => _ExportSheet(group: widget.group),
    );
    if (days == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PratinjauLaporanKontribusiScreen(
          group: widget.group,
          scores: widget.scores,
          tasks: widget.tasks,
          periodDays: days,
          totalMeetings: widget.totalMeetings,
        ),
      ),
    );
  }

  Future<void> _showFormula() => showCollabSheet<void>(
    context,
    scrollable: true,
    builder: (_) => _FormulaSheet(
      memberCount: widget.group.studentCount,
      fairShare: _fairShare,
    ),
  );

  void _openMember(ContributionScore score) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetailKontribusiAnggotaScreen(
          group: widget.group,
          scores: widget.scores,
          score: score,
          tasks: widget.tasks,
          onTabSelected: widget.onTabSelected,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(
          widget.group.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        titleTextStyle: HomeText.headline.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: ItsColors.blue,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Kontribusi',
                  style: const TextStyle(
                    fontFamily: AppFonts.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: ItsColors.ink,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _showExport,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Ekspor PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ItsColors.ink,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: Color(0xFFC4C6D0)),
                  textStyle: const TextStyle(
                    fontFamily: AppFonts.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FairShareCard(
            fairShare: _fairShare,
            warning: warningOf(_fairShare),
            memberCount: widget.group.studentCount,
            attentionCount: _attentionCount,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _showFormula,
              style: FilledButton.styleFrom(
                backgroundColor: ItsColors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontFamily: AppFonts.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Cara Menghitung Skor'),
            ),
          ),
          const SizedBox(height: 16),
          _SegmentTabs(
            value: _tab,
            onChanged: (value) => setState(() => _tab = value),
          ),
          const SizedBox(height: 16),
          if (_tab == 0)
            ..._perMember()
          else
            _CompositionTab(
              scores: widget.scores,
              memberCount: widget.group.studentCount,
              fairShare: _fairShare,
            ),
        ],
      ),
      bottomNavigationBar: ContributionNavBar(onSelected: widget.onTabSelected),
    );
  }

  List<Widget> _perMember() {
    if (widget.scores.isEmpty) {
      return const [
        NoteBox(
          'Skor kontribusi belum bisa dihitung. Selesaikan tugas, hadiri '
          'rapat, atau isi peer review dulu.',
        ),
      ];
    }
    return [
      _ChartCard(
        scores: widget.scores,
        totals: _totals,
        onTapMember: _openMember,
      ),
    ];
  }
}

class _FairShareCard extends StatelessWidget {
  const _FairShareCard({
    required this.fairShare,
    required this.warning,
    required this.memberCount,
    required this.attentionCount,
  });

  final double fairShare;
  final double warning;
  final int memberCount;
  final int attentionCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ItsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Porsi adil', style: HomeText.supporting),
                    const SizedBox(height: 2),
                    Text(
                      percentText(fairShare),
                      style: const TextStyle(
                        fontFamily: AppFonts.text,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: ItsColors.blue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '100% ÷ $memberCount anggota',
                      style: HomeText.meta.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Batas peringatan', style: HomeText.supporting),
                    const SizedBox(height: 2),
                    Text(
                      percentText(warning),
                      style: const TextStyle(
                        fontFamily: AppFonts.text,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: CColors.error,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '50% × porsi adil',
                      style: HomeText.meta.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (attentionCount > 0) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: ItsColors.border),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 17,
                  color: CColors.error,
                ),
                const SizedBox(width: 6),
                Text(
                  '$attentionCount anggota perlu perhatian',
                  style: const TextStyle(
                    fontFamily: AppFonts.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CColors.error,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentTabs extends StatelessWidget {
  const _SegmentTabs({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFC4C6D0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              label: 'Per anggota',
              active: value == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _Segment(
              label: 'Komposisi',
              active: value == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(100);
    return Semantics(
      selected: active,
      button: true,
      child: Material(
        color: active ? ItsColors.skyContainer : Colors.white,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (active) ...[
                  const Icon(
                    Icons.check,
                    size: 18,
                    color: ItsColors.onSkyContainer,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.text,
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: active ? ItsColors.onSkyContainer : ItsColors.ink,
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

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.scores,
    required this.totals,
    required this.onTapMember,
  });

  final List<ContributionScore> scores;
  final ContributionTotals totals;
  final ValueChanged<ContributionScore> onTapMember;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ItsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Skor per anggota', style: HomeText.section),
          const SizedBox(height: 2),
          Text(
            'Panjang bar = skor total, warna = asal skornya.',
            style: HomeText.meta.copyWith(fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (var i = 0; i < ContributionBarChart.partColors.length; i++)
                _LegendDot(
                  color: ContributionBarChart.partColors[i],
                  label: ContributionBarChart.partLabels[i],
                ),
            ],
          ),
          const SizedBox(height: 12),
          ContributionBarChart(
            scores: scores,
            totals: totals,
            onTapMember: onTapMember,
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppFonts.text,
            fontSize: 11,
            color: ItsColors.inkMuted,
          ),
        ),
      ],
    );
  }
}

class _CompositionTab extends StatelessWidget {
  const _CompositionTab({
    required this.scores,
    required this.memberCount,
    required this.fairShare,
  });

  final List<ContributionScore> scores;
  final int memberCount;
  final double fairShare;

  static const _palette = [
    ItsColors.blue,
    ItsColors.skyBlue,
    Color(0xFF4C9BC7),
    Color(0xFF5C6FA8),
    ItsColors.lightBlue,
    ItsColors.yellow,
  ];

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) {
      return const NoteBox(
        'Belum ada skor untuk dibagi. Komposisi muncul setelah ada tugas, '
        'rapat, atau peer review.',
      );
    }
    final colors = [
      for (var i = 0; i < scores.length; i++)
        scores[i].needsAttention
            ? CColors.error
            : _palette[i % _palette.length],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ItsColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Pembagian 100% kelompok', style: HomeText.section),
              const SizedBox(height: 2),
              Text(
                'Gambaran cepat untuk dosen dan ketua.',
                style: HomeText.meta.copyWith(fontSize: 11.5),
              ),
              const SizedBox(height: 16),
              Center(
                child: SizedBox.square(
                  dimension: 176,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size.square(176),
                        painter: _DonutPainter(
                          values: [
                            for (final score in scores) score.contributionPct,
                          ],
                          colors: colors,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$memberCount',
                            style: const TextStyle(
                              fontFamily: AppFonts.text,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1,
                              color: ItsColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('anggota', style: HomeText.meta),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < scores.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[i],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          scores[i].fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: ItsColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        percentText(scores[i].contributionPct),
                        style: TextStyle(
                          fontFamily: AppFonts.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scores[i].needsAttention
                              ? CColors.error
                              : ItsColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _LabelMeaningCard(fairShare: fairShare),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values, required this.colors});

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - 13,
    );
    const stroke = 22.0;
    const gap = 0.03;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      if (sweep <= 0) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = colors[i];
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(0, sweep - gap),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}

class _LabelMeaningCard extends StatelessWidget {
  const _LabelMeaningCard({required this.fairShare});

  final double fairShare;

  @override
  Widget build(BuildContext context) {
    final high = fairShare * 1.25;
    final balanced = fairShare * 0.9;
    final warning = warningOf(fairShare);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ItsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Arti label', style: HomeText.section),
          const SizedBox(height: 2),
          Text(
            'Skor dibandingkan dengan porsi adil (${percentText(fairShare)}), '
            'jadi tetap adil berapa pun jumlah anggotanya.',
            style: HomeText.meta.copyWith(fontSize: 11.5, height: 1.5),
          ),
          const SizedBox(height: 12),
          _LabelMeaningRow(
            title: 'Kontribusi tinggi',
            rule: '≥ 1,25 × porsi adil',
            range: '≥ ${percentText(high)}',
          ),
          const Divider(height: 1, color: ItsColors.border),
          _LabelMeaningRow(
            title: 'Seimbang',
            rule: '0,9 sampai < 1,25 × porsi adil',
            range: '${percentText(balanced)}–${percentText(high - 0.1)}',
          ),
          const Divider(height: 1, color: ItsColors.border),
          _LabelMeaningRow(
            title: 'Di bawah rata-rata',
            rule: '0,5 sampai < 0,9 × porsi adil',
            range: '${percentText(warning)}–${percentText(balanced - 0.1)}',
          ),
          const Divider(height: 1, color: ItsColors.border),
          _LabelMeaningRow(
            title: 'Perlu perhatian',
            rule: '< 0,5 × porsi adil',
            range: '< ${percentText(warning)}',
          ),
          const SizedBox(height: 12),
          Text(
            'Label hanya alat bantu. Keputusan nilai akhir tetap di dosen.',
            style: HomeText.meta.copyWith(fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _LabelMeaningRow extends StatelessWidget {
  const _LabelMeaningRow({
    required this.title,
    required this.rule,
    required this.range,
  });

  final String title;
  final String rule;
  final String range;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppFonts.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ItsColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(rule, style: HomeText.meta.copyWith(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            range,
            style: const TextStyle(
              fontFamily: AppFonts.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ItsColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.group});

  final Group group;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  int _days = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetTitle(title: 'Ekspor laporan PDF', subtitle: widget.group.name),
        const SizedBox(height: 16),
        const Text(
          'Periode',
          style: TextStyle(
            fontFamily: AppFonts.text,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ItsColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        _PeriodRow(
          label: 'Seluruh proyek',
          selected: _days == 0,
          onTap: () => setState(() => _days = 0),
        ),
        _PeriodRow(
          label: '30 hari terakhir',
          selected: _days == 30,
          onTap: () => setState(() => _days = 30),
        ),
        const SizedBox(height: 12),
        const _InfoNote(
          'Laporan mencantumkan tanggal cetak dan catatan bahwa skor adalah '
          'alat bantu penilaian.',
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(_days),
            icon: const Icon(Icons.download_outlined, size: 20),
            label: const Text('Buat PDF'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 22,
              color: selected ? ItsColors.blue : CColors.outline,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppFonts.text,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: ItsColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormulaSheet extends StatelessWidget {
  const _FormulaSheet({required this.memberCount, required this.fairShare});

  final int memberCount;
  final double fairShare;

  @override
  Widget build(BuildContext context) {
    final warning = warningOf(fairShare);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetTitle(
            title: 'Cara menghitung skor',
            subtitle:
                'Skor menunjukkan seberapa besar bagianmu dari total kerja '
                'kelompok.',
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFC4C6D0)),
            ),
            child: Column(
              children: [
                _WeightRow('Porsi tugas', '× 60%', first: true),
                _WeightRow('Porsi kehadiran', '× 15%'),
                _WeightRow('Porsi peer review', '× 15%'),
                _WeightRow('Porsi validasi', '× 10%'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Porsi = nilai anggota ÷ total nilai semua anggota di komponen '
            'itu. Keempat hasilnya dijumlah jadi skor kontribusi.',
            style: HomeText.supporting.copyWith(height: 1.6),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nilai tiap komponen',
            style: TextStyle(
              fontFamily: AppFonts.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ItsColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const _Bullet('Tugas: ringan 1, sedang 2, berat 3 poin'),
          const _Bullet('Hanya tugas berstatus Disetujui yang dihitung'),
          const _Bullet('Tugas terlambat dikali 0,7'),
          const _Bullet('Peer review yang belum diisi dianggap 3,0'),
          const SizedBox(height: 16),
          const Text(
            'Porsi adil dan peringatan',
            style: TextStyle(
              fontFamily: AppFonts.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ItsColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          _Bullet(
            'Porsi adil = 100% ÷ jumlah anggota ($memberCount anggota = '
            '${percentText(fairShare)})',
          ),
          _Bullet(
            'Tanda peringatan muncul kalau skor di bawah 50% porsi adil '
            '(${percentText(warning)})',
          ),
          const SizedBox(height: 16),
          const _InfoNote(
            'Skor hanya alat bantu. Keputusan nilai akhir tetap di dosen.',
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Mengerti'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightRow extends StatelessWidget {
  const _WeightRow(this.label, this.weight, {this.first = false});

  final String label;
  final String weight;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        border: first
            ? null
            : const Border(top: BorderSide(color: Color(0xFFE2E4EC))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppFonts.text,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: ItsColors.ink,
              ),
            ),
          ),
          Text(
            weight,
            style: const TextStyle(
              fontFamily: AppFonts.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ItsColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 14,
            child: Text(
              '•',
              style: TextStyle(
                fontFamily: AppFonts.text,
                fontSize: 13,
                height: 1.55,
                color: ItsColors.inkMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: HomeText.supporting.copyWith(height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 18, color: ItsColors.inkMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: HomeText.meta.copyWith(fontSize: 12, height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title, required this.subtitle});

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
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontFamily: AppFonts.text,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: ItsColors.ink,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: HomeText.supporting.copyWith(height: 1.5)),
        ],
      ],
    );
  }
}
