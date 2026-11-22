import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/models/app_notification.dart';
import 'package:collab/models/group.dart';
import 'package:collab/models/task.dart';
import 'package:collab/screens/reminder_settings_screen.dart';
import 'package:collab/screens/notifications_screen.dart';
import 'package:collab/utils/theme.dart';

const _g = Group(
  id: 'g1',
  name: 'Kelompok 15',
  inviteCode: 'ABC123',
  lecturerCode: 'DSN123',
  myRole: MemberRole.member,
);

Task _task(String id) => Task(
  id: id,
  groupId: 'g1',
  title: 'Tugas $id',
  weight: TaskWeight.medium,
  status: TaskStatus.todo,
);

Widget _app(Widget body) => MaterialApp(
  theme: collabTheme,
  home: Scaffold(body: body),
);

void main() {
  final now = DateTime(2026, 11, 10, 15);

  testWidgets('notifikasi dikelompokkan Hari ini dan Sebelumnya', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        NotificationsView(
          now: now,
          items: [
            AppNotification(
              kind: NotificationKind.deadlineSoon,
              task: _task('a'),
              group: _g,
              time: DateTime(2026, 11, 10, 9, 5),
            ),
            AppNotification(
              kind: NotificationKind.rejected,
              task: _task('b'),
              group: _g,
              time: DateTime(2026, 11, 8, 20),
            ),
          ],
        ),
      ),
    );
    expect(find.text('Hari ini'), findsOneWidget);
    expect(find.text('Sebelumnya'), findsOneWidget);
    expect(find.text('Deadline sebentar lagi'), findsOneWidget);
    expect(find.text('Tugas ditolak'), findsOneWidget);
    expect(find.text('09:05'), findsOneWidget);
  });

  testWidgets('kosong menampilkan pesan', (tester) async {
    await tester.pumpWidget(_app(NotificationsView(now: now, items: const [])));
    expect(find.textContaining('Belum ada notifikasi'), findsOneWidget);
  });

  testWidgets('pengaturan pengingat mengubah pilihan', (tester) async {
    var prefs = const ReminderPrefs(leads: {ReminderLead.oneHour});
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _app(
          ReminderSettingsView(
            prefs: prefs,
            onChanged: (p) => setState(() => prefs = p),
          ),
        ),
      ),
    );
    await tester.tap(find.text('H-1'));
    await tester.pump();
    expect(prefs.leads, {ReminderLead.oneHour, ReminderLead.dayBefore});

    await tester.tap(find.text('Pengingat deadline'));
    await tester.pump();
    expect(prefs.deadlineOn, isFalse);
    // Pilihan waktu dinonaktifkan saat pengingat mati.
    await tester.tap(find.text('3 jam sebelumnya'));
    await tester.pump();
    expect(prefs.leads, {ReminderLead.oneHour, ReminderLead.dayBefore});
  });
}
