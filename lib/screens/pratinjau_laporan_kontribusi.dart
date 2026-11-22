import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:collab/models/contribution.dart';
import 'package:collab/models/group.dart';
import 'package:collab/models/task.dart';
import 'package:collab/utils/app_assets.dart';
import 'package:collab/utils/contribution_math.dart';
import 'package:collab/utils/theme.dart';
import 'package:collab/widgets/brand_lockup.dart';
import 'package:collab/widgets/common_widgets.dart';
import 'package:collab/widgets/contribution_chart.dart';
import 'package:collab/widgets/home_cards.dart';

/// Pratinjau laporan kontribusi sebelum dibagikan atau disimpan sebagai PDF.
class PratinjauLaporanKontribusiScreen extends StatefulWidget {
  const PratinjauLaporanKontribusiScreen({
    super.key,
    required this.group,
    required this.scores,
    this.tasks = const [],
    this.periodDays = 0,
    this.totalMeetings = 0,
  });

  final Group group;
  final List<ContributionScore> scores;
  final List<Task> tasks;

  /// 0 = seluruh proyek, 30 = 30 hari terakhir.
  final int periodDays;
  final int totalMeetings;

  @override
  State<PratinjauLaporanKontribusiScreen> createState() =>
      _PratinjauLaporanKontribusiScreenState();
}

