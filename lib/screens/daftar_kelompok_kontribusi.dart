import 'package:flutter/material.dart';

import 'package:collab/models/contribution.dart';
import 'package:collab/models/group.dart';
import 'package:collab/models/profile.dart';
import 'package:collab/models/task.dart';
import 'package:collab/screens/detail_kontribusi_kelompok.dart';
import 'package:collab/services/auth_service.dart';
import 'package:collab/services/group_service.dart';
import 'package:collab/services/home_service.dart';
import 'package:collab/services/profile_service.dart';
import 'package:collab/services/supabase_service.dart';
import 'package:collab/utils/theme.dart';
import 'package:collab/widgets/collab_ui.dart';
import 'package:collab/widgets/common_widgets.dart';
import 'package:collab/widgets/contribution_nav_bar.dart';
import 'package:collab/widgets/home_cards.dart';
import 'package:collab/widgets/member_avatar.dart';

/// Daftar kelompok untuk memantau porsi kontribusi tiap anggota.
///
/// Data diambil dari RPC `contribution_scores(gid)` di `supabase/schema.sql`.
/// Kalau skor belum bisa dihitung (belum ada tugas/rapat/review), kartu
/// menampilkan progres tugas sebagai gantinya.
///
/// Pemakaian:
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(builder: (_) => const DaftarKelompokKontribusiScreen()),
/// );
/// ```
class DaftarKelompokKontribusiScreen extends StatefulWidget {
  const DaftarKelompokKontribusiScreen({
    super.key,
    this.onOpenGroup,
    this.onTabSelected,
  });

  /// Kalau diisi, kartu kelompok membuka halaman ini, bukan bottom sheet.
  final ValueChanged<Group>? onOpenGroup;

  /// Kalau diisi, navigasi bawah meneruskan indeks tab ke pemanggil.
  final ValueChanged<int>? onTabSelected;

  @override
  State<DaftarKelompokKontribusiScreen> createState() =>
      _DaftarKelompokKontribusiScreenState();
}

class _Data {
  const _Data({required this.profile, required this.groups});

  final Profile profile;
  final List<KelompokKontribusi> groups;
}

class _DaftarKelompokKontribusiScreenState
    extends State<DaftarKelompokKontribusiScreen> {
  final _home = HomeService();
  final _profiles = ProfileService();
  final _groups = GroupService();
  late Future<_Data> _data = _load();

  Future<_Data> _load() async {
    final workFuture = _home.fetchMyWork();
    final profileFuture = _profiles.fetchMine();
    final work = await workFuture;
    final profile = await profileFuture;

    var meetingCounts = <String, int>{};
    try {
      meetingCounts = await _home.fetchMeetingCounts([
        for (final group in work.groups) group.id,
      ]);
    } catch (_) {
      // Tabel rapat belum bisa dibaca: tampilkan jumlah kehadiran saja.
    }

    final groups = <KelompokKontribusi>[];
    for (final group in work.groups) {
      var withMembers = group;
      try {
        withMembers = group.withMembers(await _groups.fetchMembers(group.id));
      } catch (_) {
        // Anggota gagal dimuat: kartu tetap tampil tanpa avatar.
      }
      groups.add(
        await _loadGroup(work, withMembers, meetingCounts[group.id] ?? 0),
      );
    }
    return _Data(profile: profile, groups: groups);
  }

  Future<KelompokKontribusi> _loadGroup(
    MyWork work,
    Group group,
    int totalMeetings,
  ) async {
    final tasks = [
      for (final task in work.tasks)
        if (task.groupId == group.id) task,
    ];
    final done = tasks.where((task) => task.isDone).length;

    var scores = <ContributionScore>[];
    try {
      final rows = await supabase.rpc(
        'contribution_scores',
        params: {'gid': group.id},
      );
      if (rows is List) {
        scores = [
          for (final row in rows)
            if (row is Map<String, dynamic>) ContributionScore.fromJson(row),
        ];
      }
    } catch (_) {
      // RPC belum tersedia atau RLS menolak: pakai progres tugas saja.
    }

    ContributionScore? mine;
    for (final score in scores) {
      if (score.userId == _home.myUserId) mine = score;
    }

    var average = 0.0;
    if (scores.isNotEmpty) {
      average =
          scores.fold<double>(0, (sum, s) => sum + s.contributionPct) /
          scores.length;
    }

    return KelompokKontribusi(
      group: group,
      memberCount: group.studentCount,
      taskProgress: tasks.isEmpty ? 0 : done / tasks.length,
      myContribution: mine?.contributionPct ?? 0,
      averageContribution: average,
      hasScore: mine?.hasActivity ?? false,
      needsAttention: mine?.needsAttention ?? false,
      scores: scores,
      totalMeetings: totalMeetings,
      tasks: tasks,
    );
  }

  void _reload() => setState(() => _data = _load());

  Future<void> _refresh() async {
    _reload();
    try {
      await _data;
    } catch (_) {
      // Pesan gagal sudah ditampilkan AsyncView.
    }
  }

  Future<void> _logout() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Keluar akun?'),
        content: const Text('Kamu perlu login lagi untuk membuka Collab.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    await AuthService().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: AsyncView<_Data>(
          future: _data,
          onRetry: _reload,
          builder: (context, data) => DaftarKelompokKontribusiView(
            profile: data.profile,
            groups: data.groups,
            onRefresh: _refresh,
            onOpenGroup: widget.onOpenGroup,
            onLogout: _logout,
          ),
        ),
      ),
      bottomNavigationBar: ContributionNavBar(
        onSelected: widget.onTabSelected,
      ),
    );
  }
}

