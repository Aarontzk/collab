/// Satu baris hasil RPC `contribution_scores(gid)` di supabase/schema.sql.
class ContributionScore {
  const ContributionScore({
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

  /// Porsi kontribusi 0ΓÇô100.
  final double contributionPct;

  /// Porsi adil 100 / jumlah anggota.
  final double fairSharePct;
  final bool needsAttention;

  factory ContributionScore.fromJson(Map<String, dynamic> json) =>
      ContributionScore(
        userId: json['user_id'] as String,
        fullName: json['full_name'] as String? ?? 'Anggota',
        taskPoints: _double(json['task_points']),
        meetingsAttended: (json['meetings_attended'] as num?)?.toInt() ?? 0,
        peerAvg: _double(json['peer_avg']),
        validationsGiven: (json['validations_given'] as num?)?.toInt() ?? 0,
        contributionPct: _double(json['contribution_pct']),
        fairSharePct: _double(json['fair_share_pct']),
        needsAttention: json['needs_attention'] as bool? ?? false,
      );

  /// Ada data yang bisa dihitung, bukan sekadar porsi rata-rata bawaan.
  bool get hasActivity =>
      taskPoints > 0 ||
      meetingsAttended > 0 ||
      validationsGiven > 0 ||
      (peerAvg - 3).abs() > 0.001;

  static double _double(Object? value) =>
      value is num ? value.toDouble() : 0;
}
