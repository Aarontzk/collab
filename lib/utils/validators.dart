/// Validasi form. Aturan disamakan dengan constraint di schema.sql.
abstract final class Validators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _inviteCode = RegExp(r'^([0-9A-F]{6}|[0-9A-F]{8})$');
  static final _url = RegExp(r'^https?://\S+$', caseSensitive: false);
  static final _nrp = RegExp(r'^[0-9]{5,20}$');

  static const minPasswordLength = 8;

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email wajib diisi';
    if (!_email.hasMatch(v)) return 'Format email tidak valid';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password wajib diisi';
    if (value.length < minPasswordLength) {
      return 'Password minimal $minPasswordLength karakter';
    }
    return null;
  }

  static String? requiredText(String? value, {int max = 100}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Wajib diisi';
    if (v.length > max) return 'Maksimal $max karakter';
    return null;
  }

  static String? optionalText(String? value, {required int max}) {
    final v = value?.trim() ?? '';
    if (v.length > max) return 'Maksimal $max karakter';
    return null;
  }

  static String? inviteCode(String? value) {
    final v = value?.trim().toUpperCase() ?? '';
    if (v.isEmpty) return 'Kode wajib diisi';
    if (!_inviteCode.hasMatch(v)) {
      return 'Kode harus 6 atau 8 karakter (0-9, A-F)';
    }
    return null;
  }

  /// NRP opsional; kalau diisi harus 5-20 digit angka (sama dengan schema).
  static String? nrp(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!_nrp.hasMatch(v)) return 'NRP hanya angka, 5-20 digit';
    return null;
  }

  static String? url(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Link wajib diisi';
    if (v.length > 1000) return 'Link terlalu panjang';
    if (!_url.hasMatch(v)) return 'Link harus diawali http:// atau https://';
    return null;
  }
}
