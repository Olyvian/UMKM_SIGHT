import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_sight/features/auth/presentation/pages/forgot_password_page.dart';

void main() {
  testWidgets('halaman lupa kata sandi memvalidasi email', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordPage()));

    expect(find.text('Lupa kata sandi?'), findsOneWidget);
    expect(find.text('Kirim tautan reset'), findsOneWidget);

    final submit = find.text('Kirim tautan reset');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('Email wajib diisi'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'budi');
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('Format email tidak valid'), findsOneWidget);
  });
}
