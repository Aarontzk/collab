import 'package:flutter/material.dart';

import 'package:collab/models/group.dart';
import 'package:collab/screens/meeting_detail_screen.dart';
import 'package:collab/screens/meeting_qr_screen.dart';
import 'package:collab/screens/scan_qr_screen.dart';
import 'package:collab/services/meeting_service.dart';
import 'package:collab/services/supabase_service.dart';
import 'package:collab/utils/dates.dart';
import 'package:collab/utils/theme.dart';
import 'package:collab/utils/validators.dart';
import 'package:collab/widgets/collab_ui.dart';
import 'package:collab/widgets/common_widgets.dart';

/// Posisi rapat terhadap waktu sekarang. QR bisa dibuka 15 menit sebelum mulai sampai 2 jam setelahnya.
enum MeetingPhase { upcoming, open, past }

const qrOpensBefore = Duration(minutes: 15);
const meetingLength = Duration(hours: 2);

MeetingPhase meetingPhase(DateTime start, DateTime now) {
  if (now.isBefore(start.subtract(qrOpensBefore))) return MeetingPhase.upcoming;
  if (!now.isAfter(start.add(meetingLength))) return MeetingPhase.open;
  return MeetingPhase.past;
}

class _MeetingsData {
  const _MeetingsData(this.meetings, this.attendance);
  final List<Meeting> meetings;
  final Map<String, Map<String, DateTime>> attendance;
}

