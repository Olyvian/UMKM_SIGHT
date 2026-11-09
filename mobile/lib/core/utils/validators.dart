/// Validasi form yang dipakai halaman Login & Register.
abstract final class Validators {
  static const minPasswordLength = 8;

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String? required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label wajib diisi';
    return null;
  }

  static String? name(String? value, String label) {
    final requiredError = required(value, label);
    if (requiredError != null) return requiredError;
    if (value!.trim().length < 2) return '$label terlalu pendek';
    return null;
  }

  static String? email(String? value) {
    final requiredError = required(value, 'Email');
    if (requiredError != null) return requiredError;
    if (!_emailRegex.hasMatch(value!.trim())) {
      return 'Format email tidak valid';
    }
    return null;
  }

  /// Untuk login: cukup tidak kosong (aturan panjang hanya saat mendaftar).
  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return 'Kata sandi wajib diisi';
    return null;
  }

  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Kata sandi wajib diisi';
    if (value.length < minPasswordLength) {
      return 'Minimal $minPasswordLength karakter';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Konfirmasi kata sandi wajib diisi';
    if (value != original) return 'Kata sandi tidak sama';
    return null;
  }

  /// Kekuatan kata sandi: 0 (kosong) sampai 3 (kuat).
  static int passwordStrength(String password) {
    if (password.isEmpty) return 0;

    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasDigit = RegExp(r'\d').hasMatch(password);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(password);

    var level = 1;
    if (password.length >= minPasswordLength && hasLetter && hasDigit) {
      level = 2;
      if (hasUpper && hasLower && (hasSymbol || password.length >= 12)) {
        level = 3;
      }
    }
    return level;
  }
}
