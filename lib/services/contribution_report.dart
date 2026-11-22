import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:collab/models/contribution.dart';
import 'package:collab/models/group.dart';
import 'package:collab/utils/dates.dart';

/// Pilihan isi laporan kontribusi.
class ReportOptions {
  const ReportOptions({
    this.chart = true,
    this.breakdown = true,
    this.raw = true,
  });

  final bool chart;
  final bool breakdown;
  final bool raw;

  bool get any => chart || breakdown || raw;

  ReportOptions copyWith({bool? chart, bool? breakdown, bool? raw}) =>
      ReportOptions(
        chart: chart ?? this.chart,
        breakdown: breakdown ?? this.breakdown,
        raw: raw ?? this.raw,
      );
}

/// Font bawaan PDF hanya Latin-1, jadi angka ditulis dengan koma biasa.
String _p(double v) => '${v.toStringAsFixed(1).replaceAll('.', ',')}%';

/// Susun PDF laporan kontribusi. Fungsi terpisah supaya bisa dites.
Future<Uint8List> buildContributionReport(
  Group group,
  List<Contribution> scores,
  ReportOptions options, {
  DateTime? printedAt,
}) async {
  final doc = pw.Document(title: 'Laporan Kontribusi ${group.name}');
  final fair = scores.isEmpty ? 0.0 : scores.first.fairSharePct;
  final now = printedAt ?? DateTime.now();
  const navy = PdfColor.fromInt(0xFF243F81);
  const red = PdfColor.fromInt(0xFFB3261E);
  final maxPct = scores.fold<double>(
    fair,
    (m, c) => c.contributionPct > m ? c.contributionPct : m,
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Laporan Kontribusi',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: navy,
            ),
          ),
          pw.Text(
            [group.name, ?group.courseName].join(' - '),
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.Text(
            'Dicetak ${formatDateShort(now)} - Porsi adil ${_p(fair)}, '
            'batas peringatan ${_p(fair / 2)}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),
        ],
      ),
      footer: (_) => pw.Text(
        'Skor hanya alat bantu penilaian. Keputusan nilai akhir tetap di dosen.',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
      build: (_) => [
        if (options.chart) ...[
          pw.Text(
            'Skor per anggota',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          for (final c in scores)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                children: [
                  pw.SizedBox(
                    width: 140,
                    child: pw.Text(
                      c.fullName,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.LayoutBuilder(
                      builder: (_, box) => pw.Container(
                        width:
                            (box?.maxWidth ?? 200) *
                            (maxPct == 0 ? 0 : c.contributionPct / maxPct),
                        height: 8,
                        color: c.needsAttention ? red : navy,
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: 44,
                    child: pw.Text(
                      _p(c.contributionPct),
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ],
              ),
            ),
          pw.SizedBox(height: 14),
        ],
        if (options.breakdown) ...[
          pw.Text(
            'Rincian perhitungan (bobot 60/15/15/10)',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headers: [
              'Anggota',
              'Tugas',
              'Kehadiran',
              'Peer review',
              'Validasi',
              'Total',
            ],
            data: [
              for (final c in scores)
                () {
                  final b = ScoreBreakdown.of(c, scores);
                  return [
                    c.fullName,
                    _p(b.tasks),
                    _p(b.attendance),
                    _p(b.review),
                    _p(b.validation),
                    _p(c.contributionPct),
                  ];
                }(),
            ],
          ),
          pw.SizedBox(height: 14),
        ],
        if (options.raw) ...[
          pw.Text(
            'Data mentah per anggota',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headers: [
              'Anggota',
              'Poin tugas',
              'Hadir',
              'Rata-rata review',
              'Validasi',
              'Label',
            ],
            data: [
              for (final c in scores)
                [
                  c.fullName,
                  c.taskPoints.toStringAsFixed(1),
                  '${c.meetingsAttended}',
                  c.peerAvg.toStringAsFixed(1),
                  '${c.validationsGiven}',
                  ContributionLabel.of(c).label,
                ],
            ],
          ),
        ],
      ],
    ),
  );
  return doc.save();
}

/// Buat PDF lalu buka dialog bagikan/simpan bawaan HP.
Future<void> shareContributionReport(
  Group group,
  List<Contribution> scores,
  ReportOptions options,
) async {
  final bytes = await buildContributionReport(group, scores, options);
  final safeName = group.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  await Printing.sharePdf(
    bytes: bytes,
    filename: 'Laporan_Kontribusi_$safeName.pdf',
  );
}