/// Tab Rapat (Figma Aludra R1–R3).
class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key, required this.group, required this.members});
  final Group group;
  final List<Member> members;

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  final _repo = MeetingService();
  late Future<_MeetingsData> _data = _load();

  Future<_MeetingsData> _load() async {
    final results = await Future.wait([
      _repo.fetchMeetings(widget.group.id),
      _repo.fetchAttendances(widget.group.id),
    ]);
    return _MeetingsData(
      results[0] as List<Meeting>,
      results[1] as Map<String, Map<String, DateTime>>,
    );
  }

  void _reload() => setState(() => _data = _load());

  int get _studentCount => widget.members.where((m) => m.role.isStudent).length;

  /// [existing] null = jadwalkan rapat baru, selain itu ubah rapat itu.
  Future<void> _schedule([Meeting? existing]) async {
    final draft = await showCollabSheet<_MeetingDraft>(
      context,
      scrollable: true,
      builder: (_) => _ScheduleSheet(initial: existing),
    );
    if (draft == null || !mounted) return;
    try {
      if (existing == null) {
        await _repo.createMeeting(
          groupId: widget.group.id,
          title: draft.title,
          startsAt: draft.startsAt,
        );
      } else {
        await _repo.updateMeeting(
          meetingId: existing.id,
          title: draft.title,
          startsAt: draft.startsAt,
        );
      }
      if (mounted) {
        showMessage(
          context,
          existing == null ? 'Rapat Dijadwalkan' : 'Rapat Diperbarui',
        );
        _reload();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete(Meeting meeting) async {
    final ok = await showConfirmDialog(
      context,
      icon: Icons.delete_outline,
      danger: true,
      title: 'Hapus rapat?',
      message: '"${meeting.title}" akan dihapus dari jadwal kelompok.',
      confirmLabel: 'Hapus',
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.deleteMeeting(meeting.id);
      if (mounted) {
        showMessage(context, 'Rapat dihapus');
        _reload();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Menu ubah/hapus, hanya untuk ketua dan rapat yang belum mulai.
  Widget? _menuFor(Meeting m, DateTime now) {
    if (!widget.group.amLeader || !canChangeMeeting(m.startsAt, now)) {
      return null;
    }
    return MoreMenu(
      tooltip: 'Ubah atau Hapus Rapat',
      items: [
        MoreMenuItem(
          icon: Icons.edit_outlined,
          label: 'Ubah Rapat',
          onTap: () => _schedule(m),
        ),
        MoreMenuItem(
          icon: Icons.delete_outline,
          label: 'Hapus Rapat',
          danger: true,
          onTap: () => _delete(m),
        ),
      ],
    );
  }

  Future<void> _openQr(Meeting meeting) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MeetingQrScreen(
          title: meeting.title,
          startsAt: meeting.startsAt,
          fetchToken: () => _repo.getQrToken(meeting.id),
          attendance: _repo
              .watchAttendance(meeting.id)
              .map(
                (attended) => [
                  for (final m in widget.members)
                    AttendanceEntry(
                      userId: m.userId,
                      fullName: m.fullName,
                      checkedInAt: attended[m.userId],
                    ),
                ],
              ),
        ),
      ),
    );
    _reload();
  }

  Future<void> _scan(Meeting meeting) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ScanQrScreen(
          meeting: MeetingInfo(
            title: meeting.title,
            schedule: meeting.startsAt,
          ),
        ),
      ),
    );
    if (ok == true && mounted) {
      showMessage(context, 'Absen berhasil');
      _reload();
    }
  }

  void _openDetail(Meeting m, Map<String, DateTime> attended) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MeetingDetailScreen(
          meeting: m,
          members: widget.members,
          attended: attended,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: widget.group.amLeader
          ? FloatingActionButton.extended(
              onPressed: _schedule,
              icon: const Icon(Icons.add),
              label: const Text('Jadwalkan'),
            )
          : null,
      body: AsyncView<_MeetingsData>(
        future: _data,
        onRetry: _reload,
        builder: (context, data) => RefreshIndicator(
          onRefresh: () async => _reload(),
          child: _content(data),
        ),
      ),
    );
  }

  Widget _content(_MeetingsData data) {
    final now = DateTime.now();
    final me = currentUserId;
    final notPast =
        data.meetings
            .where((m) => meetingPhase(m.startsAt, now) != MeetingPhase.past)
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final next = notPast.isEmpty ? null : notPast.first;
    final later = notPast.skip(1).toList();
    final started = data.meetings.where((m) => !m.startsAt.isAfter(now));
    final past = data.meetings
        .where((m) => meetingPhase(m.startsAt, now) == MeetingPhase.past)
        .toList();
    final mine = started
        .where((m) => data.attendance[m.id]?.containsKey(me) ?? false)
        .length;

    if (data.meetings.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          MessageView(
            icon: Icons.today_outlined,
            message: widget.group.amLeader
                ? 'Belum ada rapat.\nJadwalkan rapat pertama kelompokmu.'
                : 'Belum ada rapat terjadwal.',
          ),
        ],
      );
    }

    return TabPageList(
      children: [
        if (widget.group.myRole.isStudent && started.isNotEmpty)
          SummaryCard(
            icon: Icons.groups_outlined,
            title: 'Rapat',
            value: '$mine/${started.length}',
            caption: 'rapat kamu hadiri',
            progress: mine / started.length,
          ),
        if (next != null)
          TabSection(
            title: meetingPhase(next.startsAt, now) == MeetingPhase.open
                ? 'Sedang Berlangsung'
                : 'Rapat Berikutnya',
            child: _NextMeetingCard(
              meeting: next,
              phase: meetingPhase(next.startsAt, now),
              isLeader: widget.group.amLeader,
              canScan: widget.group.myRole.isStudent,
              attendees: data.attendance[next.id]?.length ?? 0,
              students: _studentCount,
              onOpenQr: () => _openQr(next),
              onScan: () => _scan(next),
              menu: _menuFor(next, now),
            ),
          ),
        if (later.isNotEmpty)
          TabSection(
            title: 'Terjadwal',
            child: OutlinedList(
              children: [
                for (final m in later)
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 16, right: 4),
                    leading: const IconBadge(Icons.today_outlined),
                    title: Text(m.title, style: CText.rowTitle),
                    subtitle: Text(
                      formatLongDate(m.startsAt),
                      style: CText.meta,
                    ),
                    trailing: _menuFor(m, now),
                  ),
              ],
            ),
          ),
        if (past.isNotEmpty)
          TabSection(
            title: 'Riwayat Rapat',
            child: OutlinedList(
              children: [
                for (final m in past)
                  _historyTile(m, data.attendance[m.id] ?? {}, me),
              ],
            ),
          ),
      ],
    );
  }

  Widget _historyTile(Meeting m, Map<String, DateTime> attended, String me) {
    final present = attended.containsKey(me);
    final students = _studentCount;
    final count = widget.members
        .where((x) => x.role.isStudent && attended.containsKey(x.userId))
        .length;
    final d = m.startsAt.toLocal();
    final date = formatDateShort(d).split(',').first;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: IconBadge(
        present ? Icons.check : Icons.cancel_outlined,
        color: present ? CColors.icon : ItsColors.inkMuted,
      ),
      title: Text(m.title, style: CText.rowTitle),
      subtitle: Text(
        widget.group.myRole.isStudent
            ? '$date, ${present ? 'Hadir' : 'Tidak Hadir'}, $count/$students hadir'
            : '$date, $count/$students hadir',
        style: CText.meta,
      ),
      onTap: () => _openDetail(m, attended),
    );
  }
}