class _PratinjauLaporanKontribusiScreenState
    extends State<PratinjauLaporanKontribusiScreen> {
  bool _busy = false;

  ContributionTotals get _totals => ContributionTotals.of(widget.scores);

  int get _attentionCount =>
      widget.scores.where((score) => score.needsAttention).length;

  DateTime get _periodStart {
    final now = DateTime.now();
    if (widget.periodDays > 0) {
      return now.subtract(Duration(days: widget.periodDays));
    }
    DateTime? earliest;
    for (final task in widget.tasks) {
      final date = task.createdAt;
      if (date != null && (earliest == null || date.isBefore(earliest))) {
        earliest = date;
      }
    }
    return earliest ?? now.subtract(const Duration(days: 21));
  }

  String get _periodLabel {
    final start = dayMonthText(_periodStart);
    final end = dateText(DateTime.now());
    final range = '$start sampai $end';
    return widget.periodDays > 0
        ? '30 hari terakhir ($range)'
        : 'seluruh proyek ($range)';
  }

  String get _fileName {
    final slug = widget.group.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return 'laporan-kontribusi-${slug.isEmpty ? 'kelompok' : slug}.pdf';
  }

  Future<void> _export({required bool share}) async {
    setState(() => _busy = true);
    try {
      final document = await _buildDocument();
      final bytes = await document.save();
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: _fileName);
      } else {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: _fileName,
        );
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<pw.Document> _buildDocument() async {
    final logoData = await rootBundle.load(AppAssets.logoMark);
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());
    final totals = _totals;
    final maxScale = chartMaxFor(widget.scores, totals.fairShare);
    final printedAt = DateTime.now();

    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey600,
            ),
          ),
        ),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                children: [
                  pw.Image(logo, height: 18),
                  pw.SizedBox(width: 5),
                  pw.Text(
                    'Collab',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#243F81'),
                    ),
                  ),
                ],
              ),
              pw.Text(
                'Dicetak ${dateText(printedAt)}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Laporan Kontribusi Anggota',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            '${widget.group.name}, ${widget.group.displayCourse}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            'Periode: $_periodLabel',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              _pdfStat(
                'Porsi adil',
                percentText(totals.fairShare),
                PdfColor.fromHex('#243F81'),
                PdfColor.fromHex('#E9EEF9'),
              ),
              pw.SizedBox(width: 6),
              _pdfStat(
                'Batas peringatan',
                percentText(totals.warning),
                PdfColor.fromHex('#B3261E'),
                PdfColor.fromHex('#FBEAE8'),
              ),
              pw.SizedBox(width: 6),
              _pdfStat(
                'Perlu perhatian',
                '$_attentionCount anggota',
                PdfColor.fromHex('#B3261E'),
                PdfColor.fromHex('#FBEAE8'),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Skor per anggota',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 45, right: 36),
            child: pw.Text(
              'Porsi adil ${percentText(totals.fairShare)}',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 6.5,
                color: PdfColor.fromHex('#B3261E'),
              ),
            ),
          ),
          pw.SizedBox(height: 3),
          for (final score in widget.scores)
            _pdfBar(score, totals, maxScale),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 45, right: 36),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                for (var value = 0.0; value <= maxScale; value += 5)
                  pw.Text(
                    '${value.toInt()}%',
                    style: const pw.TextStyle(
                      fontSize: 6,
                      color: PdfColors.grey600,
                    ),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Rincian',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Anggota',
              'Tugas',
              'Hadir',
              'Review',
              'Valid.',
              'Skor',
              'Label',
            ],
            data: [
              for (final score in widget.scores)
                [
                  score.fullName,
                  decimalText(score.taskPoints, 1),
                  widget.totalMeetings > 0
                      ? '${score.meetingsAttended}/${widget.totalMeetings}'
                      : '${score.meetingsAttended}',
                  decimalText(score.peerAvg, 1),
                  '${score.validationsGiven}',
                  percentText(score.contributionPct),
                  scoreLabel(score.contributionPct, totals.fairShare),
                ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
            ),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 4,
            ),
            border: pw.TableBorder.all(
              color: PdfColors.grey400,
              width: 0.4,
            ),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Skor adalah alat bantu. Keputusan nilai akhir tetap di dosen.',
            style: const pw.TextStyle(
              fontSize: 7.5,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
    return document;
  }

  pw.Widget _pdfStat(
    String label,
    String value,
    PdfColor color,
    PdfColor background,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(7),
        decoration: pw.BoxDecoration(
          color: background,
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 6.5,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfBar(
    ContributionScore score,
    ContributionTotals totals,
    double maxScale,
  ) {
    final parts = contributionPartsOf(score, totals);
    final values = [
      parts.tasks,
      parts.attendance,
      parts.review,
      parts.validation,
    ];
    final colors = [
      PdfColor.fromHex('#243F81'),
      PdfColor.fromHex('#127BBE'),
      PdfColor.fromHex('#75BDE0'),
      PdfColor.fromHex('#FDBB16'),
    ];
    final remaining = math.max(0.0, maxScale - parts.total);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(
            width: 45,
            child: pw.Text(
              firstNameOf(score.fullName),
              style: const pw.TextStyle(fontSize: 7),
            ),
          ),
          pw.Expanded(
            child: pw.ClipRRect(
              horizontalRadius: 2,
              verticalRadius: 2,
              child: pw.Row(
                children: [
                  for (var i = 0; i < values.length; i++)
                    if (values[i] > 0.01)
                      pw.Expanded(
                        flex: math.max(1, (values[i] * 100).round()),
                        child: pw.Container(
                          height: 7,
                          color: colors[i],
                        ),
                      ),
                  if (remaining > 0.01)
                    pw.Expanded(
                      flex: math.max(1, (remaining * 100).round()),
                      child: pw.Container(
                        height: 7,
                        color: PdfColors.grey300,
                      ),
                    ),
                ],
              ),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.SizedBox(
            width: 30,
            child: pw.Text(
              percentText(score.contributionPct),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: score.needsAttention
                    ? PdfColor.fromHex('#B3261E')
                    : PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ItsColors.surfaceLow,
      appBar: AppBar(
        backgroundColor: ItsColors.surfaceLow,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('Pratinjau laporan'),
        titleTextStyle: HomeText.headline.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: ItsColors.blue,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: _ReportPage(
              group: widget.group,
              scores: widget.scores,
              totals: _totals,
              attentionCount: _attentionCount,
              periodLabel: _periodLabel,
              totalMeetings: widget.totalMeetings,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Halaman 1 dari 1',
              style: HomeText.meta.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ActionBar(
        busy: _busy,
        onShare: () => _export(share: true),
        onSave: () => _export(share: false),
      ),
    );
  }
}

class _ReportPage extends StatelessWidget {
  const _ReportPage({
    required this.group,
    required this.scores,
    required this.totals,
    required this.attentionCount,
    required this.periodLabel,
    required this.totalMeetings,
  });

  final Group group;
  final List<ContributionScore> scores;
  final ContributionTotals totals;
  final int attentionCount;
  final String periodLabel;
  final int totalMeetings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const BrandLockup(size: 20),
            const Spacer(),
            Text(
              'Dicetak ${dateText(DateTime.now())}',
              style: HomeText.meta.copyWith(fontSize: 9.5),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Laporan Kontribusi Anggota',
          style: TextStyle(
            fontFamily: AppFonts.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: ItsColors.ink,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${group.name}, ${group.displayCourse}',
          style: HomeText.meta.copyWith(fontSize: 10.5),
        ),
        Text(
          'Periode: $periodLabel',
          style: HomeText.meta.copyWith(fontSize: 9.5),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatBox(
                label: 'Porsi adil',
                value: percentText(totals.fairShare),
                color: ItsColors.blue,
                background: const Color(0xFFE9EEF9),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _StatBox(
                label: 'Batas peringatan',
                value: percentText(totals.warning),
                color: const Color(0xFFB3261E),
                background: const Color(0xFFFBEAE8),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _StatBox(
                label: 'Perlu perhatian',
                value: '$attentionCount anggota',
                color: const Color(0xFFB3261E),
                background: const Color(0xFFFBEAE8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Skor per anggota',
          style: TextStyle(
            fontFamily: AppFonts.text,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: ItsColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        ContributionBarChart(
          scores: scores,
          totals: totals,
          scaleMax: chartMaxFor(scores, totals.fairShare),
          showAxis: true,
          showFooter: false,
          showFairLabel: true,
          compact: true,
        ),
        const SizedBox(height: 14),
        const Text(
          'Rincian',
          style: TextStyle(
            fontFamily: AppFonts.text,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: ItsColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        _ReportTable(
          scores: scores,
          totals: totals,
          totalMeetings: totalMeetings,
        ),
        const SizedBox(height: 8),
        Text(
          'Skor adalah alat bantu. Keputusan nilai akhir tetap di dosen.',
          style: HomeText.meta.copyWith(fontSize: 8),
        ),
        const SizedBox(height: 6),
        Text(
          '1 / 1',
          textAlign: TextAlign.right,
          style: HomeText.meta.copyWith(fontSize: 8),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HomeText.meta.copyWith(fontSize: 8),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({
    required this.scores,
    required this.totals,
    required this.totalMeetings,
  });

  final List<ContributionScore> scores;
  final ContributionTotals totals;
  final int totalMeetings;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD7D9E3)),
      ),
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF2F3FA),
            child: Row(
              children: const [
                _Cell('Anggota', flex: 34, bold: true),
                _Cell('Tugas', flex: 12, bold: true, right: true),
                _Cell('Hadir', flex: 12, bold: true, right: true),
                _Cell('Review', flex: 12, bold: true, right: true),
                _Cell('Valid.', flex: 10, bold: true, right: true),
                _Cell('Skor', flex: 13, bold: true, right: true),
                _Cell('Label', flex: 20, bold: true, right: true),
              ],
            ),
          ),
          for (var i = 0; i < scores.length; i++)
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E4EC))),
              ),
              child: Row(
                children: [
                  _Cell(scores[i].fullName, flex: 34),
                  _Cell(
                    decimalText(scores[i].taskPoints, 1),
                    flex: 12,
                    right: true,
                  ),
                  _Cell(
                    totalMeetings > 0
                        ? '${scores[i].meetingsAttended}/$totalMeetings'
                        : '${scores[i].meetingsAttended}',
                    flex: 12,
                    right: true,
                  ),
                  _Cell(
                    decimalText(scores[i].peerAvg, 1),
                    flex: 12,
                    right: true,
                  ),
                  _Cell('${scores[i].validationsGiven}', flex: 10, right: true),
                  _Cell(
                    percentText(scores[i].contributionPct),
                    flex: 13,
                    right: true,
                  ),
                  _Cell(
                    scoreLabel(
                      scores[i].contributionPct,
                      totals.fairShare,
                    ),
                    flex: 20,
                    right: true,
                    color: scores[i].needsAttention
                        ? const Color(0xFFB3261E)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(
    this.text, {
    required this.flex,
    this.bold = false,
    this.right = false,
    this.color,
  });

  final String text;
  final int flex;
  final bool bold;
  final bool right;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontFamily: AppFonts.text,
            fontSize: 7.5,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: color ?? ItsColors.ink,
          ),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.busy,
    required this.onShare,
    required this.onSave,
  });

  final bool busy;
  final VoidCallback onShare;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: busy ? null : onShare,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ItsColors.ink,
                    side: const BorderSide(color: Color(0xFFC4C6D0)),
                    textStyle: const TextStyle(
                      fontFamily: AppFonts.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Bagikan'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: busy ? null : onSave,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Simpan PDF'),
                  style: FilledButton.styleFrom(
                    textStyle: const TextStyle(
                      fontFamily: AppFonts.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
