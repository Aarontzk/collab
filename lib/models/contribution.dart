/// Nama lama yang dipakai screen kontribusi.
typedef ContributionScore = Contribution;

/// Satu baris hasil `contribution_scores(gid)` di Supabase.
class Contribution {
  const Contribution({
    required this.userId,
    required this.fullName,
    required this.taskPoints,
    required this.meetingsAttended,
    required this.peerAvg,
    required this.validationsGiven,
    required this.contributionPct,
    required this.fairSharePct,
    required this.needsAttention,
  });

  final String userId;
  final String fullName;
  final double taskPoints;
  final int meetingsAttended;
  final double peerAvg;
  final int validationsGiven;
  final double contributionPct;
  final double fairSharePct;
  final bool needsAttention;

  /// Kontribusi dibanding porsi adil. 1.0 = pas porsi adil.
  double get ratioToFairShare =>
      fairSharePct == 0 ? 0 : contributionPct / fairSharePct;

  /// Ada data yang bisa dihitung, bukan sekadar porsi rata-rata bawaan.
  bool get hasActivity =>
      taskPoints > 0 ||
      meetingsAttended > 0 ||
      validationsGiven > 0 ||
      (peerAvg - 3).abs() > 0.001;

  factory Contribution.fromJson(Map<String, dynamic> json) => Contribution(
    userId: json['user_id'] as String,
    fullName: json['full_name'] as String,
    taskPoints: (json['task_points'] as num).toDouble(),
    meetingsAttended: (json['meetings_attended'] as num).toInt(),
    peerAvg: (json['peer_avg'] as num).toDouble(),
    validationsGiven: (json['validations_given'] as num).toInt(),
    contributionPct: (json['contribution_pct'] as num).toDouble(),
    fairSharePct: (json['fair_share_pct'] as num).toDouble(),
    needsAttention: json['needs_attention'] as bool,
  );
}

/// Bagian skor dari tiap komponen, dalam poin persen (jumlahnya = skor total).
/// Rumusnya sama dengan contribution_scores() di Supabase: porsi anggota
/// terhadap total kelompok untuk tiap komponen, dikali bobotnya.
class ScoreBreakdown {
  const ScoreBreakdown({
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

  static const weights = (
    tasks: 60.0,
    attendance: 15.0,
    review: 15.0,
    validation: 10.0,
  );

  factory ScoreBreakdown.of(Contribution c, List<Contribution> all) {
    final n = all.isEmpty ? 1 : all.length;
    double share(double mine, double total) => total > 0 ? mine / total : 1 / n;
    double sum(double Function(Contribution) f) =>
        all.fold(0, (s, x) => s + f(x));
    return ScoreBreakdown(
      tasks: weights.tasks * share(c.taskPoints, sum((x) => x.taskPoints)),
      attendance:
          weights.attendance *
          share(
            c.meetingsAttended.toDouble(),
            sum((x) => x.meetingsAttended.toDouble()),
          ),
      review: weights.review * share(c.peerAvg, sum((x) => x.peerAvg)),
      validation:
          weights.validation *
          share(
            c.validationsGiven.toDouble(),
            sum((x) => x.validationsGiven.toDouble()),
          ),
    );
  }
}

/// Label pembanding terhadap porsi adil (hanya alat bantu).
enum ContributionLabel {
  high('Kontribusi tinggi', '≥ 1,25 × porsi adil'),
  balanced('Seimbang', '0,9 sampai < 1,25 × porsi adil'),
  below('Di bawah rata-rata', '0,5 sampai < 0,9 × porsi adil'),
  attention('Perlu perhatian', '< 0,5 × porsi adil');

  const ContributionLabel(this.label, this.rule);
  final String label;
  final String rule;

  static ContributionLabel of(Contribution c) {
    if (c.needsAttention) return attention;
    final r = c.ratioToFairShare;
    if (r >= 1.25) return high;
    if (r >= 0.9) return balanced;
    if (r >= 0.5) return below;
    return attention;
  }
}

/// "14,3%" dengan koma desimal.
String pct(double value, {int digits = 1}) =>
    '${value.toStringAsFixed(digits).replaceAll('.', ',')}%';
