import 'package:flutter/material.dart';

import 'package:collab/models/contribution.dart';
import 'package:collab/models/group.dart';
import 'package:collab/models/task.dart';
import 'package:collab/utils/contribution_math.dart';
import 'package:collab/utils/theme.dart';
import 'package:collab/widgets/collab_ui.dart';
import 'package:collab/widgets/contribution_chart.dart';
import 'package:collab/widgets/contribution_nav_bar.dart';
import 'package:collab/widgets/home_cards.dart';
import 'package:collab/widgets/member_avatar.dart';

/// Detail kontribusi satu anggota: skor, rincian perhitungan, dan tugas
/// yang dihitung.
class DetailKontribusiAnggotaScreen extends StatelessWidget {
  const DetailKontribusiAnggotaScreen({
    super.key,
    required this.group,
    required this.scores,
    required this.score,
    this.tasks = const [],
    this.onTabSelected,
  });

  final Group group;

  /// Semua skor kelompok, untuk menghitung total tiap komponen.
  final List<ContributionScore> scores;
  final ContributionScore score;
  final List<Task> tasks;
  final ValueChanged<int>? onTabSelected;

  @override
  Widget build(BuildContext context) {
    final totals = ContributionTotals.of(scores);
    final parts = contributionPartsOf(score, totals);
    final maxScale = chartMaxFor(scores, totals.fairShare);
    final member =
        group.members.byId(score.userId) ??
        Member(userId: score.userId, fullName: score.fullName);

    double shareOf(double value, double total) {
      if (total > 0) return value / total * 100;
      if (totals.memberCount == 0) return 0;
      return 100 / totals.memberCount;
    }

    final taskRows = [
      for (final task in tasks)
        if (task.assigneeId == score.userId &&
            (task.status == TaskStatus.approved ||
                task.status == TaskStatus.rejected))
          task,
    ]..sort((a, b) {
        final rankA = a.status == TaskStatus.approved ? 0 : 1;
        final rankB = b.status == TaskStatus.approved ? 0 : 1;
        if (rankA != rankB) return rankA - rankB;
        final dateA = a.approvedAt ?? a.submittedAt;
        final dateB = b.approvedAt ?? b.submittedAt;
        if (dateA != null && dateB != null) return dateA.compareTo(dateB);
        return a.title.compareTo(b.title);
      });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('Detail kontribusi'),
        titleTextStyle: HomeText.headline.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: ItsColors.blue,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _MemberCard(member: member),
          const SizedBox(height: 16),
          _ScoreCard(
            score: score,
            totals: totals,
            maxScale: maxScale,
          ),
          const SizedBox(height: 16),
          _BreakdownCard(
            score: score,
            totals: totals,
            parts: parts,
            shareOf: shareOf,
          ),
          const SizedBox(height: 16),
          _TasksCard(score: score, tasks: taskRows),
        ],
      ),
      bottomNavigationBar: ContributionNavBar(onSelected: onTabSelected),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final nrp = member.nrp?.trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ItsColors.border),
      ),
      child: Row(
        children: [
          MemberAvatar(
            name: member.fullName,
            avatarUrl: member.avatarUrl,
            radius: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ItsColors.ink,
                  ),
                ),
                if (nrp != null && nrp.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'NRP $nrp',
                    style: HomeText.meta.copyWith(fontSize: 12),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  member.role.label,
                  style: const TextStyle(
                    fontFamily: AppFonts.text,
                    fontSize: 13,
                    color: ItsColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.score,
    required this.totals,
    required this.maxScale,
  });

  final ContributionScore score;
  final ContributionTotals totals;
  final double maxScale;

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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skor kontribusi',
                      style: HomeText.supporting.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      percentText(score.contributionPct),
                      style: TextStyle(
                        fontFamily: AppFonts.text,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                        color: score.needsAttention
                            ? CColors.error
                            : ItsColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Porsi adil',
                    style: HomeText.supporting.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    percentText(totals.fairShare),
                    style: const TextStyle(
                      fontFamily: AppFonts.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: ItsColors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ContributionBarChart(
            scores: [score],
            totals: totals,
            scaleMax: maxScale,
            showNames: false,
            showValues: false,
            showFooter: true,
            showFairLabel: false,
            compact: true,
          ),
          if (score.needsAttention) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 17,
                  color: CColors.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Di bawah batas peringatan '
                    '${percentText(totals.warning)}. Kelompok melihat tanda '
                    'ini di daftar kontribusi.',
                    style: const TextStyle(
                      fontFamily: AppFonts.text,
                      fontSize: 12,
                      height: 1.45,
                      color: CColors.error,
                    ),
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

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.score,
    required this.totals,
    required this.parts,
    required this.shareOf,
  });

  final ContributionScore score;
  final ContributionTotals totals;
  final ContributionParts parts;
  final double Function(double value, double total) shareOf;

  @override
  Widget build(BuildContext context) {
    final taskShare = shareOf(score.taskPoints, totals.tasks);
    final attendanceShare = shareOf(
      score.meetingsAttended.toDouble(),
      totals.attendance,
    );
    final reviewShare = shareOf(score.peerAvg, totals.review);
    final validationShare = shareOf(
      score.validationsGiven.toDouble(),
      totals.validation,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ItsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Rincian perhitungan', style: HomeText.section),
          const SizedBox(height: 10),
          _ComponentRow(
            icon: Icons.checklist_rounded,
            title: 'Tugas (60%)',
            detail:
                '${decimalText(score.taskPoints, 1)} dari '
                '${decimalText(totals.tasks, 1)} poin',
            share: 'porsi ${percentText(taskShare)} × 60%',
            value: percentText(parts.tasks, decimals: 2),
          ),
          const Divider(height: 20, color: ItsColors.border),
          _ComponentRow(
            icon: Icons.groups_rounded,
            title: 'Kehadiran (15%)',
            detail:
                '${score.meetingsAttended} dari '
                '${totals.attendance.toInt()} kehadiran',
            share: 'porsi ${percentText(attendanceShare)} × 15%',
            value: percentText(parts.attendance, decimals: 2),
          ),
          const Divider(height: 20, color: ItsColors.border),
          _ComponentRow(
            icon: Icons.rate_review_outlined,
            title: 'Peer review (15%)',
            detail:
                'rata-rata ${decimalText(score.peerAvg, 1)} dari total '
                '${decimalText(totals.review, 1)}',
            share: 'porsi ${percentText(reviewShare)} × 15%',
            value: percentText(parts.review, decimals: 2),
          ),
          const Divider(height: 20, color: ItsColors.border),
          _ComponentRow(
            icon: Icons.check_circle_outline,
            title: 'Validasi (10%)',
            detail:
                '${score.validationsGiven} dari '
                '${totals.validation.toInt()} validasi',
            share: 'porsi ${percentText(validationShare)} × 10%',
            value: percentText(parts.validation, decimals: 2),
          ),
          const Divider(height: 20, color: ItsColors.border),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total skor',
                  style: TextStyle(
                    fontFamily: AppFonts.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ItsColors.ink,
                  ),
                ),
              ),
              Text(
                percentText(score.contributionPct),
                style: TextStyle(
                  fontFamily: AppFonts.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: score.needsAttention
                      ? CColors.error
                      : ItsColors.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.share,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String share;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 22, color: ItsColors.ink),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppFonts.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ItsColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(detail, style: HomeText.meta.copyWith(fontSize: 12)),
              Text(share, style: HomeText.meta.copyWith(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppFonts.text,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ItsColors.ink,
          ),
        ),
      ],
    );
  }
}

