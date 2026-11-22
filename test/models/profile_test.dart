import 'package:flutter_test/flutter_test.dart';
import 'package:collab/models/group.dart';
import 'package:collab/models/profile.dart';
import 'package:collab/utils/validators.dart';

void main() {
  test('Profile.fromJson membaca kolom opsional', () {
    final p = Profile.fromJson({
      'id': 'u1',
      'full_name': 'Azka',
      'nrp': '5025231001',
      'avatar_url': null,
    });
    expect(p.fullName, 'Azka');
    expect(p.nrp, '5025231001');
    expect(p.avatarUrl, isNull);
  });

  test('Member.fromJson ikut membaca avatar_url (boleh tidak ada)', () {
    final withPhoto = Member.fromJson({
      'user_id': 'u1',
      'role': 'member',
      'profiles': {'full_name': 'Azka', 'avatar_url': 'https://x.id/a.png'},
    });
    final without = Member.fromJson({
      'user_id': 'u2',
      'role': 'member',
      'profiles': {'full_name': 'Tio'},
    });
    expect(withPhoto.avatarUrl, 'https://x.id/a.png');
    expect(without.avatarUrl, isNull);
  });

  group('Validators.nrp', () {
    test('kosong boleh (opsional)', () {
      expect(Validators.nrp(''), isNull);
      expect(Validators.nrp(null), isNull);
    });

    test('angka 5-20 digit lolos', () {
      expect(Validators.nrp('5025231001'), isNull);
      expect(Validators.nrp(' 12345 '), isNull);
    });

    test('huruf, terlalu pendek, atau terlalu panjang ditolak', () {
      expect(Validators.nrp('50A5'), isNotNull);
      expect(Validators.nrp('1234'), isNotNull);
      expect(Validators.nrp('1' * 21), isNotNull);
    });
  });
}
