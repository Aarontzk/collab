import 'package:flutter/material.dart';

import 'package:collab/widgets/common_widgets.dart';
import 'package:collab/screens/notification_permission_screen.dart';
import 'package:collab/screens/notifications_screen.dart';
import 'package:collab/screens/settings_screen.dart';
import 'package:collab/models/group.dart';
import 'package:collab/models/profile.dart';
import 'package:collab/screens/profile_screen.dart';
import 'package:collab/services/profile_service.dart';
import 'package:collab/widgets/member_avatar.dart';
import 'package:collab/models/home_summary.dart';
import 'package:collab/services/home_service.dart';
import 'package:collab/utils/dates.dart';
import 'package:collab/widgets/collab_ui.dart';
import 'package:collab/utils/theme.dart';
import 'package:collab/widgets/group_dialogs.dart';
import 'package:collab/screens/group_home_screen.dart';
import 'package:collab/services/group_service.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _repo = GroupService();
  final _home = HomeService();
  late Future<HomeSummary> _summary = _home.fetchSummary();
  final _profiles = ProfileService();
  late Future<Profile> _me = _profiles.fetchMine();

  @override
  void initState() {
    super.initState();
    // Ajak izinkan notifikasi sekali, setelah beranda tampil.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) NotificationPermissionScreen.maybeShow(context);
    });
  }

  Future<void> _openProfile() => _openAccountPage(const ProfileScreen());

  Future<void> _openSettings() => _openAccountPage(const SettingsScreen());

  /// Profil/Pengaturan mengembalikan `true` kalau nama atau foto berubah.
  Future<void> _openAccountPage(Widget page) async {
    final changed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => page));
    if (changed == true && mounted) {
      setState(() => _me = _profiles.fetchMine());
    }
  }

  /// null = semua peran.
  MemberRole? _roleFilter;

  void _reload() => setState(() => _summary = _home.fetchSummary());

  Future<void> _openGroup(Group group, {int tab = 0}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupHomeScreen(group: group, initialTab: tab),
      ),
    );
    _reload(); // bisa saja user keluar dari kelompok
  }

  Future<void> _create() async {
    final group = await showCreateGroupDialog(context, _repo);
    if (group == null || !mounted) return;
    _reload();
    await _openGroup(group);
  }

  Future<void> _join() async {
    final joined = await showJoinGroupDialog(context, _repo);
    if (joined && mounted) {
      showMessage(context, 'Berhasil bergabung!');
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelompokku'),
        actions: [
          IconButton(
            tooltip: 'Notifikasi',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsScreen(),
                ),
              );
              _reload();
            },
          ),
          FutureBuilder<Profile>(
            future: _me,
            builder: (context, snapshot) {
              final me = snapshot.data;
              return IconButton(
                tooltip: 'Profil',
                onPressed: _openProfile,
                icon: me == null
                    ? const Icon(Icons.account_circle_outlined)
                    : MemberAvatar(
                        name: me.fullName,
                        avatarUrl: me.avatarUrl,
                        radius: 16,
                      ),
              );
            },
          ),
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Kelompok'),
      ),
      body: DecoBackground(
        child: AsyncView<HomeSummary>(
          future: _summary,
          onRetry: _reload,
          builder: (context, summary) {
            if (summary.groups.isEmpty) {
              return _EmptyGroups(onCreate: _create, onJoin: _join);
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                children: _homeChildren(context, summary),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _add() async {
    final action = await showAddGroupSheet(context);
    if (!mounted || action == null) return;
    action == AddGroupAction.create ? await _create() : await _join();
  }

  static const _roleLabels = {
    null: 'Semua peran',
    MemberRole.leader: 'Ketua',
    MemberRole.member: 'Anggota',
    MemberRole.lecturer: 'Dosen',
  };

  List<Widget> _homeChildren(BuildContext context, HomeSummary s) {
    final groups = s.groups
        .where((o) => _roleFilter == null || o.group.myRole == _roleFilter)
        .toList();
    return [
      if (s.upcoming.isNotEmpty) ...[
        SectionHeader(
          'Tenggat terdekat',
          trailing: Pill(
            '${s.upcoming.length} tugas',
            foreground: ItsColors.inkMuted,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 134,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            itemCount: s.upcoming.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _DeadlineCard(
              item: s.upcoming[i],
              onTap: () => _openGroup(s.upcoming[i].group),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      SectionHeader(
        'Kelompokmu',
        trailing: DropdownPill<MemberRole?>(
          label: _roleLabels[_roleFilter]!,
          items: [for (final e in _roleLabels.entries) (e.key, e.value)],
          onSelected: (role) => setState(() => _roleFilter = role),
        ),
      ),
      for (final o in groups) ...[
        const SizedBox(height: 12),
        _GroupCard(overview: o, onTap: () => _openGroup(o.group)),
      ],
    ];
  }
}

/// Kartu carousel "Tenggat terdekat".
class _DeadlineCard extends StatelessWidget {
  const _DeadlineCard({required this.item, required this.onTap});

  final UpcomingTask item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final task = item.task;
    final due = task.deadline!;
    final left = due.difference(DateTime.now());
    final late = left.isNegative;
    final urgent = left < const Duration(hours: 24);
    final dueColor = urgent ? CColors.error : ItsColors.ink;
    final dueText = late
        ? 'Telat ${-left.inDays < 1 ? 'hari ini' : '${-left.inDays} hari'}'
        : formatDayTime(due);
    return SizedBox(
      width: 228,
      child: Material(
        color: CColors.carousel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          foregroundPainter: const GradientBorderPainter(radius: 28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.group.name,
                    style: CText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    task.title,
                    style: CText.cardTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      StatusPill(task.status),
                      const Spacer(),
                      IconLabel(
                        icon: late ? Icons.error_outline : Icons.schedule,
                        label: dueText,
                        style: CText.chip,
                        color: dueColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu kelompok: avatar huruf, nama, mata kuliah, peran, progres.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.overview, required this.onTap});

  final GroupOverview overview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = overview.group;
    final course = g.courseName;
    return ElevatedPanel(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LetterAvatar(g.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.name,
                      style: CText.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (course != null && course.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        course,
                        style: CText.label.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              RolePill(g.myRole),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text('Progres tugas', style: CText.label)),
              Text('${overview.progressPct}%', style: CText.percent),
            ],
          ),
          const SizedBox(height: 8),
          ThinProgress(overview.progressPct / 100),
        ],
      ),
    );
  }
}

/// Belum punya kelompok (Figma Farel F2).
class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups({required this.onCreate, required this.onJoin});

  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: SizedBox(
                width: 168,
                height: 168,
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: ItsColors.blueContainer,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.group_add,
                        size: 64,
                        color: ItsColors.blue,
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 12,
                      child: _dot(ItsColors.yellow),
                    ),
                    Positioned(
                      right: 0,
                      top: 40,
                      child: _dot(ItsColors.lightBlue),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Belum ada kelompok',
              textAlign: TextAlign.center,
              style: CText.stat.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat kelompok baru sebagai ketua, atau gabung pakai kode dari '
              'ketua kelompokmu.',
              textAlign: TextAlign.center,
              style: CText.meta,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Buat kelompok'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onJoin,
              icon: const Icon(Icons.vpn_key_outlined),
              label: const Text('Gabung pakai kode'),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _dot(Color c) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}
