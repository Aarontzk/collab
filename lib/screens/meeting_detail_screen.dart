import 'package:flutter/material.dart';

import 'package:collab/models/group.dart';
import 'package:collab/services/meeting_service.dart';
import 'package:collab/utils/dates.dart';
import 'package:collab/utils/theme.dart';
import 'package:collab/widgets/collab_ui.dart';
import 'package:collab/widgets/member_avatar.dart';

/// Absen lebih dari 10 menit setelah rapat mulai dihitung terlambat.
const lateAfter = Duration(minutes: 10);

/// Detail kehadiran satu rapat (Figma Aludra R4).
class MeetingDetailScreen extends StatelessWidget {
  const MeetingDetailScreen({
    super.key,
    required this.meeting,
    required this.members,
    required this.attended,
  });

  final Meeting meeting;
  final List<Member> members;

  /// userId -> jam absen.
  final Map<String, DateTime> attended;

  @override
  Widget build(BuildContext context) {
    final students = members.where((m) => m.role.isStudent).toList();
    final lecturers = members.where((m) => !m.role.isStudent).toList();
    final present = students.where((m) => attended.containsKey(m.userId));
    final pct = students.isEmpty
        ? 0
        : (present.length * 100 / students.length).round();
    const head = TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: ItsColors.ink,
    );
    return Scaffold(
      appBar: AppBar(title: Text(meeting.title)),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CColors.outline),
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const IconBadge(Icons.groups_outlined),
                    title: Text(meeting.title, style: _listText(16)),
                    subtitle: Text(
                      formatLongDate(meeting.startsAt),
                      style: _listText(14, ItsColors.inkMuted),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          '$pct%',
                          style: const TextStyle(
                            fontFamily: AppFonts.text,
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: ItsColors.ink,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${present.length} dari ${students.length} mahasiswa hadir',
                                style: const TextStyle(
                                  fontFamily: AppFonts.body,
                                  fontSize: 13,
                                  color: Color(0xFF5D6070),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ThinProgress(pct / 100),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Mahasiswa', style: head),
          ),
          const SizedBox(height: 4),
          for (final m in students) _memberTile(m),
          if (lecturers.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Pengawas', style: head),
            ),
            const SizedBox(height: 4),
            for (final m in lecturers)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: MemberAvatar(name: m.fullName, avatarUrl: m.avatarUrl),
                title: Text(m.fullName, style: _listText(16)),
                subtitle: Text(
                  m.role.label,
                  style: _listText(14, ItsColors.inkMuted),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _memberTile(Member m) {
    final at = attended[m.userId];
    final (text, color) = attendanceLabel(meeting.startsAt, at);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: MemberAvatar(name: m.fullName, avatarUrl: m.avatarUrl),
      title: Text(m.fullName, style: _listText(16)),
      subtitle: Text(text, style: _listText(14, color)),
    );
  }
}

/// "Hadir, 19.01" / "Terlambat, 19.14" / "Tidak hadir" 
(String, Color) attendanceLabel(DateTime start, DateTime? checkedIn) {
  if (checkedIn == null) return ('Tidak Hadir', CColors.error);
  final time = formatTime(checkedIn).replaceAll(':', '.');
  if (checkedIn.isAfter(start.add(lateAfter))) {
    return ('Terlambat, $time', const Color(0xFF8A5A00));
  }
  return ('Hadir, $time', ItsColors.inkMuted);
}

/// Teks baris daftar
TextStyle _listText(double size, [Color c = ItsColors.ink]) =>
    CText.body.copyWith(
      fontSize: size,
      fontWeight: size >= 16 ? FontWeight.w600 : FontWeight.w400,
      color: c,
    );
