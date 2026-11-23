import 'package:collab/services/supabase_service.dart';

class Meeting {
  const Meeting({
    required this.id,
    required this.title,
    required this.startsAt,
  });

  final String id;
  final String title;
  final DateTime startsAt;

  factory Meeting.fromJson(Map<String, dynamic> json) => Meeting(
    id: json['id'] as String,
    title: json['title'] as String,
    startsAt: DateTime.parse(json['starts_at'] as String),
  );
}

/// Rapat boleh diubah/dihapus selama belum mulai (sama dengan aturan RLS).
bool canChangeMeeting(DateTime startsAt, DateTime now) => startsAt.isAfter(now);

class MeetingService {
  Future<List<Meeting>> fetchMeetings(String groupId) async {
    final rows = await supabase
        .from('meetings')
        .select('id, title, starts_at')
        .eq('group_id', groupId)
        .order('starts_at', ascending: false);
    return rows.map(Meeting.fromJson).toList();
  }

  /// id meeting yang sudah saya hadiri.
  Future<Set<String>> fetchMyAttendance(String groupId) async {
    final rows = await supabase
        .from('meeting_attendances')
        .select('meeting_id, meetings!inner(group_id)')
        .eq('user_id', currentUserId)
        .eq('meetings.group_id', groupId);
    return rows.map((r) => r['meeting_id'] as String).toSet();
  }

  /// Kehadiran semua rapat kelompok: meetingId -> (userId -> jam absen).
  Future<Map<String, Map<String, DateTime>>> fetchAttendances(
    String groupId,
  ) async {
    final rows = await supabase
        .from('meeting_attendances')
        .select('meeting_id, user_id, checked_in_at, meetings!inner(group_id)')
        .eq('meetings.group_id', groupId);
    final result = <String, Map<String, DateTime>>{};
    for (final r in rows) {
      (result[r['meeting_id'] as String] ??= {})[r['user_id'] as String] =
          DateTime.parse(r['checked_in_at'] as String);
    }
    return result;
  }

  /// [startsAt] null = mulai sekarang.
  Future<Meeting> createMeeting({
    required String groupId,
    required String title,
    DateTime? startsAt,
  }) async {
    final row = await supabase
        .from('meetings')
        .insert({
          'group_id': groupId,
          'title': title.trim(),
          'starts_at': ?startsAt?.toUtc().toIso8601String(),
        })
        .select('id, title, starts_at')
        .single();
    return Meeting.fromJson(row);
  }

  /// Khusus ketua, hanya untuk rapat yang belum mulai (dijaga RLS).
  Future<void> updateMeeting({
    required String meetingId,
    required String title,
    required DateTime startsAt,
  }) async {
    final updated = await supabase
        .from('meetings')
        .update({
          'title': title.trim(),
          'starts_at': startsAt.toUtc().toIso8601String(),
        })
        .eq('id', meetingId)
        .select('id');
    if (updated.isEmpty) {
      throw StateError('Rapat yang sudah mulai tidak bisa diubah');
    }
  }

  /// Khusus ketua, hanya untuk rapat yang belum mulai (dijaga RLS).
  Future<void> deleteMeeting(String meetingId) async {
    final deleted = await supabase
        .from('meetings')
        .delete()
        .eq('id', meetingId)
        .select('id');
    if (deleted.isEmpty) {
      throw StateError('Rapat yang sudah mulai tidak bisa dihapus');
    }
  }

  /// Khusus ketua. Token baru tiap dipanggil, berlaku 60 detik.
  Future<String> getQrToken(String meetingId) async {
    final token = await supabase.rpc(
      'get_meeting_qr',
      params: {'p_meeting': meetingId},
    );
    return token as String;
  }

  /// Absen satu rapat secara realtime: userId -> jam absen.
  Stream<Map<String, DateTime>> watchAttendance(String meetingId) {
    return supabase
        .from('meeting_attendances')
        .stream(primaryKey: ['meeting_id', 'user_id'])
        .eq('meeting_id', meetingId)
        .map(
          (rows) => {
            for (final r in rows)
              r['user_id'] as String: DateTime.parse(
                r['checked_in_at'] as String,
              ),
          },
        );
  }

  Future<void> checkIn(String token) async {
    await supabase.rpc('check_in', params: {'p_token': token.trim()});
  }
}
