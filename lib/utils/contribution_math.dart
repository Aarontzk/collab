import 'package:collab/models/contribution.dart';
import 'package:collab/models/task.dart';

/// Total nilai tiap komponen di satu kelompok, dipakai untuk menghitung porsi.
class ContributionTotals {
  const ContributionTotals({
    required this.tasks,
    required this.attendance,
    required this.review,
    required this.validation,
    required this.fairShare,
    required this.memberCount,
  });

  final double tasks;
  final double attendance;
  final double review;
  final double validation;

  /// Porsi adil 0–100.
  final double fairShare;
  final int memberCount;

  factory ContributionTotals.of(List<ContributionScore> scores) {
    final count = scores.length;
    return ContributionTotals(
      tasks: scores.fold(0, (sum, s) => sum + s.taskPoints),
      attendance: scores.fold(
        0,
        (sum, s) => sum + s.meetingsAttended.toDouble(),
      ),
      review: scores.fold(0, (sum, s) => sum + s.peerAvg),
      validation: scores.fold(
        0,
        (sum, s) => sum + s.validationsGiven.toDouble(),
      ),
      fairShare: count == 0
          ? 0
          : scores.first.fairSharePct > 0
          ? scores.first.fairSharePct
          : 100 / count,
      memberCount: count,
    );
  }

  /// Batas peringatan: 50% porsi adil.
  double get warning => warningOf(fairShare);
}

/// Batas peringatan dibulatkan ke bawah satu desimal supaya 14,3% → 7,1%
/// seperti tampilan di desain.
double warningOf(double fairShare) =>
    (fairShare * 0.5 * 10).floorToDouble() / 10;

/// Porsi skor satu anggota untuk tiap komponen (sudah dikali bobotnya).
class ContributionParts {
  const ContributionParts({
    required this.tasks,
    required this.attendance,
    required this.review,
    required this.validation,
  });

  final double tasks;
  final double attendance;
  final double review;
  final double validation;

  double get total => tasks + attendance + review + validation;
}

/// Rumus sama dengan RPC `contribution_scores`: 60/15/15/10, dibagi rata
/// kalau total komponen masih nol.
ContributionParts contributionPartsOf(
  ContributionScore score,
  ContributionTotals totals,
) {
  double share(double value, double total) {
    if (total > 0) return value / total;
    if (totals.memberCount == 0) return 0;
    return 1 / totals.memberCount;
  }

  return ContributionParts(
    tasks: 60 * share(score.taskPoints, totals.tasks),
    attendance: 15 * share(score.meetingsAttended.toDouble(), totals.attendance),
    review: 15 * share(score.peerAvg, totals.review),
    validation: 10 * share(score.validationsGiven.toDouble(), totals.validation),
  );
}

/// Skala maksimum grafik: skor tertinggi atau porsi adil, dibulatkan ke 5.
double chartMaxFor(List<ContributionScore> scores, double fairShare) {
  var max = fairShare;
  for (final score in scores) {
    if (score.contributionPct > max) max = score.contributionPct;
  }
  final rounded = (max / 5).ceil() * 5.0;
  return rounded.clamp(20, 100);
}

/// Label sama dengan "Arti label" di halaman Komposisi.
String scoreLabel(double contributionPct, double fairShare) {
  if (contributionPct < fairShare * 0.5) return 'Perlu perhatian';
  if (contributionPct >= fairShare * 1.25) return 'Kontribusi tinggi';
  if (contributionPct >= fairShare * 0.9) return 'Seimbang';
  return 'Di bawah rata-rata';
}

/// Poin tugas: bobot × faktor tepat waktu (telat 0,7). Hanya yang disetujui.
double taskPointsOf(Task task) {
  if (task.status != TaskStatus.approved) return 0;
  return task.weight.points * (isTaskLate(task) ? 0.7 : 1);
}

/// Sama dengan server: dibandingkan waktu submit, bukan waktu approve.
bool isTaskLate(Task task) {
  final due = task.deadline;
  if (due == null) return false;
  final submitted = task.submittedAt ?? task.approvedAt;
  if (submitted == null) return false;
  return submitted.isAfter(due);
}

String decimalText(double value, int decimals) =>
    value.toStringAsFixed(decimals).replaceAll('.', ',');

/// "6,9%" — default satu desimal.
String percentText(double value, {int decimals = 1}) =>
    '${decimalText(value, decimals)}%';

String firstNameOf(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  for (final part in parts) {
    if (part.length > 1) return part;
  }
  return parts.first;
}

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// "15 Nov 2026".
String dateText(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

/// "25 Okt".
String dayMonthText(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]}';
