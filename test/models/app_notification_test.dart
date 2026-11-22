import 'package:flutter_test/flutter_test.dart';
import 'package:collab/models/app_notification.dart';
import 'package:collab/models/group.dart';
import 'package:collab/models/task.dart';

const _g = Group(
  id: 'g1',
  name: 'Kelompok 15',
  inviteCode: 'ABC123',
  lecturerCode: 'DSN123',
  myRole: MemberRole.member,
);

Task _task(
  String id, {
  TaskStatus status = TaskStatus.todo,
  String? assignee = 'me',
  DateTime? deadline,
  DateTime? submittedAt,
  DateTime? approvedAt,
}) => Task(
  id: id,
  groupId: 'g1',
  title: 'Tugas $id',
  weight: TaskWeight.medium,
  status: status,
  assigneeId: assignee,
  deadline: deadline,
  submittedAt: submittedAt,
  approvedAt: approvedAt,
);

void main() {
  final now = DateTime(2026, 11, 10, 8);

  List<AppNotification> feed(List<Task> tasks) => buildNotificationFeed(
    myUserId: 'me',
    groups: const [_g],
    tasks: tasks,
    now: now,
  );

  group('buildNotificationFeed', () {
    test('deadline dalam 24 jam dan yang terlewat masuk', () {
      final items = feed([
        _task('soon', deadline: now.add(const Duration(hours: 5))),
        _task('late', deadline: now.subtract(const Duration(days: 1))),
        _task('far', deadline: now.add(const Duration(days: 3))),
        _task('veryLate', deadline: now.subtract(const Duration(days: 8))),
      ]);
      expect(items.map((n) => (n.task.id, n.kind)), [
        ('soon', NotificationKind.deadlineSoon),
        ('late', NotificationKind.overdue),
        ('veryLate', NotificationKind.overdue),
      ]);
    });

    test('tugas orang lain dan yang menunggu validasi diabaikan', () {
      final items = feed([
        _task(
          'x',
          assignee: 'other',
          deadline: now.add(const Duration(hours: 1)),
        ),
        _task(
          'y',
          status: TaskStatus.submitted,
          deadline: now.add(const Duration(hours: 1)),
        ),
      ]);
      expect(items, isEmpty);
    });

    test('disetujui baru-baru ini dan ditolak ikut tampil', () {
      final items = feed([
        _task(
          'ok',
          status: TaskStatus.approved,
          approvedAt: now.subtract(const Duration(hours: 2)),
        ),
        _task(
          'old',
          status: TaskStatus.approved,
          approvedAt: now.subtract(const Duration(days: 30)),
        ),
        _task(
          'no',
          status: TaskStatus.rejected,
          submittedAt: now.subtract(const Duration(days: 2)),
        ),
      ]);
      expect(items.map((n) => (n.task.id, n.kind)), [
        ('ok', NotificationKind.approved),
        ('no', NotificationKind.rejected),
      ]);
      expect(items.first.body, 'Tugas ok di Kelompok 15');
    });
  });

  group('planDeadlineReminders', () {
    List<PlannedReminder> plan(List<Task> tasks, ReminderPrefs prefs) =>
        planDeadlineReminders(
          myUserId: 'me',
          groups: const [_g],
          tasks: tasks,
          prefs: prefs,
          now: now,
        );

    test('hanya jadwal yang masih di masa depan', () {
      final due = now.add(const Duration(hours: 2));
      final planned = plan(
        [_task('a', deadline: due)],
        const ReminderPrefs(
          leads: {ReminderLead.dayBefore, ReminderLead.oneHour},
        ),
      );
      expect(planned, hasLength(1));
      expect(planned.single.at, due.subtract(const Duration(hours: 1)));
      expect(planned.single.title, 'Deadline 1 jam lagi: Tugas a');
      expect(planned.single.body, 'Kelompok 15');
    });

    test('mati kalau pengingat deadline dimatikan', () {
      final planned = plan([
        _task('a', deadline: now.add(const Duration(days: 3))),
      ], const ReminderPrefs(deadlineOn: false));
      expect(planned, isEmpty);
    });

    test('id unik per pengingat', () {
      final planned = plan([
        _task('a', deadline: now.add(const Duration(days: 3))),
        _task('b', deadline: now.add(const Duration(days: 4))),
      ], const ReminderPrefs(leads: {...ReminderLead.values}));
      expect(planned.map((r) => r.id).toSet(), hasLength(6));
    });
  });

  test('toggleLead dan simpan/baca kunci', () {
    const prefs = ReminderPrefs(leads: {ReminderLead.oneHour});
    final next = prefs.toggleLead(ReminderLead.dayBefore);
    expect(next.leads, {ReminderLead.oneHour, ReminderLead.dayBefore});
    expect(prefs.leads, {ReminderLead.oneHour}); // tidak diubah
    expect(ReminderPrefs.leadsFromKeys(next.leadKeys), next.leads);
  });

  test('statusKeys hanya tugas saya yang disetujui atau ditolak', () {
    final keys = statusKeys('me', [
      _task('a', status: TaskStatus.approved),
      _task('b', status: TaskStatus.rejected),
      _task('c'),
      _task('d', status: TaskStatus.approved, assignee: 'other'),
    ]);
    expect(keys, {'a:approved', 'b:rejected'});
  });
}
