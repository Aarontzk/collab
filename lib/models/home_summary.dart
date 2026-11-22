import 'package:collab/models/group.dart';
import 'package:collab/models/task.dart';

/// Ringkasan satu kelompok untuk kartu di beranda.
class GroupOverview {
  const GroupOverview({
    required this.group,
    required this.totalTasks,
    required this.approvedTasks,
    this.nextDeadline,
  });

  final Group group;
  final int totalTasks;
  final int approvedTasks;

  /// Tugas belum disetujui dengan deadline paling awal, termasuk yang telat.
  final Task? nextDeadline;

  /// 0..100, dibulatkan.
  int get progressPct =>
      totalTasks == 0 ? 0 : (approvedTasks * 100 / totalTasks).round();
}

/// Tugas saya yang deadline-nya dekat, beserta kelompoknya.
class UpcomingTask {
  const UpcomingTask({required this.task, required this.group});
  final Task task;
  final Group group;
}

/// Data halaman Kelompokku (beranda).
class HomeSummary {
  const HomeSummary({required this.groups, required this.upcoming});

  final List<GroupOverview> groups;

  /// Tugas saya yang belum disetujui: yang telat dulu, lalu yang deadline-nya
  /// dalam 7 hari ke depan.
  final List<UpcomingTask> upcoming;

  static const upcomingWindow = Duration(days: 7);

  /// Hitung ringkasan dari data mentah. Fungsi murni supaya mudah dites.
  factory HomeSummary.compute({
    required String myUserId,
    required List<Group> groups,
    required List<Task> tasks,
    required DateTime now,
  }) {
    final byGroup = <String, List<Task>>{};
    for (final t in tasks) {
      (byGroup[t.groupId] ??= []).add(t);
    }
    final groupById = {for (final g in groups) g.id: g};

    final overviews = [
      for (final g in groups) _overview(g, byGroup[g.id] ?? const [], now),
    ];

    final mine = tasks
        .where((t) => t.assigneeId == myUserId)
        .where((t) => t.status != TaskStatus.approved)
        .toList();
    final limit = now.add(upcomingWindow);
    final upcoming = mine.where((t) {
      final due = t.deadline;
      // Yang sudah telat tetap ikut (paling atas) supaya tidak hilang.
      return due != null && due.isBefore(limit);
    }).toList()..sort((a, b) => a.deadline!.compareTo(b.deadline!));

    return HomeSummary(
      groups: overviews,
      upcoming: [
        for (final t in upcoming)
          if (groupById[t.groupId] case final g?)
            UpcomingTask(task: t, group: g),
      ],
    );
  }

  static GroupOverview _overview(Group g, List<Task> tasks, DateTime now) {
    final open =
        tasks
            .where((t) => t.status != TaskStatus.approved)
            .where((t) => t.deadline != null)
            .toList()
          ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
    return GroupOverview(
      group: g,
      totalTasks: tasks.length,
      approvedTasks: tasks.where((t) => t.status == TaskStatus.approved).length,
      nextDeadline: open.isEmpty ? null : open.first,
    );
  }
}
