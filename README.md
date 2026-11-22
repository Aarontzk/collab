# 🤝 Collab: Kerja bareng, nilai adil

Final Project Teknologi Berkembang 2026/2027 · Flutter + Supabase

## Nama dan deskripsi aplikasi

**Masalah.** Di tugas kelompok sering ada anggota yang kerja keras dan ada yang cuma numpang nama. Dosen dan teman sekelompok susah membuktikan siapa mengerjakan apa, jadi nilai individu sering tidak adil.

**Pengguna.** Mahasiswa yang mengerjakan tugas kelompok (ketua dan anggota), serta dosen yang ingin melihat kontribusi tiap anggota.

**Cara Collab membantu.** Setiap tugas punya PIC, bobot, deadline, dan bukti pengerjaan yang divalidasi anggota lain. Absensi rapat memakai QR yang berganti terus, ada peer review anonim, lalu semua data itu dihitung menjadi **skor kontribusi** tiap anggota. Anggota yang skornya jauh di bawah rata-rata diberi tanda ⚠️.

## Syarat minimal ide (dari PPT Week 2)

| Syarat | Di Collab |
|---|---|
| Masalah, pengguna, dan solusi tertulis | ✅ Lihat bagian di atas |
| Minimal 5 layar berbeda (splash tidak dihitung) | ✅ 12 layar, lihat `lib/screens/` |
| Data disimpan dan ditampilkan kembali, minimal 2 jenis data yang saling berhubungan | ✅ Kelompok → anggota → tugas → bukti & validasi, rapat → absensi, peer review |
| Tambah, lihat, ubah, hapus minimal satu jenis data | ✅ Tugas: tambah, lihat, ubah, hapus (ubah & hapus khusus ketua, selama tugas belum disetujui) |
| Pekerjaan bisa dibagi ke seluruh anggota | ✅ Lihat tabel pembagian tugas |
| Database Supabase atau Firebase | ✅ Supabase |

## Rencana fitur dan screen

| Screen | File | Fungsi |
|---|---|---|
| Login | `login_screen.dart` | Masuk dengan email & password |
| Daftar | `register_screen.dart` | Buat akun baru |
| Daftar kelompok | `groups_screen.dart` | Lihat kelompok, buat atau gabung pakai kode |
| Beranda kelompok | `group_home_screen.dart` | 4 tab: tugas, rapat, peer review, kontribusi |
| Task board | `task_board_screen.dart` | Daftar tugas realtime + filter "Tugasku" |
| Form tugas | `task_form_screen.dart` | Tambah dan ubah tugas (PIC, bobot, deadline) |
| Detail tugas | `task_detail_screen.dart` | Bukti kerja, submit, validasi, tombol ubah/hapus untuk ketua |
| Rapat | `meetings_screen.dart` | Daftar rapat dan absensi |
| QR rapat | `meeting_qr_screen.dart` | QR absen yang berganti tiap 30 detik |
| Scan QR | `scan_qr_screen.dart` | Anggota scan untuk absen |
| Peer review | `peer_review_screen.dart` | Nilai anggota lain secara anonim |
| Kontribusi | `contribution_screen.dart` | Skor kontribusi tiap anggota + tanda ⚠️ |

## Struktur folder

Mengikuti struktur di PPT Week 2: layar di `lib/screens/`, layanan eksternal di `lib/services/`, pengujian di `test/`.

```
collab/
├── lib/
│   ├── main.dart        # pintu masuk aplikasi
│   ├── app.dart         # MaterialApp + tema
│   ├── screens/         # semua layar (UI)
│   ├── services/        # akses Supabase (auth, kelompok, tugas, rapat, peer review)
│   ├── models/          # bentuk data: Group, Task, Contribution
│   ├── widgets/         # widget & dialog yang dipakai ulang
│   └── utils/           # env, tema, validator, format tanggal, pesan error
├── assets/images/       # gambar lokal (terdaftar di pubspec.yaml)
├── test/                # pengujian, jalankan dengan flutter test
├── supabase/schema.sql  # skema database + aturan akses
├── docs/                # rumus skor kontribusi
└── pubspec.yaml         # library dan asset
```

Aturannya: **screen tidak boleh memanggil Supabase langsung**, selalu lewat file di `services/`.

