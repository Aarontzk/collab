import 'package:flutter/material.dart';

import 'package:collab/models/contribution.dart';
import 'package:collab/utils/contribution_math.dart';
import 'package:collab/utils/theme.dart';

/// Grafik batang bertumpuk: panjang bar = skor, warna = asal skornya.
///
/// Dipakai di halaman Kontribusi (per anggota), detail anggota, dan
/// pratinjau laporan. Garis putus-putus menandai batas peringatan dan
/// porsi adil.
class ContributionBarChart extends StatelessWidget {
  const ContributionBarChart({
    super.key,
    required this.scores,
    required this.totals,
    this.onTapMember,
    this.scaleMax,
    this.showNames = true,
    this.showValues = true,
    this.showAxis = false,
    this.showFooter = true,
    this.showFairLabel = true,
    this.compact = false,
  });

  final List<ContributionScore> scores;
  final ContributionTotals totals;
  final ValueChanged<ContributionScore>? onTapMember;

  /// Skala 0–100. Kalau null, dihitung dari skor tertinggi.
  final double? scaleMax;
  final bool showNames;
  final bool showValues;
  final bool showAxis;
  final bool showFooter;
  final bool showFairLabel;
  final bool compact;

  static const partColors = [
    ItsColors.blue,
    ItsColors.skyBlue,
    ItsColors.lightBlue,
    ItsColors.yellow,
  ];

  static const partLabels = ['Tugas', 'Kehadiran', 'Peer review', 'Validasi'];

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) return const SizedBox.shrink();
    final maxScale = scaleMax ?? chartMaxFor(scores, totals.fairShare);
    const gap = 8.0;
    final nameWidth = showNames ? (compact ? 46.0 : 52.0) : 0.0;
    final valueWidth = showValues ? (compact ? 38.0 : 46.0) : 0.0;
    final barLeft = nameWidth + (showNames ? gap : 0);
    final barRight = valueWidth + (showValues ? gap : 0);
    final barHeight = compact ? 9.0 : 14.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = (constraints.maxWidth - barLeft - barRight).clamp(
          40.0,
          double.infinity,
        );
        final scale = barWidth / maxScale;
        final warningX = totals.warning * scale;
        final fairX = totals.fairShare * scale;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showFairLabel)
              SizedBox(
                height: 16,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: (barLeft + fairX - 42).clamp(
                        0.0,
                        (constraints.maxWidth - 84).clamp(0.0, double.infinity),
                      ),
                      width: 84,
                      bottom: 0,
                      child: Text(
                        'Porsi adil ${percentText(totals.fairShare)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: AppFonts.text,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB3261E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Stack(
              children: [
                Column(
                  children: [
                    for (final score in scores)
                      _ChartRow(
                        score: score,
                        parts: contributionPartsOf(score, totals),
                        maxScale: maxScale,
                        nameWidth: nameWidth,
                        valueWidth: valueWidth,
                        barHeight: barHeight,
                        showNames: showNames,
                        showValues: showValues,
                        compact: compact,
                        onTap: onTapMember == null
                            ? null
                            : () => onTapMember!(score),
                      ),
                  ],
                ),
                Positioned(
                  left: barLeft + warningX,
                  top: 0,
                  bottom: 0,
                  child: const SizedBox(
                    width: 1,
                    child: CustomPaint(
                      painter: _DashedLinePainter(color: Color(0xFFB3261E)),
                    ),
                  ),
                ),
                Positioned(
                  left: barLeft + fairX,
                  top: 0,
                  bottom: 0,
                  child: const SizedBox(
                    width: 1,
                    child: CustomPaint(
                      painter: _DashedLinePainter(color: Color(0xFFB3261E)),
                    ),
                  ),
                ),
              ],
            ),
            if (showAxis) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  SizedBox(width: barLeft),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var value = 0.0; value <= maxScale; value += 5)
                          Text(
                            '${value.toInt()}%',
                            style: const TextStyle(
                              fontFamily: AppFonts.text,
                              fontSize: 8,
                              color: ItsColors.inkMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: barRight),
                ],
              ),
            ],
            if (showFooter) ...[
              const SizedBox(height: 4),
              SizedBox(
                height: 14,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: barLeft,
                      bottom: 0,
                      child: Text(
                        'Batas ${percentText(totals.warning)}',
                        style: const TextStyle(
                          fontFamily: AppFonts.text,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: ItsColors.inkMuted,
                        ),
                      ),
                    ),
                    Positioned(
                      left: (barLeft + fairX - 36).clamp(
                        0.0,
                        (constraints.maxWidth - 72).clamp(0.0, double.infinity),
                      ),
                      width: 72,
                      bottom: 0,
                      child: Text(
                        'Porsi adil ${percentText(totals.fairShare)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: AppFonts.text,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB3261E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ChartRow extends StatelessWidget {
  const _ChartRow({
    required this.score,
    required this.parts,
    required this.maxScale,
    required this.nameWidth,
    required this.valueWidth,
    required this.barHeight,
    required this.showNames,
    required this.showValues,
    required this.compact,
    this.onTap,
  });

  final ContributionScore score;
  final ContributionParts parts;
  final double maxScale;
  final double nameWidth;
  final double valueWidth;
  final double barHeight;
  final bool showNames;
  final bool showValues;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final values = [
      parts.tasks,
      parts.attendance,
      parts.review,
      parts.validation,
    ];
    final row = SizedBox(
      height: compact ? 20 : 28,
      child: Row(
        children: [
          if (showNames)
            SizedBox(
              width: nameWidth,
              child: Text(
                firstNameOf(score.fullName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.text,
                  fontSize: compact ? 8 : 10,
                  fontWeight: FontWeight.w600,
                  color: ItsColors.ink,
                ),
              ),
            ),
          if (showNames) const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = constraints.maxWidth / maxScale;
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9EBF3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Row(
                        children: [
                          for (var i = 0; i < values.length; i++)
                            if (values[i] * scale > 0.2)
                              Container(
                                width: values[i] * scale,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: ContributionBarChart.partColors[i],
                                  border: i == values.length - 1 ||
                                          values
                                                  .skip(i + 1)
                                                  .every((v) => v <= 0.001)
                                      ? null
                                      : const Border(
                                          right: BorderSide(
                                            color: Colors.white,
                                            width: 1,
                                          ),
                                        ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (showValues) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: valueWidth,
              child: Text(
                percentText(score.contributionPct),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: AppFonts.text,
                  fontSize: compact ? 8 : 10,
                  fontWeight: FontWeight.w700,
                  color: score.needsAttention
                      ? const Color(0xFFB3261E)
                      : ItsColors.ink,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: 'Lihat detail ${score.fullName}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: row,
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    const dash = 4.0;
    const gap = 4.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dash), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
