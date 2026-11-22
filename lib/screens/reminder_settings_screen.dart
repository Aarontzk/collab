import 'package:flutter/material.dart';

import 'package:collab/models/app_notification.dart';
import 'package:collab/services/notification_service.dart';
import 'package:collab/widgets/home_cards.dart';

/// Pengaturan pengingat (N2): kapan diingatkan dan notifikasi apa yang aktif.
class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  final _store = NotificationService.instance.store;
  ReminderPrefs? _prefs;

  @override
  void initState() {
    super.initState();
    _store.load().then((p) {
      if (mounted) setState(() => _prefs = p);
    });
  }

  Future<void> _update(ReminderPrefs next) async {
    setState(() => _prefs = next);
    await _store.save(next);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: prefs == null
          ? const Center(child: CircularProgressIndicator())
          : ReminderSettingsView(prefs: prefs, onChanged: _update),
    );
  }
}

/// Isi pengaturan pengingat, tanpa penyimpanan supaya mudah dites.
class ReminderSettingsView extends StatelessWidget {
  const ReminderSettingsView({
    super.key,
    required this.prefs,
    required this.onChanged,
  });

  final ReminderPrefs prefs;
  final ValueChanged<ReminderPrefs> onChanged;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _section('Notifikasi aktif'),
        CheckboxListTile(
          title: const Text('Pengingat deadline'),
          subtitle: const Text('Tugas yang kamu pegang'),
          value: prefs.deadlineOn,
          onChanged: (v) => onChanged(prefs.copyWith(deadlineOn: v)),
        ),
        CheckboxListTile(
          title: const Text('Status tugas'),
          subtitle: const Text('Saat tugasmu disetujui atau ditolak'),
          value: prefs.statusOn,
          onChanged: (v) => onChanged(prefs.copyWith(statusOn: v)),
        ),
        const Divider(height: 32),
        _section('Ingatkan deadline'),
        for (final lead in ReminderLead.values)
          CheckboxListTile(
            title: Text(lead.label),
            value: prefs.leads.contains(lead),
            onChanged: prefs.deadlineOn
                ? (_) => onChanged(prefs.toggleLead(lead))
                : null,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'Pengingat dijadwalkan di HP ini setiap kamu membuka beranda.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
    child: Text(
      title,
      style: HomeText.headline.copyWith(fontWeight: FontWeight.w600),
    ),
  );
}
