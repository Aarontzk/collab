// Dibuat oleh Gregorius Cahya Khrisna Setiaputra - 5026241122

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collab/models/task_detail_data.dart';
import 'package:collab/screens/task_detail_screen.dart';
import 'package:collab/utils/theme.dart';
import 'package:collab/widgets/task_dialogs.dart';

import 'fake_task_detail_service.dart';
import 'task_detail_fonts.dart';

Widget _app(Widget home) => MaterialApp(theme: collabTheme, home: home);

TaskDetailData _noEvidence(TaskDetailStatus status) =>
    sampleTaskDetail(status).copyWith(evidences: const []);

Future<FakeTaskDetailService> _show(
  WidgetTester tester,
  TaskDetailStatus status, {
  bool isPic = false,
  bool isLeader = false,
  bool isStudent = true,
  TaskDetailData? task,
  FakeTaskDetailService? service,
  Future<bool> Function(Uri)? openUrl,
}) async {
  tester.view.physicalSize = const Size(412, 917);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake =
      service ??
      FakeTaskDetailService(
        task ?? sampleTaskDetail(status),
        isPic: isPic,
        isLeader: isLeader,
        isStudent: isStudent,
      );
  await tester.pumpWidget(
    _app(TaskDetailScreen(service: fake, openUrl: openUrl)),
  );
  await tester.pumpAndSettle();
  return fake;
}

Finder _inDialog(Finder matching) =>
    find.descendant(of: find.byType(Dialog), matching: matching);

