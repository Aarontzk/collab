import 'package:flutter/material.dart';
import 'package:collab/widgets/member_avatar.dart';
import 'package:flutter/services.dart';

import 'package:collab/utils/theme.dart';
import 'package:collab/widgets/collab_ui.dart';
import 'package:collab/widgets/common_widgets.dart';
import 'package:collab/screens/detail_kontribusi_kelompok.dart';
import 'package:collab/screens/meetings_screen.dart';
import 'package:collab/screens/peer_review_screen.dart';
import 'package:collab/screens/task_board_screen.dart';
import 'package:collab/models/group.dart';
import 'package:collab/services/contribution_service.dart';
import 'package:collab/services/group_service.dart';
import 'package:collab/widgets/contribution_nav_bar.dart';
import 'package:collab/widgets/group_dialogs.dart';

/// Halaman utama satu kelompok: Tugas, Rapat, Review, Kontribusi.
class GroupHomeScreen extends StatefulWidget {
  const GroupHomeScreen({super.key, required this.group, this.initialTab = 0});
  final Group group;

  /// 0 Tugas, 1 Rapat, 2 Review, 3 Kontribusi.
  final int initialTab;

  @override
  State<GroupHomeScreen> createState() => _GroupHomeScreenState();
}

class _GroupHomeScreenState extends State<GroupHomeScreen> {
  final _repo = GroupService();
  late Future<List<Member>> _members = _repo.fetchMembers(widget.group.id);
  late int _tab = widget.initialTab;

  /// Bisa berubah kalau ketua mengedit nama/mata kuliah.
  late Group _group = widget.group;

  void _reloadMembers() =>
      setState(() => _members = _repo.fetchMembers(widget.group.id));

  void _selectTab(int i) {
    if (i != _tab) HapticFeedback.selectionClick();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    // Halaman Kontribusi (Maria) punya AppBar dan navigasi bawah sendiri.
    if (_tab == 3) {
      return _ContributionTab(group: group, onTabSelected: _selectTab);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          IconButton(
            tooltip: 'Info kelompok',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfo(context),
          ),
        ],
      ),
      body: AsyncView<List<Member>>(
        future: _members,
        onRetry: _reloadMembers,
        builder: (context, members) => IndexedStack(
          index: _tab,
          children: [
            TaskBoardScreen(group: group, members: members),
            MeetingsScreen(group: group, members: members),
            const PeerReviewScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _selectTab,
        destinations: [
          // Ikon garis yang sama dengan Collab/Ikon di Figma, aktif maupun tidak.
          _destination(Icons.checklist, 'Tugas'),
          _destination(Icons.groups_outlined, 'Rapat'),
          _destination(Icons.reviews_outlined, 'Review'),
          _destination(Icons.leaderboard_outlined, 'Kontribusi'),
        ],
      ),
    );
  }

  NavigationDestination _destination(IconData icon, String label) =>
      NavigationDestination(icon: Icon(icon), label: label);

