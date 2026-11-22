import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:collab/models/app_notification.dart';
import 'package:collab/models/group.dart';
import 'package:collab/models/task.dart';

/// Pilihan notifikasi disimpan di HP (SharedPreferences).
class ReminderPrefsStore {
  static const _deadlineOn = 'notif.deadline_on';
  static const _leads = 'notif.leads';
  static const _statusOn = 'notif.status_on';
  static const _asked = 'notif.permission_asked';
  static const _seen = 'notif.seen_status';

  Future<ReminderPrefs> load() async {
    final p = await SharedPreferences.getInstance();
    const fallback = ReminderPrefs();
    final keys = p.getStringList(_leads);
    return ReminderPrefs(
      deadlineOn: p.getBool(_deadlineOn) ?? fallback.deadlineOn,
      leads: keys == null ? fallback.leads : ReminderPrefs.leadsFromKeys(keys),
      statusOn: p.getBool(_statusOn) ?? fallback.statusOn,
    );
  }

  Future<void> save(ReminderPrefs prefs) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_deadlineOn, prefs.deadlineOn);
    await p.setStringList(_leads, prefs.leadKeys);
    await p.setBool(_statusOn, prefs.statusOn);
  }

  /// Layar izin notifikasi cukup ditampilkan sekali.
  Future<bool> wasPermissionAsked() async =>
      (await SharedPreferences.getInstance()).getBool(_asked) ?? false;

  Future<void> markPermissionAsked() async =>
      (await SharedPreferences.getInstance()).setBool(_asked, true);

  /// null = belum pernah sinkron (jangan kirim kabar lama sekaligus).
  Future<Set<String>?> seenStatus() async =>
      (await SharedPreferences.getInstance()).getStringList(_seen)?.toSet();

  Future<void> saveSeenStatus(Set<String> keys) async =>
      (await SharedPreferences.getInstance()).setStringList(
        _seen,
        keys.toList(),
      );
}

/// Notifikasi lokal: pengingat deadline dan kabar status tugas.
/// Semua method aman dipanggil di platform yang tidak didukung (jadi no-op).
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final store = ReminderPrefsStore();
  Future<bool>? _ready;

  static const _channel = AndroidNotificationDetails(
    'collab_reminders',
    'Pengingat tugas',
    channelDescription: 'Pengingat deadline dan kabar status tugas',
    importance: Importance.high,
    priority: Priority.high,
    // Tetap tampil di layar kunci.
    visibility: NotificationVisibility.public,
  );
  static const _details = NotificationDetails(android: _channel);

  /// Id di atas ini untuk kabar status, di bawahnya untuk pengingat terjadwal.
  static const _statusIdBase = 100000;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<bool> _init() => _ready ??= _doInit();

  Future<bool> _doInit() async {
    if (!_supported) return false;
    try {
      tzdata.initializeTimeZones();
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Notifikasi gagal disiapkan: $e');
      return false;
    }
  }

  Future<bool> isEnabled() async {
    if (!await _init()) return false;
    return await _android?.areNotificationsEnabled() ?? false;
  }

  /// Minta izin ke sistem (Android 13+). Mengembalikan status akhirnya.
  Future<bool> requestPermission() async {
    await store.markPermissionAsked();
    if (!await _init()) return false;
    return await _android?.requestNotificationsPermission() ?? false;
  }

  /// Jadwalkan ulang semua pengingat dan kirim kabar status yang baru.
  /// Dipanggil setiap data beranda dimuat. Error hanya dicatat.
  Future<void> sync({
    required String myUserId,
    required List<Group> groups,
    required List<Task> tasks,
  }) async {
    try {
      if (!await _init()) return;
      final prefs = await store.load();
      await _scheduleDeadlines(myUserId, groups, tasks, prefs);
      await _announceStatus(myUserId, groups, tasks, prefs);
    } catch (e) {
      debugPrint('Sinkron notifikasi gagal: $e');
    }
  }

  Future<void> _scheduleDeadlines(
    String myUserId,
    List<Group> groups,
    List<Task> tasks,
    ReminderPrefs prefs,
  ) async {
    await _plugin.cancelAllPendingNotifications();
    final planned = planDeadlineReminders(
      myUserId: myUserId,
      groups: groups,
      tasks: tasks,
      prefs: prefs,
      now: DateTime.now(),
    );
    for (final r in planned) {
      await _plugin.zonedSchedule(
        id: r.id,
        scheduledDate: tz.TZDateTime.from(r.at, tz.local),
        notificationDetails: _details,
        // Tidak perlu izin alarm presisi; telat beberapa menit tidak masalah.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
      );
    }
  }

  Future<void> _announceStatus(
    String myUserId,
    List<Group> groups,
    List<Task> tasks,
    ReminderPrefs prefs,
  ) async {
    final current = statusKeys(myUserId, tasks);
    final seen = await store.seenStatus();
    await store.saveSeenStatus(current);
    if (seen == null || !prefs.statusOn) return;

    final groupName = {for (final g in groups) g.id: g.name};
    var n = 0;
    for (final t in tasks) {
      final key = '${t.id}:${t.status.dbValue}';
      if (!current.contains(key) || seen.contains(key)) continue;
      final approved = t.status == TaskStatus.approved;
      await _plugin.show(
        id: _statusIdBase + n++,
        title: approved ? 'Tugas disetujui' : 'Tugas ditolak, perlu revisi',
        body: [
          t.title,
          if (groupName[t.groupId] case final g?) 'di $g',
        ].join(' '),
        notificationDetails: _details,
      );
    }
  }
}
