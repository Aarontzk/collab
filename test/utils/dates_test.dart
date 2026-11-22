import 'package:flutter_test/flutter_test.dart';
import 'package:collab/utils/dates.dart';

void main() {
  group('weekStartUtc', () {
    test('Senin tetap hari itu', () {
      expect(weekStartUtc(DateTime.utc(2026, 11, 2, 8)), '2026-11-02');
    });
    test('Rabu dan Minggu mundur ke Senin', () {
      expect(weekStartUtc(DateTime.utc(2026, 11, 4, 23, 59)), '2026-11-02');
      expect(weekStartUtc(DateTime.utc(2026, 11, 8, 12)), '2026-11-02');
    });
    test('melewati batas bulan dan tahun', () {
      expect(weekStartUtc(DateTime.utc(2026, 10, 1)), '2026-09-28');
      expect(weekStartUtc(DateTime.utc(2027, 1, 1)), '2026-12-28');
    });
  });

  test('formatDateTime pakai nama bulan Indonesia dan 2 digit jam', () {
    final local = DateTime(2026, 8, 17, 9, 5);
    expect(formatDateTime(local), '17 Agu 2026, 09:05');
  });
}
