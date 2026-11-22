const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String _twoDigits(int n) => n.toString().padLeft(2, '0');

/// Contoh: "4 Nov 2026, 09:05" (waktu lokal).
String formatDateTime(DateTime value) {
  final d = value.toLocal();
  return '${d.day} ${_months[d.month - 1]} ${d.year}, '
      '${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';
}

/// Senin minggu ini (UTC) dalam format yyyy-mm-dd.
/// Sama dengan `date_trunc('week', now())::date` di Supabase.
String weekStartUtc(DateTime now) {
  final utc = now.toUtc();
  final today = DateTime.utc(utc.year, utc.month, utc.day);
  final monday = today.subtract(Duration(days: utc.weekday - DateTime.monday));
  return '${monday.year}-${_twoDigits(monday.month)}-${_twoDigits(monday.day)}';
}

const _weekdays = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

/// Untuk deadline dekat. Contoh: "Senin, 23:59" (dalam 7 hari)
/// atau "10 Nov, 23:59" (lebih jauh). Waktu lokal.
String formatDeadlineShort(DateTime value, DateTime now) {
  final d = value.toLocal();
  final time = '${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';
  if (d.difference(now.toLocal()).inDays < 7) {
    return '${_weekdays[d.weekday - 1]}, $time';
  }
  return '${d.day} ${_months[d.month - 1]}, $time';
}

/// Contoh: "09:05" (waktu lokal).
String formatTime(DateTime value) {
  final d = value.toLocal();
  return '${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';
}

/// Contoh: "12 Nov, 23:59" (waktu lokal).
String formatDateShort(DateTime value) {
  final d = value.toLocal();
  return '${d.day} ${_months[d.month - 1]}, '
      '${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';
}

/// Contoh: "Sen, 23:59" (hari disingkat, waktu lokal).
String formatDayTime(DateTime value) {
  final d = value.toLocal();
  return '${_weekdays[d.weekday - 1].substring(0, 3)}, '
      '${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';
}

const _weekdaysLong = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

/// Contoh: "Kamis, 19 Nov 2026, 19.00" (waktu lokal).
String formatLongDate(DateTime value) {
  final d = value.toLocal();
  return '${_weekdaysLong[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} '
      '${d.year}, ${_twoDigits(d.hour)}.${_twoDigits(d.minute)}';
}

/// Contoh: "Min, 15 Nov 2026 pukul 23:59" (waktu lokal).
String formatDeadlineFull(DateTime value) {
  final d = value.toLocal();
  return '${_weekdays[d.weekday - 1].substring(0, 3)}, ${d.day} '
      '${_months[d.month - 1]} ${d.year} pukul '
      '${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';
}