## Pembagian tugas

| Anggota | Bagian |
|---|---|
| 1 | Login, daftar, kelompok (`login`, `register`, `groups`, `group_home`, `auth_service`, `group_service`) + `supabase/schema.sql` |
| 2 | Task board & form tugas (`task_board`, `task_form`, `task_service`) |
| 3 | Detail tugas, upload bukti file/foto ke Storage, validasi (`task_detail`, `task_dialogs`) |
| 4 | Rapat & absensi QR (`meetings`, `meeting_qr`, `scan_qr`, `meeting_service`) |
| 5 | Peer review anonim (`peer_review_screen`, `peer_review_service`) |
| 6 | Skor kontribusi, grafik `fl_chart`, export PDF (`contribution_screen`, `models/contribution.dart`) |
| 7 | Desain UI di Figma, tema (`utils/theme.dart`), notifikasi pengingat deadline |

## Status fitur

| Fitur | Status |
|---|---|
| Login / daftar / logout | ✅ |
| Buat & gabung kelompok pakai kode, info anggota, keluar kelompok | ✅ |
| Task board realtime + filter "Tugasku" | ✅ |
| Tambah tugas (PIC, bobot, deadline) | ✅ |
| Bukti kerja berupa link + submit + validasi | ✅ |
| Rapat + QR berganti tiap 30 detik + scan absen | ✅ |
| Peer review anonim mingguan | ✅ |
| Skor kontribusi + tanda ⚠️ | ✅ |
| Ubah & hapus tugas (syarat CRUD) | ✅ |
| Upload bukti file/foto ke Storage | ⬜ Anggota 3 |
| Grafik kontribusi + export PDF | ⬜ Anggota 6 |
| Desain UI sesuai Figma + notifikasi | ⬜ Anggota 7 |

## Setup

1. **Kunci Supabase.** Salin `env.example.json` menjadi `env.json`, lalu isi `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY` (minta ke ketua).
   `env.json` tidak ikut di-commit. **Jangan pernah** memakai `service_role`/secret key.
2. **Jalankan**
   ```bash
   flutter pub get
   flutter run --dart-define-from-file=env.json
   ```
   Tanpa `--dart-define-from-file=env.json` aplikasi hanya menampilkan "Kunci Supabase belum diisi".
   Pintas di Windows: `.\run.bat` menyalakan emulator Android (kalau belum hidup), menunggu sampai siap, lalu menjalankan app dengan env.json.
   Di VS Code, buka folder `collab` lalu pilih konfigurasi **Collab** di Run and Debug.
   Di Android Studio, pilih **Collab** di dropdown Run (dari `.run/Collab.run.xml`, flag sudah terisi).

Perintah lain dari PPT:

| Perintah | Fungsi |
|---|---|
| `flutter analyze` | Cek warning dan error |
| `flutter test` | Jalankan semua test di folder `test/` |
| `flutter pub get` | Unduh dependencies |
| `flutter clean` | Bersihkan cache build kalau ada error aneh |

## Pengumpulan (dari PPT)

**Laporan kelompok** (link Drive, nama file `NamaKelompok_Collab.pdf`, contoh `Kelompok15_Collab.pdf`), isinya:
1. Cover dan nama anggota
2. Daftar isi
3. Nama dan deskripsi aplikasi
4. Rencana fitur dan screen aplikasi
5. Progress (UI Figma atau kode Dart)
6. Halaman terakhir: tabel kontribusi anggota (tanggal, nama, kontribusi)

**Logbook** (satu spreadsheet kelompok, week 11–14, submit ulang linknya tiap minggu di intip.in/ProgressKelompokTEKBER26). Isi tiap minggu:
- Pembagian tugas tiap anggota
- Yang dikerjakan
- Hambatan
- Rencana minggu depan

Update logbook dulu sebelum submit. Anggota yang tidak berkontribusi tidak dapat nilai kelompok untuk weekly progress.

## Aturan Git

- Satu branch per fitur, misalnya `feat/edit-hapus-tugas` atau `feat/upload-bukti`.
- Jangan push langsung ke `main`. Buat Pull Request dan minta 1 teman me-review.
- Sebelum PR, pastikan `flutter analyze` dan `flutter test` lulus.
