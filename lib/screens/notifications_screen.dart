import 'package:flutter/material.dart';

import 'package:collab/models/app_notification.dart';
import 'package:collab/models/group.dart';
import 'package:collab/screens/group_home_screen.dart';
import 'package:collab/screens/reminder_settings_screen.dart';
import 'package:collab/services/home_service.dart';
import 'package:collab/utils/dates.dart';
import 'package:collab/utils/theme.dart';
import 'package:collab/widgets/collab_ui.dart';
import 'package:collab/widgets/common_widgets.dart';
import 'package:collab/widgets/home_cards.dart';

/// Pusat notifikasi (N1): kabar tugas saya, dikelompokkan per hari.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _home = HomeService();
  late Future<List<AppNotification>> _feed = _load();

  Future<List<AppNotification>> _load() async {
    final work = await _home.fetchMyWork();
    return buildNotificationFeed(
      myUserId: _home.myUserId,
      groups: work.groups,
      tasks: work.tasks,
      now: DateTime.now(),
    );
  }

  void _reload() => setState(() => _feed = _load());

  Future<void> _openGroup(Group group) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupHomeScreen(group: group, initialTab: 0),
      ),
    );
    _reload();
  }

  void _openSettings() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ReminderSettingsScreen()),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          IconButton(
            tooltip: 'Pengaturan notifikasi',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: AsyncView<List<AppNotification>>(
        future: _feed,
        onRetry: _reload,
        builder: (context, items) => RefreshIndicator(
          onRefresh: () async => _reload(),
          child: NotificationsView(
            items: items,
            now: DateTime.now(),
            onTap: (n) => _openGroup(n.group),
            onOpenSettings: _openSettings,
          ),
        ),
      ),
    );
  }
}

/// Daftar notifikasi tanpa Supabase, supaya bisa dites.
class NotificationsView extends StatelessWidget {
  const NotificationsView({
    super.key,
    required this.items,
    required this.now,
    this.onTap,
    this.onOpenSettings,
  });

  final List<AppNotification> items;
  final DateTime now;
  final ValueChanged<AppNotification>? onTap;

  /// Tombol di empty state, membuka pengaturan pengingat.
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          MessageView(
            icon: Icons.notifications_outlined,
            message:
                'Belum ada notifikasi.\nKabar tugasmu akan muncul di sini.',
            actionLabel: 'Atur pengingat',
            onAction: onOpenSettings,
          ),
        ],
      );
    }
    final today = items.where((n) => isSameDay(n.time, now)).toList();
    final earlier = items.where((n) => !isSameDay(n.time, now)).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (today.isNotEmpty) ...[
          const SectionTitle('Hari ini'),
          for (final n in today) _tile(context, n),
        ],
        if (earlier.isNotEmpty) ...[
          const SectionTitle('Sebelumnya'),
          for (final n in earlier) _tile(context, n),
        ],
      ],
    );
  }

  Widget _tile(BuildContext context, AppNotification n) {
    final (icon, bg, color) = switch (n.kind) {
      NotificationKind.deadlineSoon => (
        Icons.schedule,
        ItsColors.blueContainer,
        CColors.icon,
      ),
      NotificationKind.overdue => (
        Icons.error_outline,
        CColors.errorContainer,
        CColors.error,
      ),
      NotificationKind.rejected => (
        Icons.cancel_outlined,
        CColors.errorContainer,
        CColors.error,
      ),
      NotificationKind.approved => (
        Icons.check,
        CColors.successContainer,
        CColors.success,
      ),
    };
    final when = isSameDay(n.time, now)
        ? formatTime(n.time)
        : formatDeadlineShort(n.time, now);
    return ListTile(
      leading: IconBadge(icon, background: bg, color: color),
      title: Text(n.title),
      subtitle: Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(when, style: HomeText.supporting),
      onTap: onTap == null ? null : () => onTap!(n),
    );
  }
}