class _TasksCard extends StatelessWidget {
  const _TasksCard({required this.score, required this.tasks});

  final ContributionScore score;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ItsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tugas yang dihitung', style: HomeText.section),
          const SizedBox(height: 2),
          Text(
            'Hanya tugas berstatus Disetujui. Terlambat dikali 0,7.',
            style: HomeText.meta.copyWith(fontSize: 11.5),
          ),
          const SizedBox(height: 6),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Belum ada tugas yang disetujui atau ditolak.',
                style: HomeText.meta.copyWith(fontSize: 12),
              ),
            )
          else
            for (final task in tasks) _TaskRow(task: task),
          const Divider(height: 20, color: ItsColors.border),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total poin tugas',
                  style: TextStyle(
                    fontFamily: AppFonts.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ItsColors.ink,
                  ),
                ),
              ),
              Text(
                decimalText(score.taskPoints, 1),
                style: const TextStyle(
                  fontFamily: AppFonts.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ItsColors.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final approved = task.status == TaskStatus.approved;
    final late = isTaskLate(task);
    final points = taskPointsOf(task);
    final detail = approved
        ? '${task.weight.label} (${task.weight.points}), '
              '${late ? 'terlambat ×0,7' : 'tepat waktu'}'
        : '${task.weight.label} (${task.weight.points}), ditolak';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            approved ? Icons.check_circle : Icons.cancel,
            size: 21,
            color: ItsColors.ink,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: ItsColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(detail, style: HomeText.meta.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            approved ? '+${decimalText(points, 1)}' : '0',
            style: const TextStyle(
              fontFamily: AppFonts.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ItsColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