Future<void> _addLink(WidgetTester tester, String url) async {
  await tester.tap(find.text('Tempel Tautan'));
  await tester.pumpAndSettle();
  await tester.enterText(_inDialog(find.byType(TextField)), url);
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, 'Tambah'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadCollabFonts);

  group('memuat data', () {
    testWidgets('menampilkan data dari service', (tester) async {
      await _show(tester, TaskDetailStatus.submitted);
      expect(find.text('Fitur absensi QR'), findsOneWidget);
      expect(find.text('Aludra Nadia Salwa'), findsOneWidget);
      expect(find.text('Berat · 3 poin'), findsOneWidget);
      expect(find.text('1 / 2 setuju'), findsOneWidget);
    });

    testWidgets('gagal memuat: tampil error dan bisa coba lagi', (
      tester,
    ) async {
      final fake = FakeTaskDetailService(
        sampleTaskDetail(TaskDetailStatus.todo),
      )..failWith = StateError('Koneksi putus');
      await _show(tester, TaskDetailStatus.todo, service: fake);
      expect(find.text('Koneksi putus'), findsOneWidget);
      expect(find.text('Fitur absensi QR'), findsNothing);

      fake.failWith = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Fitur absensi QR'), findsOneWidget);
    });

    testWidgets('aksi gagal: pesan error tampil dan data tidak berubah', (
      tester,
    ) async {
      final fake = await _show(tester, TaskDetailStatus.todo, isPic: true);
      fake.failWith = StateError(
        'Kamu tidak punya akses untuk mengubah tugas ini.',
      );
      await tester.tap(find.text('Mulai kerjakan'));
      await tester.pumpAndSettle();
      expect(find.textContaining('tidak punya akses'), findsOneWidget);
      expect(fake.task.status, TaskDetailStatus.todo);
      expect(find.text('Mulai kerjakan'), findsOneWidget);
    });
  });

  group('PIC', () {
    testWidgets('belum mulai: bukti terkunci, Mulai kerjakan', (tester) async {
      final fake = await _show(tester, TaskDetailStatus.todo, isPic: true);
      expect(find.text('Terkunci'), findsOneWidget);
      expect(find.text('Belum diajukan'), findsOneWidget);

      await tester.tap(find.text('Mulai kerjakan'));
      await tester.pumpAndSettle();
      expect(fake.task.status, TaskDetailStatus.inProgress);
      expect(find.text('Ajukan validasi'), findsOneWidget);
      expect(find.text('Upload Foto/File'), findsOneWidget);
    });

    testWidgets('bukan PIC tidak melihat tombol Mulai kerjakan', (
      tester,
    ) async {
      await _show(tester, TaskDetailStatus.todo);
      expect(find.text('Mulai kerjakan'), findsNothing);
    });

    testWidgets('ajukan ditolak kalau belum ada bukti', (tester) async {
      final fake = await _show(
        tester,
        TaskDetailStatus.inProgress,
        isPic: true,
        task: _noEvidence(TaskDetailStatus.inProgress),
      );
      expect(find.text('Belum ada'), findsOneWidget);
      await tester.tap(find.text('Ajukan validasi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('minimal satu bukti'), findsOneWidget);
      expect(fake.task.status, TaskDetailStatus.inProgress);
    });

    testWidgets('tempel tautan lalu ajukan: bukti baru disimpan saat submit', (
      tester,
    ) async {
      final fake = await _show(
        tester,
        TaskDetailStatus.inProgress,
        isPic: true,
        task: _noEvidence(TaskDetailStatus.inProgress),
      );
      await _addLink(tester, 'https://figma.com/design/x');
      expect(find.text('figma.com/design/x'), findsOneWidget);
      // Belum dikirim ke server sebelum Ajukan.
      expect(fake.task.evidences, isEmpty);

      await tester.tap(find.text('Ajukan validasi'));
      await tester.pumpAndSettle();
      expect(fake.task.status, TaskDetailStatus.submitted);
      expect(fake.task.evidences.single.kind, EvidenceKind.link);
      expect(fake.task.workNote, 'Sudah diuji di emulator Android.');
      expect(find.text('Menunggu validasi'), findsOneWidget);
      expect(find.text('1 lampiran'), findsOneWidget);
    });

    testWidgets('bukti baru bisa dibuang sebelum diajukan', (tester) async {
      await _show(
        tester,
        TaskDetailStatus.inProgress,
        isPic: true,
        task: _noEvidence(TaskDetailStatus.inProgress),
      );
      await _addLink(tester, 'https://figma.com/design/x');
      await tester.tap(find.byTooltip('Hapus bukti'));
      await tester.pumpAndSettle();
      expect(find.text('figma.com/design/x'), findsNothing);
      expect(find.text('Belum ada'), findsOneWidget);
    });

    testWidgets('tempel tautan: hanya http(s) yang diterima', (tester) async {
      await _show(
        tester,
        TaskDetailStatus.inProgress,
        isPic: true,
        task: _noEvidence(TaskDetailStatus.inProgress),
      );
      await tester.tap(find.text('Tempel Tautan'));
      await tester.pumpAndSettle();
      FilledButton add() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Tambah'),
      );
      await tester.enterText(_inDialog(find.byType(TextField)), 'bukan url');
      await tester.pump();
      expect(add().onPressed, isNull);
      await tester.enterText(
        _inDialog(find.byType(TextField)),
        'https://figma.com/design/x',
      );
      await tester.pump();
      expect(add().onPressed, isNotNull);
    });

    testWidgets('ditolak: bukti lama bisa dihapus lalu kirim ulang', (
      tester,
    ) async {
      final fake = await _show(tester, TaskDetailStatus.rejected, isPic: true);
      expect(find.text('Perbarui'), findsNothing);
      expect(find.text('Upload Foto/File'), findsOneWidget);
      expect(find.text('Tempel Tautan'), findsOneWidget);
      expect(find.text('2 lampiran'), findsOneWidget);

      // Hapus bukti tersimpan: langsung dikirim ke server.
      await tester.tap(find.byTooltip('Hapus bukti').first);
      await tester.pumpAndSettle();
      expect(fake.task.evidences.length, 1);

      await tester.tap(find.text('Kirim ulang validasi'));
      await tester.pumpAndSettle();
      expect(fake.task.status, TaskDetailStatus.submitted);
      expect(fake.task.validations, isEmpty);
      expect(fake.task.evidences.length, 1);
    });

    testWidgets('ditolak: anggota lain tidak melihat tombol bukti', (
      tester,
    ) async {
      await _show(tester, TaskDetailStatus.rejected);
      expect(find.text('Upload Foto/File'), findsNothing);
      expect(find.byTooltip('Hapus bukti'), findsNothing);
    });

    testWidgets('sheet tambah bukti menampilkan tiga sumber dan Tutup', (
      tester,
    ) async {
      await _show(tester, TaskDetailStatus.inProgress, isPic: true);
      await tester.tap(find.text('Upload Foto/File'));
      await tester.pumpAndSettle();
      expect(find.text('Tambah bukti kerja'), findsOneWidget);
      expect(find.text('Ambil Foto / Pilih dari Galeri'), findsOneWidget);
      expect(find.text('Upload File Dokumen'), findsOneWidget);
      expect(find.text('Tempel Tautan URL'), findsOneWidget);
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.text('Tambah bukti kerja'), findsNothing);
    });
  });

  group('validator', () {
    testWidgets('setujui dengan komentar sampai cukup: tugas Disetujui', (
      tester,
    ) async {
      final fake = await _show(tester, TaskDetailStatus.submitted);
      await tester.tap(find.text('Setujui'));
      await tester.pumpAndSettle();
      expect(find.text('Setujui tugas?'), findsOneWidget);
      await tester.enterText(
        _inDialog(find.byType(TextField)),
        ' Sudah dicoba ',
      );
      await tester.tap(_inDialog(find.widgetWithText(FilledButton, 'Setujui')));
      await tester.pumpAndSettle();

      expect(fake.task.status, TaskDetailStatus.approved);
      expect(fake.task.validations.last.comment, 'Sudah dicoba');
      expect(find.text('2 / 2 setuju'), findsOneWidget);
      expect(
        find.text('Tugas selesai · dihitung ke skor kontribusi'),
        findsOneWidget,
      );
    });

    testWidgets('setujui: komentar boleh kosong, Batal tidak menyetujui', (
      tester,
    ) async {
      final fake = await _show(tester, TaskDetailStatus.submitted);
      await tester.tap(find.text('Setujui'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(fake.task.validations.length, 1);

      await tester.tap(find.text('Setujui'));
      await tester.pumpAndSettle();
      await tester.tap(_inDialog(find.widgetWithText(FilledButton, 'Setujui')));
      await tester.pumpAndSettle();
      expect(fake.task.validations.last.approved, isTrue);
      expect(fake.task.validations.last.comment, isNull);
    });

    testWidgets('tolak: alasan wajib, lalu status Ditolak', (tester) async {
      final fake = await _show(tester, TaskDetailStatus.submitted);
      await tester.tap(find.text('Tolak'));
      await tester.pumpAndSettle();
      expect(find.text('Tolak tugas?'), findsOneWidget);
      expect(
        find.textContaining('agar Aludra Nadia Salwa tahu'),
        findsOneWidget,
      );
      FilledButton reject() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Tolak tugas'),
      );
      expect(reject().onPressed, isNull);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(reject().onPressed, isNull);

      await tester.enterText(find.byType(TextField), ' QR masih statis ');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Tolak tugas'));
      await tester.pumpAndSettle();
      expect(fake.task.status, TaskDetailStatus.rejected);
      expect(fake.task.validations.last.comment, 'QR masih statis');
      expect(find.text('Perlu revisi'), findsOneWidget);
    });

    testWidgets('tolak: Batal tidak mengubah apa pun', (tester) async {
      final fake = await _show(tester, TaskDetailStatus.submitted);
      await tester.tap(find.text('Tolak'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(fake.task.validations.length, 1);
      expect(find.text('Tolak tugas?'), findsNothing);
    });

    testWidgets('PIC tidak boleh memvalidasi tugasnya sendiri', (tester) async {
      await _show(tester, TaskDetailStatus.submitted, isPic: true);
      expect(find.text('Setujui'), findsNothing);
      expect(find.text('Tolak'), findsNothing);
    });

    testWidgets('dosen tidak boleh memvalidasi', (tester) async {
      await _show(tester, TaskDetailStatus.submitted, isStudent: false);
      expect(find.text('Setujui'), findsNothing);
      expect(find.text('Tolak'), findsNothing);
    });

    testWidgets('sudah memberi suara: tombol hilang', (tester) async {
      final fake = FakeTaskDetailService(
        sampleTaskDetail(TaskDetailStatus.submitted),
      )..voted = true;
      await _show(tester, TaskDetailStatus.submitted, service: fake);
      expect(find.text('Setujui'), findsNothing);
    });
  });

  group('ketua', () {
    testWidgets('ikon ubah dan hapus tampil untuk ketua', (tester) async {
      await _show(tester, TaskDetailStatus.submitted, isLeader: true);
      expect(find.byTooltip('Ubah tugas'), findsOneWidget);
      expect(find.byTooltip('Hapus tugas'), findsOneWidget);
    });

    testWidgets('anggota biasa tidak melihat ikon ubah dan hapus', (
      tester,
    ) async {
      await _show(tester, TaskDetailStatus.submitted);
      expect(find.byTooltip('Ubah tugas'), findsNothing);
      expect(find.byTooltip('Hapus tugas'), findsNothing);
    });

    testWidgets('tugas Disetujui terkunci: ubah dan hapus disembunyikan', (
      tester,
    ) async {
      await _show(tester, TaskDetailStatus.approved, isLeader: true);
      expect(find.byTooltip('Ubah tugas'), findsNothing);
      expect(find.byTooltip('Hapus tugas'), findsNothing);
    });

    testWidgets('hapus: Batal tidak menghapus', (tester) async {
      final fake = await _show(
        tester,
        TaskDetailStatus.submitted,
        isLeader: true,
      );
      await tester.tap(find.byTooltip('Hapus tugas'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus tugas?'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(fake.deleted, isFalse);
    });

    testWidgets('hapus: konfirmasi menghapus dan menutup layar dengan true', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 917);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fake = FakeTaskDetailService(
        sampleTaskDetail(TaskDetailStatus.submitted),
        isLeader: true,
      );
      Object? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => result = await Navigator.of(context)
                    .push<bool>(
                      MaterialPageRoute(
                        builder: (_) => TaskDetailScreen(service: fake),
                      ),
                    ),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hapus tugas'));
      await tester.pumpAndSettle();
      await tester.tap(_inDialog(find.widgetWithText(FilledButton, 'Hapus')));
      await tester.pumpAndSettle();

      expect(fake.deleted, isTrue);
      expect(result, isTrue);
      expect(find.text('Detail tugas'), findsNothing);
    });

    testWidgets('ubah tugas membuka form berisi data lalu memperbarui', (
      tester,
    ) async {
      final fake = await _show(
        tester,
        TaskDetailStatus.submitted,
        isLeader: true,
      );
      await tester.tap(find.byTooltip('Ubah tugas'));
      await tester.pumpAndSettle();

      expect(find.text('Ubah tugas'), findsWidgets);
      final title = find.widgetWithText(TextFormField, 'Fitur absensi QR');
      expect(title, findsOneWidget);
      await tester.enterText(title, 'Fitur absensi QR v2');
      await tester.ensureVisible(find.text('Simpan'));
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(fake.task.title, 'Fitur absensi QR v2');
      expect(fake.task.picId, 'aludra');
      expect(fake.task.weight, 3);
      expect(find.text('Fitur absensi QR v2'), findsOneWidget);
      expect(find.text('Detail tugas'), findsOneWidget);
    });
  });

  group('buka bukti', () {
    TaskDetailData withEvidence(List<EvidenceItem> items) =>
        sampleTaskDetail(TaskDetailStatus.submitted).copyWith(evidences: items);

    testWidgets('tautan dibuka di browser', (tester) async {
      final opened = <Uri>[];
      await _show(
        tester,
        TaskDetailStatus.submitted,
        openUrl: (u) async {
          opened.add(u);
          return true;
        },
      );
      await tester.tap(find.text('github.com/Aarontzk/kontri/pull/7'));
      await tester.pump();
      expect(
        opened.single.toString(),
        'https://github.com/Aarontzk/kontri/pull/7',
      );
    });

    testWidgets('tautan bukan http/https ditolak', (tester) async {
      final opened = <Uri>[];
      await _show(
        tester,
        TaskDetailStatus.submitted,
        task: withEvidence(const [
          EvidenceItem(
            kind: EvidenceKind.link,
            title: 'file.txt',
            subtitle: 'Tautan',
            localPath: 'file:///etc/passwd',
          ),
        ]),
        openUrl: (u) async {
          opened.add(u);
          return true;
        },
      );
      await tester.tap(find.text('file.txt'));
      await tester.pump();
      expect(opened, isEmpty);
      expect(find.textContaining('Hanya tautan http/https'), findsOneWidget);
    });

    testWidgets('file di Storage dibuka lewat signed URL', (tester) async {
      final opened = <Uri>[];
      final fake = await _show(
        tester,
        TaskDetailStatus.submitted,
        task: withEvidence(const [
          EvidenceItem(
            kind: EvidenceKind.file,
            title: 'laporan.pdf',
            subtitle: '2,0 MB · File di Storage',
            storagePath: 'g1/t1/laporan.pdf',
          ),
        ]),
        openUrl: (u) async {
          opened.add(u);
          return true;
        },
      );
      await tester.tap(find.text('laporan.pdf'));
      await tester.pump();
      expect(fake.signedFor, ['g1/t1/laporan.pdf']);
      expect(opened.single.host, 'example.supabase.co');
    });

    testWidgets('foto di Storage dipratinjau di dialog', (tester) async {
      await _show(
        tester,
        TaskDetailStatus.submitted,
        task: withEvidence(const [
          EvidenceItem(
            kind: EvidenceKind.image,
            title: 'hasil-uji-qr.png',
            subtitle: '1,2 MB · Foto di Storage',
            storagePath: 'g1/t1/hasil-uji-qr.png',
          ),
        ]),
      );
      await tester.tap(find.text('hasil-uji-qr.png'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('bukti tanpa sumber memberi tahu belum bisa dibuka', (
      tester,
    ) async {
      await _show(tester, TaskDetailStatus.submitted);
      await tester.tap(find.text('hasil-uji-qr.png'));
      await tester.pump();
      expect(find.textContaining('belum bisa dibuka'), findsOneWidget);
    });
  });

  group('aksi tidak dobel', () {
    testWidgets('tekan Upload dua kali cepat hanya membuka satu sheet', (
      tester,
    ) async {
      await _show(tester, TaskDetailStatus.inProgress, isPic: true);
      await tester.tap(find.text('Upload Foto/File'));
      await tester.tap(find.text('Upload Foto/File'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Tambah bukti kerja'), findsOneWidget);
    });

    testWidgets('tombol bawah nonaktif selama sheet terbuka', (tester) async {
      await _show(tester, TaskDetailStatus.inProgress, isPic: true);
      await tester.tap(find.text('Upload Foto/File'));
      await tester.pumpAndSettle();
      FilledButton submit() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Ajukan validasi'),
      );
      expect(submit().onPressed, isNull);
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(submit().onPressed, isNotNull);
    });

    testWidgets('ikon hapus bukti cukup besar untuk disentuh', (tester) async {
      await _show(tester, TaskDetailStatus.inProgress, isPic: true);
      final size = tester.getSize(find.byTooltip('Hapus bukti').first);
      expect(size.width, greaterThanOrEqualTo(40));
      expect(size.height, greaterThanOrEqualTo(40));
    });
  });

  group('pilihan sumber foto', () {
    Future<PhotoSource?> pick(WidgetTester tester, String label) async {
      PhotoSource? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await showPhotoSourceSheet(context),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      expect(find.text('Ambil foto bukti'), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('Ambil Foto memilih kamera', (tester) async {
      expect(await pick(tester, 'Ambil Foto'), PhotoSource.camera);
    });

    testWidgets('Pilih dari Galeri memilih galeri', (tester) async {
      expect(await pick(tester, 'Pilih dari Galeri'), PhotoSource.gallery);
    });
  });
}
