import 'package:flutter/material.dart';

import 'package:collab/models/profile.dart';
import 'package:collab/services/auth_service.dart';
import 'package:collab/services/profile_service.dart';
import 'package:collab/utils/validators.dart';
import 'package:collab/widgets/auth_page.dart';
import 'package:collab/widgets/collab_ui.dart';
import 'package:collab/widgets/common_widgets.dart';
import 'package:collab/widgets/home_cards.dart';
import 'package:collab/widgets/labeled_field.dart';
import 'package:collab/widgets/member_avatar.dart';

/// Profil akun sendiri: lihat, ubah nama & NRP, keluar akun.
/// Mengembalikan `true` lewat Navigator.pop kalau profil diubah.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.service});

  /// Bisa diganti di tes; default ke Supabase.
  final ProfileService? service;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileService _repo = widget.service ?? ProfileService();
  late Future<Profile> _profile = _repo.fetchMine();
  bool _changed = false;

  void _reload() => setState(() => _profile = _repo.fetchMine());

  Future<void> _signOut() async {
    // Tutup halaman ini dulu; AuthGate lalu otomatis menampilkan login.
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
        appBar: AppBar(title: const Text('Profil')),
        body: AsyncView<Profile>(
          future: _profile,
          onRetry: _reload,
          builder: (context, profile) => ProfileView(
            profile: profile,
            email: _repo.email,
            onSave: (name, nrp) async {
              final saved = await _repo.updateMine(fullName: name, nrp: nrp);
              _changed = true;
              return saved;
            },
            onSignOut: _signOut,
          ),
        ),
      ),
    );
  }
}

/// Isi halaman profil, dipisah dari Supabase supaya bisa dites.
class ProfileView extends StatefulWidget {
  const ProfileView({
    super.key,
    required this.profile,
    required this.onSave,
    required this.onSignOut,
    this.email,
  });

  final Profile profile;
  final String? email;

  /// Mengembalikan profil setelah disimpan.
  final Future<Profile> Function(String fullName, String nrp) onSave;
  final VoidCallback onSignOut;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _nrp = TextEditingController(text: widget.profile.nrp ?? '');
  late Profile _profile = widget.profile;
  bool _saving = false;

  /// Tombol simpan hanya aktif kalau ada yang diubah.
  bool get _dirty =>
      _name.text.trim() != _profile.fullName ||
      _nrp.text.trim() != (_profile.nrp ?? '');

  void _onChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    _name.addListener(_onChanged);
    _nrp.addListener(_onChanged);
  }

  @override
  void dispose() {
    _name.dispose();
    _nrp.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.onSave(_name.text, _nrp.text);
      if (!mounted) return;
      setState(() => _profile = saved);
      showMessage(context, 'Profil disimpan');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final email = widget.email;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(
          child: MemberAvatar(
            name: profile.fullName,
            avatarUrl: profile.avatarUrl,
            radius: 44,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          profile.fullName,
          textAlign: TextAlign.center,
          style: HomeText.pageTitle,
        ),
        if (email != null) ...[
          const SizedBox(height: 4),
          Text(email, textAlign: TextAlign.center, style: HomeText.supporting),
        ],
        const SizedBox(height: 32),
        Text('Data diri', style: HomeText.section),
        const SizedBox(height: 16),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'Nama lengkap',
                child: TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  validator: Validators.requiredText,
                ),
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: 'NRP',
                optional: true,
                child: TextFormField(
                  controller: _nrp,
                  keyboardType: TextInputType.number,
                  validator: Validators.nrp,
                  onFieldSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(height: 8),
              const RequirementList(['Hanya angka', '5–20 digit']),
              const SizedBox(height: 24),
              LoadingButton(
                label: 'Simpan perubahan',
                isLoading: _saving,
                onPressed: _dirty ? _save : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          textColor: CColors.error,
          leading: const IconBadge(
            Icons.logout,
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