/// Kartu rapat berikutnya / sedang berlangsung (R1, R2).
class _NextMeetingCard extends StatelessWidget {
  const _NextMeetingCard({
    required this.meeting,
    required this.phase,
    required this.isLeader,
    required this.canScan,
    required this.attendees,
    required this.students,
    required this.onOpenQr,
    required this.onScan,
    this.menu,
  });

  final Meeting meeting;
  final MeetingPhase phase;
  final bool isLeader;
  final bool canScan;
  final int attendees;
  final int students;
  final VoidCallback onOpenQr;
  final VoidCallback onScan;

  /// Menu ubah/hapus (ketua, rapat belum mulai).
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final open = phase == MeetingPhase.open;
    final opensAt = meeting.startsAt.subtract(qrOpensBefore);
    final label = isLeader
        ? (open ? 'Tampilkan QR Absensi' : 'Mulai Absensi QR')
        : 'Pindai QR Absen';
    final showButton = isLeader || canScan;
    return OutlinedList(
      children: [
        ListTile(
          contentPadding: EdgeInsets.fromLTRB(16, 4, menu == null ? 16 : 4, 4),
          leading: const IconBadge(Icons.groups_outlined),
          title: Text(meeting.title, style: CText.rowTitle),
          subtitle: Text(formatLongDate(meeting.startsAt), style: CText.meta),
          trailing: menu,
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showButton) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: open ? (isLeader ? onOpenQr : onScan) : null,
                  icon: const Icon(Icons.mobile_friendly),
                  label: Text(label),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                open
                    ? '$attendees dari $students anggota sudah absen'
                    : 'Dapat dimulai pada pukul ${formatTime(opensAt).replaceAll(':', '.')}',
                textAlign: TextAlign.center,
                style: CText.label,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MeetingDraft {
  const _MeetingDraft(this.title, this.startsAt);
  final String title;
  final DateTime startsAt;
}

/// Sheet "Jadwalkan Rapat" (R3).
class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({this.initial});

  /// Rapat yang sedang diubah; null = jadwalkan baru.
  final Meeting? initial;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title);
  late DateTime _date = DateUtils.dateOnly(
    widget.initial?.startsAt.toLocal() ?? DateTime.now(),
  );
  late TimeOfDay _time = widget.initial != null
      ? TimeOfDay.fromDateTime(widget.initial!.startsAt.toLocal())
      : TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)))
            .replacing(minute: 0);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateUtils.dateOnly(now),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final start = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    // Rapat yang diubah harus tetap di masa depan, kalau tidak terkunci.
    if (widget.initial != null && !start.isAfter(DateTime.now())) {
      showMessage(context, 'Pilih waktu yang belum terlewat', isError: true);
      return;
    }
    Navigator.pop(context, _MeetingDraft(_title.text.trim(), start));
  }

  @override
  Widget build(BuildContext context) {
    final time =
        '${_time.hour.toString().padLeft(2, '0')}.${_time.minute.toString().padLeft(2, '0')}';
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            title: widget.initial == null ? 'Jadwalkan Rapat' : 'Ubah Rapat',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Judul Rapat'),
            validator: (v) => Validators.requiredText(v, max: 150),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _PickerField(
                  label: 'Tanggal',
                  value: formatLongDate(_date).split(',').take(2).join(','),
                  icon: Icons.today_outlined,
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _PickerField(
                  label: 'Jam',
                  value: time,
                  icon: Icons.schedule,
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: _save,
                  child: const Text('Simpan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: Icon(icon, color: ItsColors.inkMuted),
        ),
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
