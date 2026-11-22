import 'package:flutter/material.dart';

// ============================================================
// Collab - Kelompok 15 Tekber
// Pindai QR absen (scan_qr_screen) — semua dalam satu file
// ============================================================

const _navy = Color(0xFF1F3A82);
const _lightBlue = Color(0xFFD3EAF7);
const _bg = Color(0xFFF5F6FC);
const _darkPanel = Color(0xFF1B1C21);
const _viewfinder = Color(0xFF2B2C35);
const _amber = Color(0xFFFFB81C);
const _errorRed = Color(0xFFB3261E);
const _errorBg = Color(0xFFF9DCDA);

// ------------------------- MODELS -------------------------

enum ScanState { scanning, success, invalid }

class MeetingInfo {
  final String title;
  final DateTime schedule;

  const MeetingInfo({required this.title, required this.schedule});
}

// ------------------------ HELPERS -------------------------

const _dayFull = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _dayShort = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _monthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
];

String _two(int n) => n.toString().padLeft(2, '0');

/// Contoh: "Kamis, 12 Nov 2026 · 19.00 WIB"
String formatSchedule(DateTime d) =>
    '${_dayFull[d.weekday - 1]}, ${d.day} ${_monthShort[d.month - 1]} ${d.year}'
    ' · ${_two(d.hour)}.${_two(d.minute)} WIB';

/// Contoh: "Kam, 12 Nov · 19.02"
String formatScanTime(DateTime d) =>
    '${_dayShort[d.weekday - 1]}, ${d.day} ${_monthShort[d.month - 1]}'
    ' · ${_two(d.hour)}.${_two(d.minute)}';

// ------------------------ SCREEN -------------------------

class ScanQrScreen extends StatefulWidget {
  final MeetingInfo meeting;

  const ScanQrScreen({super.key, required this.meeting});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _lineController;

  ScanState _state = ScanState.scanning;
  bool _torchOn = false;
  DateTime? _scannedAt;

  @override
  void initState() {
    super.initState();
    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _lineController.dispose();
    super.dispose();
  }

  /// TODO: ganti dengan verifikasi ke backend (Supabase / Firebase, dsb).
  /// Kembalikan true jika QR masih berlaku (belum lewat 30 detik).
  Future<bool> _verifyQr(String code) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return code != 'EXPIRED';
  }

  /// Panggil fungsi ini dari callback scanner kamera (mis. mobile_scanner).
  Future<void> _handleScan(String code) async {
    if (_state == ScanState.success) return;
    final ok = await _verifyQr(code);
    if (!mounted) return;
    setState(() {
      _state = ok ? ScanState.success : ScanState.invalid;
      if (ok) _scannedAt = DateTime.now();
    });
  }

  void _rescan() => setState(() => _state = ScanState.scanning);

  void _toggleTorch() {
    // TODO: panggil controller.toggleTorch() dari mobile_scanner.
    setState(() => _torchOn = !_torchOn);
  }

  Future<void> _enterManualCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Masukkan kode manual'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'Kode dari layar ketua',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: _navy),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
    if (code != null && code.isNotEmpty) _handleScan(code);
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = _state == ScanState.success;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Pindai QR absen',
          style: TextStyle(
              color: _navy, fontSize: 26, fontWeight: FontWeight.w800),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: isSuccess
            ? _SuccessView(
                key: const ValueKey('success'),
                meeting: widget.meeting,
                scannedAt: _scannedAt ?? DateTime.now(),
              )
            : _ScannerView(
                key: ValueKey(_state),
                state: _state,
                meeting: widget.meeting,
                torchOn: _torchOn,
                lineAnimation: _lineController,
                onToggleTorch: _toggleTorch,
                // ---- DEMO (hapus setelah kamera asli terpasang) ----
                // Tap area kamera = simulasi QR valid,
                // tahan lama = simulasi QR kedaluwarsa.
                onDemoValid: () => _handleScan('VALID'),
                onDemoExpired: () => _handleScan('EXPIRED'),
              ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget? _buildBottomBar() {
    Widget? child;
    switch (_state) {
      case ScanState.scanning:
        return null;
      case ScanState.invalid:
        child = Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _enterManualCode,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  foregroundColor: _navy,
                  side: BorderSide(color: Colors.grey.shade400),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                child: const Text('Masukkan kode manual'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _rescan,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: _navy,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                child: const Text('Pindai ulang'),
              ),
            ),
          ],
        );
        break;
      case ScanState.success:
        child = FilledButton(
          onPressed: () => Navigator.maybePop(context),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: _navy,
            shape: const StadiumBorder(),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          child: const Text('Kembali ke rapat'),
        );
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: child,
        ),
      ),
    );
  }
}

// ----------------- VIEW: SCANNING / INVALID ------------------