/// Satu kelompok + angka kontribusi yang ditampilkan di kartu.
class KelompokKontribusi {
  const KelompokKontribusi({
    required this.group,
    required this.memberCount,
    required this.taskProgress,
    required this.myContribution,
    required this.averageContribution,
    required this.hasScore,
    required this.needsAttention,
    this.scores = const [],
    this.totalMeetings = 0,
    this.tasks = const [],
  });

  final Group group;
  final int memberCount;

  /// 0-1, dari tugas yang sudah disetujui.
  final double taskProgress;

  /// Persen 0-100.
  final double myContribution;
  final double averageContribution;

  /// Sudah ada aktivitas yang bisa dihitung.
  final bool hasScore;
  final bool needsAttention;
  final List<ContributionScore> scores;

  /// Jumlah rapat kelompok, untuk "Hadir 4/5" di halaman detail.
  final int totalMeetings;

  /// Tugas kelompok, untuk rincian di halaman detail anggota.
  final List<Task> tasks;

  String get metricLabel =>
      hasScore ? 'Kontribusi Kamu' : 'Progres tugas';

  double get metricPercent => hasScore ? myContribution : taskProgress * 100;

  double get metricFraction =>
      (hasScore ? myContribution / 100 : taskProgress).clamp(0.0, 1.0);

  String get statusLabel {
    if (needsAttention) return 'Perlu perhatian';
    if (hasScore) return 'Seimbang';
    return 'Belum ada skor';
  }
}

/// Tampilan tanpa Supabase, supaya mudah dites atau dipakai ulang.
class DaftarKelompokKontribusiView extends StatefulWidget {
  const DaftarKelompokKontribusiView({
    super.key,
    required this.profile,
    required this.groups,
    required this.onRefresh,
    this.onOpenGroup,
    this.onLogout,
  });

  final Profile profile;
  final List<KelompokKontribusi> groups;
  final Future<void> Function() onRefresh;
  final ValueChanged<Group>? onOpenGroup;
  final VoidCallback? onLogout;

  @override
  State<DaftarKelompokKontribusiView> createState() =>
      _DaftarKelompokKontribusiViewState();
}

