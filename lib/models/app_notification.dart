import 'package:collab/models/group.dart';
import 'package:collab/models/task.dart';

/// Kapan pengingat deadline dikirim, relatif terhadap deadline.
enum ReminderLead {
  dayBefore('day', Duration(days: 1), 'H-1', '1 hari lagi'),
  threeHours('3h', Duration(hours: 3), '3 jam sebelumnya', '3 jam lagi'),
  oneHour('1h', Duration(hours: 1), '1 jam sebelumnya', '1 jam lagi');

  const ReminderLead(this.key, this.before, this.label, this.remaining);

  final String key;
  final Duration before;
  final String label;

  /// Dipakai di isi notifikasi: "Deadline 3 jam lagi".
  final String remaining;
}

/// Pilihan notifikasi milik user. Disimpan lokal di HP.
class ReminderPrefs {
  const ReminderPrefs({
    this.deadlineOn = true,
    this.leads = const {ReminderLead.dayBefore, ReminderLead.oneHour},
    this.statusOn = true,
  });

  /// Pengingat deadline tugas saya.
  final bool deadlineOn;
  final Set<ReminderLead> leads;

  /// Kabar tugas saya disetujui atau ditolak.
  final bool statusOn;

  ReminderPrefs copyWith({
    bool? deadlineOn,
    Set<ReminderLead>? leads,
    bool? statusOn,
  }) => ReminderPrefs(
    deadlineOn: deadlineOn ?? this.deadlineOn,
    leads: leads ?? this.leads,
    statusOn: statusOn ?? this.statusOn,
  );

  ReminderPrefs toggleLead(ReminderLead lead) => copyWith(
    leads: leads.contains(lead) ? ({...leads}..remove(lead)) : {...leads, lead},
  );

  List<String> get leadKeys => [
    for (final l in ReminderLead.values)
      if (leads.contains(l)) l.key,
  ];

  static Set<ReminderLead> leadsFromKeys(Iterable<String> keys) => {
    for (final l in ReminderLead.values)
      if (keys.contains(l.key)) l,
  };
}

enum NotificationKind { deadlineSoon, overdue, rejected, approved }

/// Satu baris di pusat notifikasi.
class AppNotification {
  const AppNotification({
    required this.kind,
    required this.task,
    required this.group,
    required this.time,
  });

  final NotificationKind kind;
  final Task task;
  final Group group;

  /// Waktu kejadian, dipakai untuk urutan dan grup "Hari ini".
  final DateTime time;

  String get title => switch (kind) {
    NotificationKind.deadlineSoon => 'Deadline sebentar lagi',
    NotificationKind.overdue => 'Deadline terlewat',
    NotificationKind.rejected => 'Tugas ditolak',
    NotificationKind.approved => 'Tugas disetujui',
  };

  String get body => '${task.title} di ${group.name}';
}

/// Notifikasi lokal yang dijadwalkan di HP.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;
}

/// Tugas saya yang masih perlu dikerjakan (belum disetujui, belum menunggu validasi).
bool _isOpenFor(Task t, String myUserId) =>
    t.assigneeId == myUserId &&
    t.status != TaskStatus.approved &&
    t.status != TaskStatus.submitted;

/// Isi pusat notifikasi, terbaru di atas. Fungsi murni supaya mudah dites.
List<AppNotification> buildNotificationFeed({
  required String myUserId,
  required List<Group> groups,
  required List<Task> tasks,
  required DateTime now,
}) {
  const soon = Duration(hours: 24);
  const keep = Duration(days: 7);
  final groupById = {for (final g in groups) g.id: g};
  final items = <AppNotification>[];

  for (final t in tasks) {
    final group = groupById[t.groupId];
    if (group == null || t.assigneeId != myUserId) continue;
    final due = t.deadline;

    if (t.status == TaskStatus.approved) {
      final at = t.approvedAt;
      if (at != null && now.difference(at) <= keep) {
        items.add(_item(NotificationKind.approved, t, group, at));
      }
      continue;
    }
    if (t.status == TaskStatus.rejected) {
      items.add(
        _item(NotificationKind.rejected, t, group, t.submittedAt ?? now),
      );
    }
    if (!_isOpenFor(t, myUserId) || due == null) continue;
    if (due.isBefore(now)) {
      // Tetap tampil selama belum dikumpulkan, setelat apa pun.
      items.add(_item(NotificationKind.overdue, t, group, due));
    } else if (due.difference(now) <= soon) {
      items.add(_item(NotificationKind.deadlineSoon, t, group, now));
    }
  }

  items.sort((a, b) => b.time.compareTo(a.time));
  return items;
}

AppNotification _item(
  NotificationKind kind,
  Task task,
  Group group,
  DateTime time,
) => AppNotification(kind: kind, task: task, group: group, time: time);

/// Pengingat deadline yang perlu dijadwalkan dari sekarang.
List<PlannedReminder> planDeadlineReminders({
  required String myUserId,
  required List<Group> groups,
  required List<Task> tasks,
  required ReminderPrefs prefs,
  required DateTime now,
}) {
  if (!prefs.deadlineOn) return const [];
  final groupById = {for (final g in groups) g.id: g};
  final planned = <PlannedReminder>[];
  for (final t in tasks) {
    final due = t.deadline;
    final group = groupById[t.groupId];
    if (due == null || group == null || !_isOpenFor(t, myUserId)) continue;
    for (final lead in ReminderLead.values) {
      if (!prefs.leads.contains(lead)) continue;
      final at = due.subtract(lead.before);
      if (!at.isAfter(now)) continue;
      planned.add(
        PlannedReminder(
          id: planned.length + 1,
          at: at,
          title: 'Deadline ${lead.remaining}: ${t.title}',
          body: group.name,
        ),
      );
    }
  }
  return planned;
}

/// Kunci "taskId:status" untuk tugas saya yang disetujui/ditolak.
/// Dibandingkan dengan yang sudah pernah dilihat untuk mendeteksi kabar baru.
Set<String> statusKeys(String myUserId, List<Task> tasks) => {
  for (final t in tasks)
    if (t.assigneeId == myUserId &&
        (t.status == TaskStatus.approved || t.status == TaskStatus.rejected))
      '${t.id}:${t.status.dbValue}',
};

bool isSameDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}
