// Dibuat oleh Gregorius Cahya Khrisna Setiaputra - 5026241122

import 'package:flutter/services.dart';

/// `flutter test` memakai font Ahem (sangat lebar) untuk semua teks. Muat font
/// asli Collab supaya ukuran teks di tes sama dengan di aplikasi.
Future<void> loadCollabFonts() async {
  const families = {
    'PlusJakartaSans': [
      'PlusJakartaSans-Regular',
      'PlusJakartaSans-Medium',
      'PlusJakartaSans-SemiBold',
      'PlusJakartaSans-Bold',
      'PlusJakartaSans-ExtraBold',
    ],
    'Roboto': ['Roboto-Regular', 'Roboto-Medium'],
    'Poppins': ['Poppins-Regular'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      loader.addFont(rootBundle.load('assets/fonts/$file.ttf'));
    }
    await loader.load();
  }
}