class _DaftarKelompokKontribusiViewState
    extends State<DaftarKelompokKontribusiView> {
  MemberRole? _role;

  List<KelompokKontribusi> get _visible => _role == null
      ? widget.groups
      : [
          for (final item in widget.groups)
            if (item.group.myRole == _role) item,
        ];

  double get _average {
    final scored = [
      for (final item in widget.groups)
        if (item.hasScore) item.averageContribution,
    ];
    if (scored.isEmpty) return 0;
    return scored.reduce((a, b) => a + b) / scored.length;
  }

  Future<void> _open(KelompokKontribusi item) async {
    final onOpenGroup = widget.onOpenGroup;
    if (onOpenGroup != null) {
      onOpenGroup(item.group);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetailKontribusiKelompokScreen(
          group: item.group,
          scores: item.scores,
          totalMeetings: item.totalMeetings,
          tasks: item.tasks,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Kelompokku',
                  style: HomeText.headline.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: ItsColors.blue,
                  ),
                ),
              ),
              if (widget.onLogout != null)
                IconButton(
                  tooltip: 'Keluar akun',
                  onPressed: widget.onLogout,
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: ItsColors.ink,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _HeroCard(
            name: widget.profile.fullName,
            average: _average,
            groupCount: widget.groups.length,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text('Kelompokmu', style: HomeText.section),
              ),
              _RoleFilter(
                value: _role,
                onSelected: (role) => setState(() => _role = role),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (visible.isEmpty)
            MessageView(
              icon: Icons.groups_outlined,
              message: _role == null
                  ? 'Belum ada kelompok.\nGabung atau buat kelompok dulu.'
                  : 'Tidak ada kelompok dengan peran ini.',
            )
          else
            for (final item in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GroupContributionCard(
                  item: item,
                  onTap: () => _open(item),
                ),
              ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.name,
    required this.average,
    required this.groupCount,
  });

  final String name;
  final double average;
  final int groupCount;

  static String _firstName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Kamu';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A78), Color(0xFF2E64C4)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Halo, ${_firstName(name)}',
            style: const TextStyle(
              fontFamily: AppFonts.text,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pilih kelompok untuk memantau porsi kontribusi & '
            'transparansi penilaian tim.',
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 13,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HeroStat(
                  value: formatPercent(average),
                  label: 'rata-rata kontribusi',
                ),
              ),
              Container(
                width: 1,
                height: 38,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: Colors.white.withValues(alpha: 0.24),
              ),
              Expanded(
                child: _HeroStat(
                  value: '$groupCount',
                  label: 'kelompok aktif',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppFonts.text,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.1,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }
}

class _GroupContributionCard extends StatelessWidget {
  const _GroupContributionCard({required this.item, required this.onTap});

  final KelompokKontribusi item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final attention = item.needsAttention;
    final accent = attention ? CColors.error : ItsColors.blue;
    return ElevatedPanel(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LetterAvatar(item.group.name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HomeText.cardTitle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.group.displayCourse,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HomeText.supporting,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              RolePill(item.group.myRole),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(item.metricLabel, style: HomeText.supporting),
              ),
              Text(
                formatPercent(item.metricPercent),
                style: HomeText.cardTitle.copyWith(color: accent),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.metricFraction,
              minHeight: 6,
              color: accent,
              backgroundColor: ItsColors.border,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _AvatarStack(members: item.group.members),
              const SizedBox(width: 8),
              Text('${item.memberCount} anggota', style: HomeText.meta),
              const Spacer(),
              _StatusPill(item: item),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.members});

  final List<Member> members;

  @override
  Widget build(BuildContext context) {
    final shown = members.take(3).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 26,
      width: 20.0 * (shown.length - 1) + 26,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 20,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: MemberAvatar(
                  name: shown[i].fullName,
                  avatarUrl: shown[i].avatarUrl,
                  radius: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.item});

  final KelompokKontribusi item;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, border, icon) = switch (item) {
      _ when item.needsAttention => (
        CColors.error,
        CColors.errorContainer,
        Colors.transparent,
        Icons.warning_amber_rounded,
      ),
      _ when item.hasScore => (
        CColors.success,
        Colors.white,
        CColors.success,
        null,
      ),
      _ => (ItsColors.inkMuted, Colors.white, CColors.outline, null),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            item.statusLabel,
            style: HomeText.label.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleFilter extends StatelessWidget {
  const _RoleFilter({required this.value, required this.onSelected});

  final MemberRole? value;
  final ValueChanged<MemberRole?> onSelected;

  @override
  Widget build(BuildContext context) {
    final label = value?.label ?? 'Semua peran';
    return PopupMenuButton<String>(
      tooltip: 'Filter peran',
      position: PopupMenuPosition.under,
      color: Colors.white,
      onSelected: (key) => onSelected(
        key == 'all' ? null : MemberRole.values.byName(key),
      ),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'all', child: Text('Semua peran')),
        for (final role in MemberRole.values)
          PopupMenuItem(value: role.name, child: Text(role.label)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: CColors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: HomeText.label.copyWith(
                color: ItsColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.expand_more,
              size: 18,
              color: ItsColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// "14,5%" - satu desimal, atau tanpa desimal kalau bulat.
String formatPercent(double value) {
  final rounded = value.roundToDouble();
  final text = (value - rounded).abs() < 0.05
      ? rounded.toStringAsFixed(0)
      : value.toStringAsFixed(1).replaceAll('.', ',');
  return '$text%';
}