class _ScannerView extends StatelessWidget {
  final ScanState state;
  final MeetingInfo meeting;
  final bool torchOn;
  final Animation<double> lineAnimation;
  final VoidCallback onToggleTorch;
  final VoidCallback onDemoValid;
  final VoidCallback onDemoExpired;

  const _ScannerView({
    super.key,
    required this.state,
    required this.meeting,
    required this.torchOn,
    required this.lineAnimation,
    required this.onToggleTorch,
    required this.onDemoValid,
    required this.onDemoExpired,
  });

  bool get _invalid => state == ScanState.invalid;

  @override
  Widget build(BuildContext context) {
    final accent = _invalid ? _errorRed : _amber;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Panel kamera
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            color: _darkPanel,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: _invalid ? null : onDemoValid,
                onLongPress: _invalid ? null : onDemoExpired,
                child: SizedBox(
                  width: 232,
                  height: 232,
                  child: Stack(
                    children: [
                      // TODO: ganti Container ini dengan MobileScanner(...)
                      Container(
                        decoration: BoxDecoration(
                          color: _viewfinder,
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _CornerPainter(color: accent),
                        ),
                      ),
                      if (!_invalid)
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: lineAnimation,
                            builder: (_, __) => Align(
                              alignment:
                                  Alignment(0, -0.75 + 1.5 * lineAnimation.value),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: _amber,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                _invalid ? 'QR tidak berlaku' : 'Arahkan kamera ke QR di HP ketua',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: onToggleTorch,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  decoration: BoxDecoration(
                    color: torchOn
                        ? const Color(0xFF5A5B66)
                        : const Color(0xFF3A3B44),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(torchOn ? Icons.flash_on : Icons.flash_on_outlined,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      const Text('Senter',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Pesan error (hanya saat QR tidak valid)
        if (_invalid) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _errorBg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFF8C1D18), size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('QR sudah berganti',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B1410))),
                      SizedBox(height: 4),
                      Text(
                        'QR yang kamu pindai sudah lewat 30 detik. Minta ketua menampilkan QR terbaru, lalu pindai lagi.',
                        style:
                            TextStyle(fontSize: 15, color: Color(0xFF7A1F1A)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        _MeetingCard(meeting: meeting),

        // Catatan (hanya saat scanning)
        if (!_invalid) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'QR berganti tiap 30 detik, jadi pindai langsung dari layar ketua.',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final MeetingInfo meeting;

  const _MeetingCard({required this.meeting});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6E8F2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFDDE3FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.event, color: _navy),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meeting.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(formatSchedule(meeting.schedule),
                    style:
                        TextStyle(fontSize: 14, color: Colors.grey.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Menggambar 4 sudut (bracket) pada viewfinder.
class _CornerPainter extends CustomPainter {
  final Color color;

  const _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    const r = 28.0; // radius sudut
    const arm = 52.0; // panjang lengan
    final w = size.width;
    final h = size.height;
    const inset = 3.0;

    final path = Path()
      // kiri-atas
      ..moveTo(inset, arm)
      ..lineTo(inset, r)
      ..arcToPoint(const Offset(r, inset), radius: const Radius.circular(r))
      ..lineTo(arm, inset)
      // kanan-atas
      ..moveTo(w - arm, inset)
      ..lineTo(w - r, inset)
      ..arcToPoint(Offset(w - inset, r), radius: const Radius.circular(r))
      ..lineTo(w - inset, arm)
      // kanan-bawah
      ..moveTo(w - inset, h - arm)
      ..lineTo(w - inset, h - r)
      ..arcToPoint(Offset(w - r, h - inset), radius: const Radius.circular(r))
      ..lineTo(w - arm, h - inset)
      // kiri-bawah
      ..moveTo(arm, h - inset)
      ..lineTo(r, h - inset)
      ..arcToPoint(Offset(inset, h - r), radius: const Radius.circular(r))
      ..lineTo(inset, h - arm);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => old.color != color;
}

// ---------------------- VIEW: SUCCESS -----------------------

class _SuccessView extends StatelessWidget {
  final MeetingInfo meeting;
  final DateTime scannedAt;

  const _SuccessView({
    super.key,
    required this.meeting,
    required this.scannedAt,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 24),
      children: [
        Center(
          child: Container(
            width: 128,
            height: 128,
            decoration: const BoxDecoration(
              color: _lightBlue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: _navy,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 40),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Kehadiran tercatat',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Kamu tercatat hadir di rapat ini. Ketua bisa melihatnya di daftar kehadiran.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16, height: 1.4, color: Colors.grey.shade700),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _DetailRow(label: 'Rapat', value: meeting.title),
              const SizedBox(height: 14),
              _DetailRow(
                  label: 'Waktu pindai', value: formatScanTime(scannedAt)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Status',
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey.shade700)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: _lightBlue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Hadir',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0B4F6C))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
        const SizedBox(width: 16),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}