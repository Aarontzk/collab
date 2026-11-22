// Dikerjakan oleh: Rezzel (5026241079 - M. Azwar Alfarezzel Dharmawantara)
// Figma: halaman "Rezzel" > "08 QR rapat – Pro".
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:collab/utils/dates.dart';
import 'package:collab/utils/theme.dart';
import 'package:collab/widgets/collab_ui.dart';
import 'package:collab/widgets/common_widgets.dart';

/// Satu anggota di daftar kehadiran. [checkedInAt] kosong = belum scan.
class AttendanceEntry {
  const AttendanceEntry({
    required this.userId,
    required this.fullName,
    this.checkedInAt,
  });

  final String userId;
  final String fullName;
  final DateTime? checkedInAt;

  bool get present => checkedInAt != null;
}

/// QR absen rapat untuk ketua. QR diganti tiap [rotateEvery]; token di
/// database berlaku 60 detik (`get_meeting_qr`), jadi QR lama masih sah
/// sebentar saat anggota baru selesai scan.
///
/// Screen ini tidak memanggil Supabase. Token, daftar hadir, dan tutup
/// absensi diisi pemanggil lewat meeting service, sesuai aturan di README.
class MeetingQrScreen extends StatefulWidget {
  const MeetingQrScreen({
    super.key,
    required this.title,
    required this.startsAt,
    required this.fetchToken,
    required this.attendance,
    this.onClose,
    this.rotateEvery = const Duration(seconds: 30),
  });

  final String title;
  final DateTime startsAt;

  /// Biasanya `rpc('get_meeting_qr', params: {'p_meeting': id})`.
  final Future<String> Function() fetchToken;

  /// Daftar semua anggota + jam scan, sebaiknya realtime.
  final Stream<List<AttendanceEntry>> attendance;

  /// Aksi tombol "Tutup absensi". Kosong = cukup kembali ke halaman rapat.
  final Future<void> Function()? onClose;

  final Duration rotateEvery;

  @override
  State<MeetingQrScreen> createState() => _MeetingQrScreenState();
}

class _MeetingQrScreenState extends State<MeetingQrScreen> {
  String? _token;
  Object? _error;
  int _left = 0;
  Timer? _ticker;
  bool _closing = false;
  bool _fetching = false;

  int get _total => widget.rotateEvery.inSeconds;

  @override
  void initState() {
    super.initState();
    _refresh();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (_token == null) return;
    if (_left <= 1) {
      _refresh();
    } else {
      setState(() => _left--);
    }
  }

  Future<void> _refresh() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final token = await widget.fetchToken();
      if (!mounted) return;
      setState(() {
        _token = token;
        _error = null;
        _left = _total;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      _fetching = false;
    }
  }

  Future<void> _close() async {
    final onClose = widget.onClose;
    if (onClose != null) {
      setState(() => _closing = true);
      try {
        await onClose();
      } catch (e) {
        if (mounted) showError(context, e);
        if (mounted) setState(() => _closing = false);
        return;
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ItsColors.surfaceLow,
      appBar: AppBar(
        backgroundColor: ItsColors.surfaceLow,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          IconLabel(
            icon: Icons.event,
            label: _meetingTime(widget.startsAt),
            size: 18,
            gap: 8,
            style: const TextStyle(
              fontFamily: AppFonts.text,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: ItsColors.inkMuted,
            ),
          ),
          const SizedBox(height: 16),
          _QrCard(
            token: _token,
            error: _error,
            secondsLeft: _left,
            total: _total,
            onRetry: _refresh,
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<AttendanceEntry>>(
            stream: widget.attendance,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _AttendanceCard.message(
                  'Daftar hadir gagal dimuat. Tarik ulang halaman ini.',
                );
              }
              final list = snapshot.data;
              if (list == null) {
                return _AttendanceCard.message('Memuat daftar hadir...');
              }
              return _AttendanceCard(entries: list);
            },
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: ItsColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: SizedBox(
              height: 48,
              child: FilledButtonTheme(
                data: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppShape.large),
                    ),
                  ).merge(Theme.of(context).filledButtonTheme.style),
                ),
                child: LoadingButton(
                  label: 'Tutup absensi',
                  isLoading: _closing,
                  onPressed: _close,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Contoh: "Kamis, 12 Nov 2026 · 19:00 WIB".
String _meetingTime(DateTime value) {
  final long = formatLongDate(value); // "Kamis, 12 Nov 2026, 19.00"
  final date = long.substring(0, long.lastIndexOf(', '));
  return '$date · ${formatTime(value)} WIB';
}

/// Kartu QR putih radius 28: QR 240, lalu hitung mundur + bar progres.
class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.token,
    required this.error,
    required this.secondsLeft,
    required this.total,
    required this.onRetry,
  });

  final String? token;
  final Object? error;
  final int secondsLeft;
  final int total;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = token;
    final Widget qr;
    if (t != null) {
      qr = QrImageView(
        data: t,
        size: 240,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
      );
    } else if (error != null) {
      qr = MessageView(
        icon: Icons.qr_code_2,
        message: 'QR gagal dibuat',
        actionLabel: 'Coba lagi',
        onAction: onRetry,
      );
    } else {
      qr = const Center(child: CircularProgressIndicator());
    }

    return ElevatedPanel(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        children: [
          SizedBox.square(dimension: 240, child: qr),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'QR berganti otomatis',
                  style: TextStyle(
                    fontFamily: AppFonts.text,
                    fontSize: 13,
                    color: ItsColors.inkMuted,
                  ),
                ),
              ),
              Text(
                t == null ? '-' : '$secondsLeft dtk',
                style: const TextStyle(
                  fontFamily: AppFonts.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ItsColors.blue,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: t == null || total == 0 ? 0 : secondsLeft / total,
              minHeight: 6,
              color: ItsColors.blue,
              backgroundColor: ItsColors.border,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu kehadiran radius 16: judul + jumlah hadir, lalu baris per anggota.
class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.entries}) : note = null;

  const _AttendanceCard.message(String text) : entries = const [], note = text;

  final List<AttendanceEntry> entries;
  final String? note;

  @override
  Widget build(BuildContext context) {
    // Yang sudah hadir di atas (urut jam scan), yang belum di bawah.
    final sorted = [...entries]
      ..sort((a, b) {
        final x = a.checkedInAt, y = b.checkedInAt;
        if (x == null && y == null) return a.fullName.compareTo(b.fullName);
        if (x == null) return 1;
        if (y == null) return -1;
        return x.compareTo(y);
      });
    final present = entries.where((e) => e.present).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppShape.large),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Kehadiran',
                  style: TextStyle(
                    fontFamily: AppFonts.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ItsColors.ink,
                  ),
                ),
              ),
              if (note == null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ItsColors.skyContainer,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '$present / ${entries.length} hadir',
                    style: const TextStyle(
                      fontFamily: AppFonts.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ItsColors.onSkyContainer,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (note != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(note!, style: CText.meta),
            )
          else
            for (final e in sorted) _AttendanceRow(e),
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow(this.entry);

  final AttendanceEntry entry;

  @override
  Widget build(BuildContext context) {
    final at = entry.checkedInAt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            at != null ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: at != null ? ItsColors.blue : CColors.outline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.text,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: at != null ? ItsColors.ink : ItsColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            at != null ? formatTime(at) : 'Belum scan',
            style: TextStyle(
              fontFamily: AppFonts.text,
              fontSize: 12,
              color: at != null ? ItsColors.inkMuted : CColors.error,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
