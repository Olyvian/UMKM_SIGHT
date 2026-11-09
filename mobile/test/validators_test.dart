import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_sight/core/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('menolak kosong dan format salah', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('budi'), isNotNull);
      expect(Validators.email('budi@toko'), isNotNull);
    });

    test('menerima email valid', () {
      expect(Validators.email('budi@tokoberkah.com'), isNull);
    });
  });

  group('Validators.newPassword', () {
    test('minimal 8 karakter', () {
      expect(Validators.newPassword('abc123'), isNotNull);
      expect(Validators.newPassword('abc12345'), isNull);
    });
  });

  group('Validators.confirmPassword', () {
    test('harus sama dengan kata sandi', () {
      expect(Validators.confirmPassword('abc12345', 'abc12345'), isNull);
      expect(Validators.confirmPassword('abc1234', 'abc12345'), isNotNull);
      expect(Validators.confirmPassword('', 'abc12345'), isNotNull);
    });
  });

  group('Validators.passwordStrength', () {
    test('menghitung level 0 sampai 3', () {
      expect(Validators.passwordStrength(''), 0);
      expect(Validators.passwordStrength('abc'), 1);
      expect(Validators.passwordStrength('abcdefg1'), 2);
      expect(Validators.passwordStrength('Abcdefg1!'), 3);
    });
  });
}
