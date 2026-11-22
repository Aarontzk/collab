import 'package:flutter_test/flutter_test.dart';
import 'package:collab/utils/validators.dart';

void main() {
  group('email', () {
    test('menolak kosong dan format salah', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email(null), isNotNull);
      expect(Validators.email('azka'), isNotNull);
      expect(Validators.email('azka@kampus'), isNotNull);
    });
    test('menerima email valid (dengan spasi di pinggir)', () {
      expect(Validators.email(' azka@student.ac.id '), isNull);
    });
  });

  group('password', () {
    test('minimal 8 karakter', () {
      expect(Validators.password(''), isNotNull);
      expect(Validators.password('1234567'), isNotNull);
      expect(Validators.password('12345678'), isNull);
    });
  });

  group('requiredText / optionalText', () {
    test('requiredText menolak spasi saja dan teks terlalu panjang', () {
      expect(Validators.requiredText('   '), isNotNull);
      expect(Validators.requiredText('a' * 101), isNotNull);
      expect(Validators.requiredText('Kelompok 1'), isNull);
    });
    test('optionalText boleh kosong tapi tetap dibatasi', () {
      expect(Validators.optionalText('', max: 5), isNull);
      expect(Validators.optionalText(null, max: 5), isNull);
      expect(Validators.optionalText('123456', max: 5), isNotNull);
    });
  });

  group('inviteCode', () {
    test('menerima 6 (anggota) atau 8 (dosen) karakter hex, tidak peka huruf besar', () {
      expect(Validators.inviteCode('a1b2c3'), isNull);
      expect(Validators.inviteCode('A1B2C3D4'), isNull);
    });
    test('menolak panjang lain dan karakter non-hex', () {
      expect(Validators.inviteCode(''), isNotNull);
      expect(Validators.inviteCode('ABC12'), isNotNull);
      expect(Validators.inviteCode('ABC1234'), isNotNull);
      expect(Validators.inviteCode('XYZ123'), isNotNull);
    });
  });

  group('url', () {
    test('wajib http/https', () {
      expect(Validators.url(''), isNotNull);
      expect(Validators.url('github.com/collab'), isNotNull);
      expect(Validators.url('ftp://x.com'), isNotNull);
      expect(Validators.url('https://github.com/collab'), isNull);
      expect(Validators.url('HTTP://figma.com/file'), isNull);
    });
    test('menolak link lebih dari 1000 karakter', () {
      expect(Validators.url('https://${'a' * 1000}.com'), isNotNull);
    });
  });
}
