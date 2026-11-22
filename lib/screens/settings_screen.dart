import 'package:flutter/material.dart';

import 'package:collab/models/profile.dart';
import 'package:collab/screens/new_password_screen.dart';
import 'package:collab/screens/profile_screen.dart';
import 'package:collab/screens/reminder_settings_screen.dart';
import 'package:collab/services/auth_service.dart';
import 'package:collab/services/profile_service.dart';
import 'package:collab/utils/app_assets.dart';
import 'package:collab/widgets/collab_ui.dart';
import 'package:collab/widgets/common_widgets.dart';
import 'package:collab/widgets/member_avatar.dart';

/// Pengaturan, penempatannya mengikuti Pengaturan Google:
/// cari di atas, kartu akun, daftar kategori, keluar akun paling bawah.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _profiles = ProfileService();
  late Future<Profile> _me = _profiles.fetchMine();
  bool _changed = false;

  void _reload() => setState(() => _me = _profiles.fetchMine());

  Future<void> _signOut() async {
    Navigator.of(context).popUntil((route) => route.isFirst);
    await AuthService().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Pengaturan')),
        body: AsyncView<Profile>(
          future: _me,
          onRetry: _reload,
          builder: (context, me) => SettingsView(
            profile: me,
            email: _profiles.email,
            onSignOut: _signOut,
            onProfileChanged: () {
              _changed = true;
              _reload();
            },
          ),
        ),
      ),
    );
  }
}

/// Satu kategori pengaturan.
class _Entry {
  const _Entry(this.icon, this.title, this.summary, this.open);
  final IconData icon;
  final String title;
  final String summary;
  final Future<void> Function(BuildContext context) open;
}

/// Isi halaman pengaturan, dipisah supaya bisa dites tanpa Supabase.
class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.profile,
    required this.onSignOut,
    this.email,
    this.onProfileChanged,
  });

  final Profile profile;
  final String? email;
  final VoidCallback onSignOut;
  final VoidCallback? onProfileChanged;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  String _query = '';

  Future<void> _openProfile(BuildContext context) async {
    final changed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    if (changed == true) widget.onProfileChanged?.call();
  }

  late final List<_Entry> _entries = [
    _Entry(
      Icons.notifications_outlined,
      'Notifikasi',
      'Pengingat deadline, status tugas',
      (context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ReminderSettingsScreen()),
      ),
    ),
    _Entry(
      Icons.person_outline,
      'Akun',
      'Nama, NRP, foto profil',
      _openProfile,
    ),
    _Entry(
      Icons.keyboard_outlined,
      'Keamanan',
      'Ubah kata sandi',
      (context) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (routeContext) => NewPasswordScreen(
            showBack: true,
            onDone: () => Navigator.of(routeContext).pop(),
          ),
        ),
      ),
    ),
    _Entry(
      Icons.info_outline,
      'Tentang Collab',
      'Versi aplikasi, lisensi',
      (context) async => showAboutDialog(
        context: context,
        applicationName: 'Collab',
        applicationVersion: '0.1.0',
        applicationIcon: Image.asset(AppAssets.logoMark, width: 48),
        applicationLegalese: 'Tugas kelompok Teknologi Berkembang, ITS',
      ),
    ),
  ];

  List<_Entry> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _entries;
    return _entries
        .where(
          (e) =>
              e.title.toLowerCase().contains(q) ||
              e.summary.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final p = widget.profile;
    final visible = _visible;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SearchBar(
            hintText: 'Cari pengaturan',
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll(0),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: MemberAvatar(
                name: p.fullName,
                avatarUrl: p.avatarUrl,
                radius: 24,
              ),
              title: Text(p.fullName, style: text.titleMedium),
              subtitle: widget.email == null ? null : Text(widget.email!),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openProfile(context),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Tidak ada pengaturan yang cocok',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        for (final e in visible)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 32),
            leading: IconBadge(e.icon, size: 48),
            title: Text(e.title),
            subtitle: Text(e.summary),
            onTap: () => e.open(context),
          ),
        const Divider(height: 32),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 32),
          textColor: CColors.error,
          leading: const IconBadge(
            Icons.logout,
            size: 48,
            background: CColors.errorContainer,
            color: CColors.error,
          ),
          title: const Text('Keluar akun'),
          onTap: widget.onSignOut,
        ),
      ],
    );
  }
}