  void _showInfo(BuildContext context) {
    final group = _group;
    showCollabSheet<void>(
      context,
      scrollable: true,
      builder: (sheetContext) => FutureBuilder<List<Member>>(
        future: _members,
        builder: (context, snapshot) => GroupInfoSheet(
          group: group,
          members: snapshot.data ?? const [],
          onLeave: group.amLeader ? null : () => _leave(sheetContext),
          onEdit: group.amLeader ? () => _edit(sheetContext) : null,
          onDelete: group.amLeader ? () => _delete(sheetContext) : null,
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext sheetContext) async {
    Navigator.pop(sheetContext);
    final updated = await showEditGroupScreen(context, _repo, _group);
    if (updated == null || !mounted) return;
    setState(() => _group = updated);
    showMessage(context, 'Kelompok diperbarui');
  }

  Future<void> _delete(BuildContext sheetContext) async {
    Navigator.pop(sheetContext);
    final ok = await showConfirmDialog(
      context,
      icon: Icons.delete_outline,
      title: 'Hapus kelompok?',
      message:
          'Kelompok "${_group.name}" beserta semua tugas, rapat, dan review '
          'akan dihapus untuk semua anggota. Ini tidak bisa dibatalkan.',
      confirmLabel: 'Hapus',
      danger: true,
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.deleteGroup(_group.id);
      if (!mounted) return;
      showMessage(context, 'Kelompok dihapus');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _leave(BuildContext sheetContext) async {
    Navigator.pop(sheetContext);
    try {
      await _repo.leaveGroup(_group.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }
}

/// Isi sheet Info kelompok (Figma Farel F7).
class GroupInfoSheet extends StatefulWidget {
  const GroupInfoSheet({
    super.key,
    required this.group,
    required this.members,
    this.onLeave,
    this.onEdit,
    this.onDelete,
  });

  final Group group;
  final List<Member> members;
  final VoidCallback? onLeave;

  /// Khusus ketua.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<GroupInfoSheet> createState() => _GroupInfoSheetState();
}

class _GroupInfoSheetState extends State<GroupInfoSheet> {
  MemberRole? _role;

  static const _labels = {
    null: 'Semua peran',
    MemberRole.leader: 'Ketua',
    MemberRole.member: 'Anggota',
    MemberRole.lecturer: 'Dosen',
  };

  /// Jumlah anggota dengan peran tertentu (null = semua).
  int _count(MemberRole? role) =>
      widget.members.where((m) => role == null || m.role == role).length;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final course = g.courseName;
    final shown = widget.members
        .where((m) => _role == null || m.role == _role)
        .toList();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: SheetHeader(
                    title: 'Info kelompok',
                    subtitle: course == null || course.isEmpty
                        ? g.name
                        : '${g.name} · $course',
                  ),
                ),
                if (widget.onEdit != null)
                  IconButton(
                    tooltip: 'Edit kelompok',
                    icon: const Icon(Icons.edit_outlined),
                    color: ItsColors.blue,
                    onPressed: widget.onEdit,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _CodeCard(label: 'Kode gabung anggota', code: g.inviteCode),
            if (g.amLeader) ...[
              const SizedBox(height: 16),
              _CodeCard(
                label: 'Kode untuk dosen',
                code: g.lecturerCode,
                secret: true,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Anggota',
                    style: CText.sectionStrong.copyWith(fontSize: 15),
                  ),
                ),
                DropdownPill<MemberRole?>(
                  label: '${_labels[_role]} · ${shown.length}',
                  // Tiap pilihan menampilkan jumlah anggotanya, seperti di Figma.
                  items: [
                    for (final e in _labels.entries)
                      (e.key, '${e.value} · ${_count(e.key)}'),
                  ],
                  onSelected: (r) => setState(() => _role = r),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final m in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    MemberAvatar(
                      name: m.fullName,
                      avatarUrl: m.avatarUrl,
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        m.fullName,
                        style: CText.body.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    RolePill(m.role),
                  ],
                ),
              ),
            if (widget.onLeave != null) ...[
              const SizedBox(height: 4),
              _DangerButton(
                icon: Icons.logout,
                label: 'Keluar dari kelompok',
                onTap: widget.onLeave!,
              ),
            ],
            if (widget.onDelete != null) ...[
              const SizedBox(height: 4),
              _DangerButton(
                icon: Icons.delete_outline,
                label: 'Hapus kelompok',
                onTap: widget.onDelete!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tombol merah lebar di bagian bawah sheet (keluar / hapus kelompok).
class _DangerButton extends StatelessWidget {
  const _DangerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const red = CColors.error;
    return Material(
      color: CColors.errorContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: red),
              const SizedBox(width: 12),
              Text(
                label,
                style: CText.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu kode (gabung anggota biru muda, kode dosen kuning).
class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.label,
    required this.code,
    this.secret = false,
  });

  final String label;
  final String code;
  final bool secret;

  @override
  Widget build(BuildContext context) {
    final ink = secret ? ItsColors.onYellowContainer : ItsColors.blue;
    final labelColor = secret
        ? ItsColors.onYellowContainer
        : ItsColors.inkMuted;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: secret ? ItsColors.yellowContainer : CColors.carousel,
        borderRadius: BorderRadius.circular(16),
        border: secret ? null : Border.all(color: ItsColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label, style: CText.label.copyWith(color: labelColor)),
                    if (secret) ...[
                      const SizedBox(width: 8),
                      Pill(
                        'Rahasiakan',
                        foreground: ItsColors.onYellowContainer,
                        style: CText.chip.copyWith(fontSize: 12),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  code,
                  style: CText.stat.copyWith(
                    fontSize: 20,
                    letterSpacing: 24 * 0.12,
                    color: ink,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: CColors.chipBorder),
            ),
            child: IconButton(
              tooltip: 'Salin',
              icon: const Icon(Icons.content_copy, size: 20),
              color: ink,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) showMessage(context, 'Kode disalin');
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Memuat skor, tugas, dan jumlah rapat lalu menampilkan halaman Kontribusi.
class _ContributionTab extends StatefulWidget {
  const _ContributionTab({required this.group, required this.onTabSelected});
  final Group group;
  final ValueChanged<int> onTabSelected;

  @override
  State<_ContributionTab> createState() => _ContributionTabState();
}

class _ContributionTabState extends State<_ContributionTab> {
  final _service = ContributionService();
  late Future<ContributionData> _data = _service.fetchGroup(widget.group.id);

  void _reload() =>
      setState(() => _data = _service.fetchGroup(widget.group.id));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ContributionData>(
      future: _data,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null) {
          return DetailKontribusiKelompokScreen(
            group: widget.group,
            scores: data.scores,
            tasks: data.tasks,
            totalMeetings: data.totalMeetings,
            onTabSelected: widget.onTabSelected,
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(widget.group.name)),
          body: AsyncView<ContributionData>(
            future: _data,
            onRetry: _reload,
            builder: (_, _) => const SizedBox.shrink(),
          ),
          bottomNavigationBar: ContributionNavBar(
            onSelected: widget.onTabSelected,
          ),
        );
      },
    );
  }
}
